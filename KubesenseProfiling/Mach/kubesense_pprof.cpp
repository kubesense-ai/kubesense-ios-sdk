/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#include "kubesense_pprof.h"

#if defined(__APPLE__) && !TARGET_OS_WATCH

#include <cstdlib>

#include "kubesense_pprof_testing.h"
#include "profile.h"
#include "profile_pprof_packer.h"
#include "binary_image_resolver.h"

// C interface implementation
extern "C" {

kubesense_pprof_t* kubesense_pprof_create(uint64_t sampling_interval_ns) {
    return kubesense_pprof_create_with_cpu_time(sampling_interval_ns, false);
}

kubesense_pprof_t* kubesense_pprof_create_with_cpu_time(uint64_t sampling_interval_ns, bool record_cpu_time) {
    try {
        auto* profiler = new dd::profiler::profile(sampling_interval_ns, record_cpu_time);
        return reinterpret_cast<kubesense_pprof_t*>(profiler);
    } catch (...) {
        return nullptr;
    }
}

void kubesense_pprof_destroy(kubesense_pprof_t* profile) {
    if (profile) {
        delete reinterpret_cast<dd::profiler::profile*>(profile);
    }
}

void kubesense_pprof_add_samples(kubesense_pprof_t* profile, const stack_trace_t* traces, size_t count) {
    if (profile && traces && count > 0) {
        reinterpret_cast<dd::profiler::profile*>(profile)->add_samples(traces, count);
    }
}

size_t kubesense_pprof_serialize(kubesense_pprof_t* profile, uint8_t** data) {
    if (!profile || !data) return 0;
    return dd::profiler::profile_pprof_pack(*reinterpret_cast<dd::profiler::profile*>(profile), data);
}

void kubesense_pprof_free_serialized_data(const uint8_t* data) {
    if (data) std::free(const_cast<uint8_t*>(data));
}

void kubesense_pprof_callback(stack_trace_t* traces, size_t count, void* ctx) {
    kubesense_pprof_t* profile = static_cast<kubesense_pprof_t*>(ctx);
    if (profile && traces && count > 0) {
        // Resolve binary images in-place
        dd::profiler::resolve_stack_trace_frames(traces, count, nullptr);
        kubesense_pprof_add_samples(profile, traces, count);

        // Free image data we allocated
        for (size_t i = 0; i < count; i++) {
            for (uint32_t j = 0; j < traces[i].frame_count; j++) {
                binary_image_destroy(&traces[i].frames[j].image);
            }
        }
    }
}

double kubesense_pprof_get_start_timestamp_s(kubesense_pprof_t* profile) {
    if (!profile) return 0.0;
    int64_t timestamp = reinterpret_cast<dd::profiler::profile*>(profile)->start_timestamp();
    return static_cast<double>(timestamp) / 1e9; // to seconds
}

double kubesense_pprof_get_end_timestamp_s(kubesense_pprof_t* profile) {
    if (!profile) return 0.0;
    int64_t timestamp = reinterpret_cast<dd::profiler::profile*>(profile)->end_timestamp();
    return static_cast<double>(timestamp) / 1e9; // to seconds
}

void kubesense_pprof_set_server_time_offset_ns(kubesense_pprof_t* profile, int64_t offset_ns) {
    if (!profile) return;
    reinterpret_cast<dd::profiler::profile*>(profile)->set_server_time_offset_ns(offset_ns);
}

size_t kubesense_pprof_sample_count(kubesense_pprof_t* profile) {
    if (!profile) return 0;
    return reinterpret_cast<dd::profiler::profile*>(profile)->samples().size();
}

} // extern "C"

#endif // __APPLE__ && !TARGET_OS_WATCH
