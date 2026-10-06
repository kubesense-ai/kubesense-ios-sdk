/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#ifndef KUBESENSE_PROFILER_PROFILER_H_
#define KUBESENSE_PROFILER_PROFILER_H_

#ifdef __APPLE__
#include <TargetConditionals.h>
#if !TARGET_OS_WATCH

#include <stdint.h>
#include <stdbool.h>
#include <sys/types.h>
#include <mach/mach.h>
#include <pthread.h>
#include <pthread/qos.h>

/**
 * Structure representing a binary image loaded in memory.
 */
typedef struct binary_image {
    /** Base address where the image is loaded */
    uint64_t load_address;
    /** UUID of the binary */
    uuid_t uuid;
    /** Filename of the binary */
    const char* filename;
} binary_image_t;

/**
 * Represents a single stack frame in a profile.
 */
typedef struct stack_frame {
    /** The instruction pointer */
    uint64_t instruction_ptr;
    /** The binary image information */
    binary_image_t image;
} stack_frame_t;

/**
 * Represents a complete stack trace.
 */
typedef struct stack_trace {
    /** System-wide unique 64-bit thread ID */
    uint64_t tid;
    /** Thread name  */
    const char* thread_name;
    /** Timestamp in nanoseconds since system boot */
    uint64_t timestamp;
    /** Actual sampling interval in nanoseconds for this sample */
    uint64_t sampling_interval_nanos;
    /** CPU time consumed by this thread since the previous sample */
    uint64_t cpu_time_nanos;
    /** The stack frames array */
    stack_frame_t* frames;
    /** Number of frames in the trace */
    uint32_t frame_count;
} stack_trace_t;

/**
 * Configuration for sampling profilers.
 */
typedef struct sampling_config {
    /** Sampling interval in nanoseconds */
    uint64_t sampling_interval_nanos;  // default: 1000000 (1ms)
    /** Whether to profile only the current thread */
    uint8_t profile_current_thread_only;
    /** Maximum number of samples to buffer before calling the callback */
    size_t max_buffer_size;
    /** Maximum number of stack frames to capture per trace */
    uint32_t max_stack_depth;  // default: 128
    /** Maximum number of threads to sample per cycle (0 = no limit) */
    uint32_t max_thread_count;  // default: 100
    /** QoS class for the sampling thread */
    qos_class_t qos_class;
    /** Whether samples should include a CPU-time value */
    uint8_t record_cpu_time;
} sampling_config_t;

/**
 * Default sampling configuration values.
 */
/// Sampling frequency. Default to ~101 Hz (1/101 seconds ≈ 9.9ms)
#define SAMPLING_CONFIG_DEFAULT_FREQUENCY_HZ    101     // 101 Hz
#define SAMPLING_CONFIG_DEFAULT_INTERVAL_NANOS  9900990 // ~101 Hz (1/101 seconds ≈ 9.9ms)

/// Max buffer size of samples. It is a larger buffer to delay stack aggregation.
#define SAMPLING_CONFIG_DEFAULT_BUFFER_SIZE     10000
/// Max frames per trace.
#define SAMPLING_CONFIG_DEFAULT_STACK_DEPTH     128
/// Max threads count.
#define SAMPLING_CONFIG_DEFAULT_THREAD_COUNT    100

/**
 * Default sampling configuration with safe default values.
 * For C++ use only. Use sampling_config_get_default() from Swift.
 */
static const sampling_config_t SAMPLING_CONFIG_DEFAULT = {
    SAMPLING_CONFIG_DEFAULT_INTERVAL_NANOS,  // sampling_interval_nanos
    0,                                       // profile_current_thread_only
    SAMPLING_CONFIG_DEFAULT_BUFFER_SIZE,     // max_buffer_size
    SAMPLING_CONFIG_DEFAULT_STACK_DEPTH,     // max_stack_depth
    SAMPLING_CONFIG_DEFAULT_THREAD_COUNT,    // max_thread_count
    QOS_CLASS_USER_INTERACTIVE,              // qos_class
    0                                        // record_cpu_time
};

/**
 * Callback type for receiving stack traces.
 * This is called whenever a batch of stack traces is captured.
 *
 * Traces are delivered with raw instruction pointers only — binary image
 * information (UUID, filename) is **not** resolved. The callback is free
 * to resolve frames in-place (e.g., via `resolve_stack_trace_frames`)
 * before further processing.
 *
 * @param traces Mutable array of captured stack traces
 * @param count Number of traces in the array
 * @param ctx Context pointer passed during profiler creation
 */
typedef void (*stack_trace_callback_t)(stack_trace_t* traces, size_t count, void* ctx);

// UserDefaults constants centralized for Profiling
#define KUBESENSE_PROFILING_USER_DEFAULTS_SUITE_NAME "ai.kubesense.ios-sdk.profiling"
#define KUBESENSE_PROFILING_IS_ENABLED_KEY "is_profiling_enabled"
#define KUBESENSE_PROFILING_APP_LAUNCH_SAMPLE_RATE_KEY "profiling_app_launch_sample_rate"

#ifdef __cplusplus

namespace kubesense::profiler {
// Forward declarations
    class mach_sampling_profiler;
    class profile;
}

/**
 * Releases heap-backed memory owned by a stack trace.
 *
 * @param trace Pointer to stack trace to clean up (can be nullptr).
 */
void stack_trace_destroy(stack_trace_t* trace);

