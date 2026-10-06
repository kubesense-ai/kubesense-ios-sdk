/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#include "kubesense_profiler.h"

#if defined(__APPLE__) && !TARGET_OS_WATCH

#include "profile.h"
#include "mach_sampling_profiler.h"
#include "binary_image_resolver.h"

#include <CoreFoundation/CoreFoundation.h>
#include <cstdlib>
#include <cstring>
#include <mutex>
#include <new>
#include <random>
#include <utility>

// Profiling sampling backstop (see `callback`).
// Typical profile span is ~1 minute; this cutoff includes additional slack beyond that.
// The extra time avoids stopping sampling while the profile is still being processed.
static constexpr int64_t KUBESENSE_PROFILER_TIMEOUT_NS = 90000000000LL; // 1:30 minutes
static constexpr double KUBESENSE_PROFILER_MAX_SAMPLE_RATE = 100.0;
static constexpr bool KUBESENSE_PROFILER_RECORD_CPU_TIME = true;
// Maximum queued aggregation batch memory before new batches are dropped.
static constexpr uint64_t KUBESENSE_PROFILER_DEFAULT_HARD_LIMIT_BYTES = 64ULL * 1024ULL * 1024ULL;

/*
 * Architecture note
 *
 * The Swift profiling feature coordinates the C++ Mach profiler layer through
 * the public C API below. The Mach profiler state is backed by a process-wide
 * singleton (`g_kubesense_profiler`).
 *
 * The C++ profiler owns two long-lived profiler threads while running:
 * - `mach_sampling_profiler` owns the sampling thread, which captures raw
 *   stack traces and hands off completed buffers.
 * - `aggregation_worker` owns the aggregation thread, which drains buffers,
 *   runs profile aggregation and executes flush barriers in order.
 *
 * Public C API calls such as start, stop and flush run on external caller
 * threads and are serialized by `g_kubesense_profiler_mutex`.
 */

static kubesense_profiler_diagnostics_t empty_diagnostics() {
    return {0, 0, 0};
}

namespace kubesense::profiler { class kubesense_profiler; }

static kubesense::profiler::kubesense_profiler* g_kubesense_profiler = nullptr;
static std::mutex g_kubesense_profiler_mutex;

/**
 * Checks if ThreadSanitizer is enabled
 * and without options to avoid halts.
 *
 * @return true if ThreadSanitizer is enabled, false otherwise
 */
static bool is_thread_sanitizer_enabled() {
#if __has_feature(thread_sanitizer)
    const char* tsanOptions = getenv("TSAN_OPTIONS");
    if (tsanOptions != nullptr) {
        return (strstr(tsanOptions, "halt_on_error=0") == nullptr)
        || (strstr(tsanOptions, "report_bugs=0") == nullptr);
    }
    return true;
#endif
    return false;
}

/**
 * Checks if the current process was launched via pre-warming by examining
 * the ActivePrewarm environment variable.
 *
 * @return true if the process is actively pre-warmed, false otherwise
 */
static bool is_active_prewarm() {
    const char* prewarm = getenv("ActivePrewarm");
    return prewarm != nullptr && strcmp(prewarm, "1") == 0;
}

/**
 * Determines whether profiling should be enabled based on the sample rate
 * using probabilistic sampling.
 *
 * @param sample_rate The sample rate percentage (0.0 to 100.0)
 * @return true if profiling should be enabled, false otherwise
 */
static bool sample(double sample_rate) {
    if (sample_rate <= 0.0) return false;
    if (sample_rate >= 100.0) return true;

    static std::random_device rd;
    static std::mt19937 gen(rd());
    static std::uniform_real_distribution<double> dis(0.0, 100.0);

    double random_value = dis(gen);
    return random_value < sample_rate;
}

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Reads the KubesenseProfiling info from the `UserDefaults`
 * to validate that the feature was enabled before.
 *
 * @return If Profiling was enabled, or false if the key is not found
 */
bool kubesense_is_profiling_enabled() {
    CFStringRef suiteName = CFSTR(KUBESENSE_PROFILING_USER_DEFAULTS_SUITE_NAME);
    CFStringRef key = CFSTR(KUBESENSE_PROFILING_IS_ENABLED_KEY);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, suiteName);

    bool result = false;

    if (value) {
        if (CFGetTypeID(value) == CFBooleanGetTypeID()) {
            result = CFBooleanGetValue((CFBooleanRef)value);
        }
        CFRelease(value);
    }

    return result;
}

/**
 * Reads the KubesenseProfiling sample rate from the `UserDefaults`
 *
 * @return The sample rate as a double, or 0.0 if not found or invalid
 */
