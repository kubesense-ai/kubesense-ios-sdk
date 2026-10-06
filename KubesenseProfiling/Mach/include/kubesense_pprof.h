/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#ifndef KUBESENSE_PROFILER_KUBESENSE_PPROF_H_
#define KUBESENSE_PROFILER_KUBESENSE_PPROF_H_

#ifdef __APPLE__
#include <TargetConditionals.h>
#if !TARGET_OS_WATCH

#include <stdint.h>
#include <stddef.h>
#include "kubesense_profiler.h"

#ifdef __cplusplus
namespace kubesense::profiler {

class profile;

} // namespace kubesense:profiler

extern "C" {
#endif

/**
 * Opaque handle to a profile instance
 */
#ifdef __cplusplus
typedef kubesense::profiler::profile kubesense_pprof_t;
#else
typedef struct profile kubesense_pprof_t;
#endif

/**
 * Create a new pprof profile aggregator
 * 
 * @param sampling_interval_ns The sampling interval in nanoseconds
 * @return Pointer to the created profile, or NULL on failure
 */
kubesense_pprof_t* kubesense_pprof_create(uint64_t sampling_interval_ns);

/**
 * Create a new pprof profile aggregator with optional CPU-time sample values.
 *
 * @param sampling_interval_ns The sampling interval in nanoseconds
 * @param record_cpu_time Whether samples should include CPU time as a second value
 * @return Pointer to the created profile, or NULL on failure
 */
kubesense_pprof_t* kubesense_pprof_create_with_cpu_time(uint64_t sampling_interval_ns, bool record_cpu_time);

/**
 * Destroy a pprof profile aggregator and free all associated memory
 *
 * @param profile Pointer to the profile to destroy
 */
void kubesense_pprof_destroy(kubesense_pprof_t* profile);

/**
 * Add stack traces to the profile
 *
 * @param profile Pointer to the profile
 * @param traces Array of stack traces to add
 * @param count Number of traces in the array
 */
void kubesense_pprof_add_samples(kubesense_pprof_t* profile, const stack_trace_t* traces, size_t count);

/**
 * Serialize the profile to protobuf format
 *
 * @param profile Pointer to the profile
 * @param data Output parameter for the serialized data (caller must free with kubesense_pprof_free_serialized_data)
 * @return Size of the serialized data in bytes, or 0 on failure
 */
size_t kubesense_pprof_serialize(kubesense_pprof_t* profile, uint8_t** data);

/**
 * Free memory allocated by kubesense_pprof_serialize
 *
 * @param data Pointer to the data to free
 */
void kubesense_pprof_free_serialized_data(const uint8_t* data);

/**
 * Callback function that resolves binary images and forwards stack traces
 * to a kubesense_pprof_t instance.
 *
 * Performs full Mach-O header parsing for image resolution (no cache).
 */
void kubesense_pprof_callback(stack_trace_t* traces, size_t count, void* ctx);

/**
 * Get profile start timestamp in seconds since Unix epoch
 *
 * @param profile Pointer to the profile
 * @return Start timestamp in seconds since Unix epoch, or 0.0 if no samples
 */
double kubesense_pprof_get_start_timestamp_s(kubesense_pprof_t* profile);

/**
 * Get profile end timestamp in seconds since Unix epoch
 *
 * @param profile Pointer to the profile
 * @return End timestamp in seconds since Unix epoch, or 0.0 if no samples
 */
double kubesense_pprof_get_end_timestamp_s(kubesense_pprof_t* profile);

/**
 * Set the server time correction used for exported timestamps.
 *
 * @param profile Pointer to the profile
 * @param offset_ns Server time offset in nanoseconds
 */
void kubesense_pprof_set_server_time_offset_ns(kubesense_pprof_t* profile, int64_t offset_ns);

#ifdef __cplusplus
}
#endif

#endif // !TARGET_OS_WATCH
#endif // __APPLE__

#endif // KUBESENSE_PROFILER_KUBESENSE_PPROF_H_