extern "C" {
#endif

/**
 * Opaque handle to a profiler instance
 */
#ifdef __cplusplus
typedef kubesense::profiler::mach_sampling_profiler profiler_t;
#else
typedef struct profiler profiler_t;
#endif

/**
 * Starts the global Kubesense profiler.
 *
 * If `g_kubesense_profiler` does not exist, it is created with a 100% sample rate.
 *
 * @return 1 if successfully started (or already running), 0 otherwise.
 */
int kubesense_profiler_start(void);

/**
 * Stops the profiler.
 *
 */
void kubesense_profiler_stop();

/**
 * Checks if the profiler is currently running.
 *
 * @return true if profiler is running.
 */
bool kubesense_profiler_is_running();

/**
 * Checks whether the profiler successfully started from the process-launch constructor.
 *
 * Starting the profiler later with `kubesense_profiler_start()` does not change this value.
 *
 * @return true if profiling started during process launch, false otherwise.
 */
bool kubesense_profiler_was_started_at_launch();

// MARK: - KS Profiler (auto-start) API

/**
 * Status codes for the kubesense profiler operations
 */
typedef enum {
    KUBESENSE_PROFILER_STATUS_NOT_CREATED = 0,       ///< Profiler was not created
    KUBESENSE_PROFILER_STATUS_NOT_STARTED = 1,       ///< Profiler was never started
    KUBESENSE_PROFILER_STATUS_RUNNING = 2,           ///< Profiler is currently running
    KUBESENSE_PROFILER_STATUS_STOPPED = 3,           ///< Profiler was stopped manually
    KUBESENSE_PROFILER_STATUS_TIMEOUT = 4,           ///< Profiler was stopped due to timeout
    KUBESENSE_PROFILER_STATUS_PREWARMED = 5,         ///< Profiler was not started due to prewarming
    KUBESENSE_PROFILER_STATUS_ALLOCATION_FAILED = 6, ///< Memory allocation failed
} kubesense_profiler_status_t;

/**
 * Diagnostics for profiling aggregation pressure.
 */
typedef struct kubesense_profiler_diagnostics {
    /** Number of sampled batches dropped since the last consume. */
    uint64_t dropped_batch_count;
    /** Number of sampled stack traces dropped since the last consume. */
    uint64_t dropped_sample_count;
    /** Maximum queued batch memory observed since the last consume. */
    uint64_t max_pending_bytes;
} kubesense_profiler_diagnostics_t;

/**
 * Opaque handle to a kubesense profiler profile instance
 */
#ifdef __cplusplus
typedef kubesense::profiler::profile kubesense_profile_t;
#else
typedef struct profile kubesense_profile_t;
#endif

/**
 * @brief Gets the current status of the kubesense profiler
 *
 * This function provides detailed information about the profiler's current state,
 * including why it may not have started or why it stopped.
 *
 * @return Current profiler status code
 */
kubesense_profiler_status_t kubesense_profiler_get_status(void);

/**
 * @brief Returns and resets profiling diagnostics accumulated since the last call.
 *
 * @return Profiling diagnostics, or zeroed diagnostics if the profiler does not exist.
 */
kubesense_profiler_diagnostics_t kubesense_profiler_diagnostics(void);

/**
 * @brief Stops profiling if it's currently running
 *
 * This function should be called when the application no longer needs profiling. It will:
 *
 * - Stop the sampling thread
 * - Flush any remaining collected samples
 * - Set the profiler state to inactive
 *
 * After calling this function, `kubesense_profiler_get_status()` will return `KUBESENSE_PROFILER_STATUS_STOPPED`.
 *
 * @note Safe to call multiple times - subsequent calls are no-ops
 * @note Safe to call even if profiling was never started
 *
 * @warning Once stopped, profiling cannot be restarted in the same process
 *
 * @see `kubesense_profiler_get_status()`
 */
void kubesense_profiler_stop(void);

/**
 * @brief Retrieves the current profile
 *
 * Returns a typed handle to the profile data being collected.
 *
 * @return Typed handle to profile data, or NULL if profiling was never started
 *         or no profile exists
 */
kubesense_profile_t* kubesense_profiler_get_profile(void);

/**
 * @brief Flushes the sampling buffer and retrieves the profile
 *
 * Requests a flush of pending samples, then atomically swaps the internal
 * profile with a fresh empty one in the aggregation stream. Sampling continues
 * uninterrupted into the new profile.
 *
 * @return Typed handle to profile data, or NULL if:
 *         - Profiling was never started
 *         - No samples were collected
 */
kubesense_profile_t* kubesense_profiler_flush_and_get_profile(void);

/**
 * @brief Sets the server time correction used for exported profile timestamps.
 *
 * The latest value is applied to the active profile and to future profiles
 * created after flushing.
 *
 * @param offset_ns Server time offset in nanoseconds
 */
void kubesense_profiler_set_server_time_offset_ns(int64_t offset_ns);

/**
 * @brief Destroys the kubesense profiler data and frees all associated memory
 *
 * This function should be called when the profile data is no longer needed
 * to free memory resources.
 *
 * @note Safe to call multiple times - subsequent calls are no-ops
 * @note Safe to call even if profiling was never started
 *
 * @warning After calling this function, any previously returned profile handles become invalid
 *
 * @see `kubesense_profiler_get_profile()`, `kubesense_profiler_flush_and_get_profile()`
 */
void kubesense_profiler_destroy(void);

#ifdef __cplusplus
}
#endif

#endif // !TARGET_OS_WATCH
#endif // __APPLE__

#endif // KUBESENSE_PROFILER_PROFILER_H_