static double read_profiling_sample_rate() {
    CFStringRef suiteName = CFSTR(KUBESENSE_PROFILING_USER_DEFAULTS_SUITE_NAME);
    CFStringRef key = CFSTR(KUBESENSE_PROFILING_APP_LAUNCH_SAMPLE_RATE_KEY);
    CFPropertyListRef value = CFPreferencesCopyAppValue(key, suiteName);
    
    double sample_rate = 0.0;
    
    if (value) {
        if (CFGetTypeID(value) == CFNumberGetTypeID()) {
            CFNumberGetValue((CFNumberRef)value, kCFNumberDoubleType, &sample_rate);
        }
        CFRelease(value);
    }
    
    // Validate sample rate is between 0 and 100
    if (sample_rate < 0.0) return 0.0;
    if (sample_rate > 100.0) return 100.0;
    
    return sample_rate;
}

/**
 * Deletes the KubesenseProfiling defaults from the `UserDefaults`
 * to be re-evaluated during `Profiling.enable()`.
 */
void kubesense_delete_profiling_defaults() {
    CFStringRef suiteName = CFSTR(KUBESENSE_PROFILING_USER_DEFAULTS_SUITE_NAME);
    CFStringRef isEnabledKey = CFSTR(KUBESENSE_PROFILING_IS_ENABLED_KEY);
    CFStringRef sampleRateKey = CFSTR(KUBESENSE_PROFILING_APP_LAUNCH_SAMPLE_RATE_KEY);

    CFPreferencesSetValue(isEnabledKey, NULL, suiteName, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSetValue(sampleRateKey, NULL, suiteName, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
    CFPreferencesSynchronize(suiteName, kCFPreferencesCurrentUser, kCFPreferencesAnyHost);
}

#ifdef __cplusplus
}
#endif

namespace kubesense::profiler {

/**
 * Encapsulates profiler state and operations
 */
class kubesense_profiler {
public:
    kubesense_profiler_status_t status = KUBESENSE_PROFILER_STATUS_NOT_STARTED;

    explicit kubesense_profiler(
        double sample_rate = KUBESENSE_PROFILER_MAX_SAMPLE_RATE,
        bool is_prewarming = false,
        int64_t timeout_ns = KUBESENSE_PROFILER_TIMEOUT_NS,
        uint64_t hard_limit_bytes = KUBESENSE_PROFILER_DEFAULT_HARD_LIMIT_BYTES
    ) : sample_rate(sample_rate), is_prewarming(is_prewarming), timeout_ns(timeout_ns), hard_limit_bytes(hard_limit_bytes) {}

    // Non-copyable, non-movable (prevents double-free of raw pointers)
    kubesense_profiler(const kubesense_profiler&) = delete;
    kubesense_profiler& operator=(const kubesense_profiler&) = delete;
    kubesense_profiler(kubesense_profiler&&) = delete;
    kubesense_profiler& operator=(kubesense_profiler&&) = delete;

    ~kubesense_profiler() {
        delete profiler;
        delete profile;
        delete image_cache;
    }

    /**
     * Auto start the profiler.
     */
    int auto_start() {
        // Create and populate the binary image cache early, before sampling starts.
        // This pre-loads binary image metadata (UUID, filename) for all currently
        // loaded images and watches for new ones via dyld notifications.
        image_cache = new (std::nothrow) binary_image_cache();
        // if cache allocation/start fails, keep profiling running
        if (!image_cache || !image_cache->load()) {
            delete image_cache;
            image_cache = nullptr;
        }

        if (is_prewarming) {
            status = KUBESENSE_PROFILER_STATUS_PREWARMED;
            return 0;
        }

        if (!sample(sample_rate)) {
            status = KUBESENSE_PROFILER_STATUS_NOT_STARTED;
            return 0;
        }

        if (!create_profile_and_profiler()) return 0;

        started_at_launch = start() == 1;
        return started_at_launch ? 1 : 0;
    }

    int start() {
        if (!create_profile_and_profiler()) return 0;
        if (status == KUBESENSE_PROFILER_STATUS_RUNNING) return 1;

        if (!profiler->start_sampling()) {
            status = KUBESENSE_PROFILER_STATUS_NOT_STARTED;
            return 0;
        }

        status = KUBESENSE_PROFILER_STATUS_RUNNING;
        return 1;
    }

    void stop() {
        if (!profiler) return;
        status = KUBESENSE_PROFILER_STATUS_STOPPED;
        profiler->stop_sampling();
    }

    /**
     * Get the current profile.
     *
     * @return The profile pointer, or nullptr if no profile exists
     */
    profile* get_profile() {
        std::lock_guard<std::mutex> lock(profile_mutex);
        return profile;
    }

    bool was_started_at_launch() const {
        return started_at_launch;
    }

    /**
     * Sets the server time offset on the active profile and stores it for
     * profiles created after future flushes.
     */
    void set_server_time_offset_ns(int64_t offset_ns) {
        std::lock_guard<std::mutex> lock(profile_mutex);
        server_time_offset_ns = offset_ns;
        if (profile) {
            profile->set_server_time_offset_ns(offset_ns);
        }
    }

    /**
     * Flushes the sampling buffer and returns the profile, swapping in a fresh one.
     * The swap runs in the aggregation worker's ordered stream, giving this
     * flush a deterministic profile boundary.
     *
     * @return The harvested profile, or nullptr if no profile exists or it has no samples.
     */
    profile* flush_and_get_profile() {
        if (!profiler) {
            return nullptr;
        }

        kubesense::profiler::profile* next_profile = new (std::nothrow) kubesense::profiler::profile(
            sampling_interval_ns,
            KUBESENSE_PROFILER_RECORD_CPU_TIME
        );
        kubesense::profiler::profile* flushed_profile = nullptr;
        auto swap_profile = [this, next_profile, &flushed_profile] {
            swap_profile_at_flush_boundary(next_profile, flushed_profile);
        };

        if (!profiler->request_flush(swap_profile)) {
            swap_profile();
        }

        {
            std::lock_guard<std::mutex> lock(profile_mutex);
            if (profile) {
                profile->set_server_time_offset_ns(server_time_offset_ns);
            }
        }

        if (flushed_profile && flushed_profile->samples().empty()) {
            delete flushed_profile;
            return nullptr;
        }

        return flushed_profile;
    }

    kubesense_profiler_diagnostics_t diagnostics() {
        kubesense_profiler_diagnostics_t result = empty_diagnostics();

        if (profiler) {
            profiler->consume_diagnostics(result);
        }

        return result;
    }

private:
    /**
     * @brief Swaps the active profile at a flush boundary.
     *
     * Moves the current active profile into `flushed_profile` and installs the
     * `next_profile` under `profile_mutex`.
     *
     * @param next_profile Profile to install as the active profile.
     * @param flushed_profile Set to the previously active profile.
     */
    void swap_profile_at_flush_boundary(
        kubesense::profiler::profile* next_profile,
        kubesense::profiler::profile*& flushed_profile
    ) {
        std::lock_guard<std::mutex> lock(profile_mutex);

        flushed_profile = profile;
        profile = next_profile;

        if (!profile) {
            status = KUBESENSE_PROFILER_STATUS_ALLOCATION_FAILED;
            if (profiler) profiler->request_stop();
        }
    }

    /**
     * Creates the profile aggregator and sampling profiler.
     * No-op if already created.
     * @return true on success, false on allocation failure
     */
    bool create_profile_and_profiler() {
        if (is_thread_sanitizer_enabled()) {
            printf("[KUBESENSE SDK] → Profiling is disabled because ThreadSanitizer is active. Please disable ThreadSanitizer to enable profiling.\n");
            status = KUBESENSE_PROFILER_STATUS_NOT_STARTED;
            return false;
        }

        if (profiler) return true;

        profile = new (std::nothrow) kubesense::profiler::profile(
            sampling_interval_ns,
            KUBESENSE_PROFILER_RECORD_CPU_TIME
        );
        if (!profile) {
            status = KUBESENSE_PROFILER_STATUS_ALLOCATION_FAILED;
            return false;
        }
        profile->set_server_time_offset_ns(server_time_offset_ns);

        sampling_config_t config = SAMPLING_CONFIG_DEFAULT;
        config.sampling_interval_nanos = sampling_interval_ns;
        config.record_cpu_time = KUBESENSE_PROFILER_RECORD_CPU_TIME;

        profiler = new (std::nothrow) mach_sampling_profiler(&config, callback, this, hard_limit_bytes);
        if (!profiler) {
            delete profile;
            profile = nullptr;
            status = KUBESENSE_PROFILER_STATUS_ALLOCATION_FAILED;
            return false;
        }

        return true;
    }

    mach_sampling_profiler* profiler = nullptr;
    profile* profile = nullptr;
    binary_image_cache* image_cache = nullptr;
    double sample_rate = 0.0;
    bool is_prewarming = false;
    int64_t timeout_ns = KUBESENSE_PROFILER_TIMEOUT_NS;
    uint64_t hard_limit_bytes = KUBESENSE_PROFILER_DEFAULT_HARD_LIMIT_BYTES;
    uint64_t sampling_interval_ns = SAMPLING_CONFIG_DEFAULT_INTERVAL_NANOS;
    int64_t server_time_offset_ns = 0;
    bool started_at_launch = false;

    /**
     * Mutex protecting the profile pointer.
     */
    std::mutex profile_mutex;

    /**
     * Static callback function to handle collected stack traces.
     *
     * Lazily resolves binary image information for first-seen locations and
     * adds the samples to the profile.
     *
     * @param traces Array of captured stack traces
     * @param count Number of traces in the array
     * @param ctx Context pointer to kubesense_profiler instance
     */
    static void callback(stack_trace_t* traces, size_t count, void* ctx) {
        if (!traces || count == 0 || !ctx) return;

        kubesense_profiler* profiler = static_cast<kubesense_profiler*>(ctx);

        std::lock_guard<std::mutex> lock(profiler->profile_mutex);

        kubesense::profiler::profile* profile = profiler->profile;

        if (!profile) return;

        profile->add_samples(traces, count, profiler->image_cache);

        // Check for timeout after adding samples
        int64_t duration_ns = profile->end_timestamp() - profile->start_timestamp();
        if (duration_ns > profiler->timeout_ns) {
            profiler->profiler->request_stop();
            profiler->status = KUBESENSE_PROFILER_STATUS_TIMEOUT;
        }
    }
};

} // namespace kubesense::profiler

/**
 * Constructor function that runs early during app launch to check if
 * profiling should be enabled based on bundle configuration and prewarming.
 *
 * Uses high priority (65535) to run as close to main() as possible.
 */
__attribute__((constructor(65535)))
static void kubesense_profiler_auto_start() {
    set_main_thread(pthread_self());

    double sample_rate = kubesense_is_profiling_enabled() ? read_profiling_sample_rate() : 0;
    g_kubesense_profiler = new (std::nothrow) kubesense::profiler::kubesense_profiler(
        sample_rate,
        is_active_prewarm(),
        KUBESENSE_PROFILER_TIMEOUT_NS,
        KUBESENSE_PROFILER_DEFAULT_HARD_LIMIT_BYTES
    );
    if (g_kubesense_profiler) {
        g_kubesense_profiler->auto_start();
    }

    // Reset profiling defaults to be re-evaluated again
    kubesense_delete_profiling_defaults();
}

// MARK: - KS Profiler API

int kubesense_profiler_start(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    if (!g_kubesense_profiler) {
        g_kubesense_profiler = new (std::nothrow) kubesense::profiler::kubesense_profiler(
            KUBESENSE_PROFILER_MAX_SAMPLE_RATE,
            false,
            KUBESENSE_PROFILER_TIMEOUT_NS,
            KUBESENSE_PROFILER_DEFAULT_HARD_LIMIT_BYTES
        );
        if (!g_kubesense_profiler) {
            return 0;
        }
    }
    return g_kubesense_profiler->start();
}

void kubesense_profiler_stop(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    if (g_kubesense_profiler) g_kubesense_profiler->stop();
}

kubesense_profiler_status_t kubesense_profiler_get_status(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    return g_kubesense_profiler ? g_kubesense_profiler->status : KUBESENSE_PROFILER_STATUS_NOT_CREATED;
}

kubesense_profiler_diagnostics_t kubesense_profiler_diagnostics(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    if (g_kubesense_profiler) {
        return g_kubesense_profiler->diagnostics();
    }
    return empty_diagnostics();
}

bool kubesense_profiler_is_running() {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    return g_kubesense_profiler ? g_kubesense_profiler->status == KUBESENSE_PROFILER_STATUS_RUNNING : false;
}

bool kubesense_profiler_was_started_at_launch() {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    return g_kubesense_profiler ? g_kubesense_profiler->was_started_at_launch() : false;
}

kubesense_profile_t* kubesense_profiler_get_profile(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    return g_kubesense_profiler ? reinterpret_cast<kubesense_profile_t*>(g_kubesense_profiler->get_profile()) : nullptr;
}

kubesense_profile_t* kubesense_profiler_flush_and_get_profile(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    return g_kubesense_profiler ? reinterpret_cast<kubesense_profile_t*>(g_kubesense_profiler->flush_and_get_profile()) : nullptr;
}

void kubesense_profiler_set_server_time_offset_ns(int64_t offset_ns) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    if (g_kubesense_profiler) g_kubesense_profiler->set_server_time_offset_ns(offset_ns);
}

void kubesense_profiler_destroy(void) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    delete g_kubesense_profiler;
    g_kubesense_profiler = nullptr;
}

#ifdef __cplusplus
extern "C" {
#endif

void kubesense_profiler_start_testing(
    double sample_rate,
    bool is_prewarming,
    int64_t timeout_ns,
    uint64_t hard_limit_bytes
) {
    std::lock_guard<std::mutex> lock(g_kubesense_profiler_mutex);
    delete g_kubesense_profiler;
    g_kubesense_profiler = new (std::nothrow) kubesense::profiler::kubesense_profiler(
        sample_rate,
        is_prewarming,
        timeout_ns,
        hard_limit_bytes == 0 ? KUBESENSE_PROFILER_DEFAULT_HARD_LIMIT_BYTES : hard_limit_bytes
    );
    if (g_kubesense_profiler) {
        g_kubesense_profiler->auto_start();
    }
}

#ifdef __cplusplus
}
#endif

#endif // __APPLE__ && !TARGET_OS_WATCH
