/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#ifndef KUBESENSE_PROFILER_KUBESENSE_PPROF_TESTING_H_
#define KUBESENSE_PROFILER_KUBESENSE_PPROF_TESTING_H_

#ifdef __APPLE__
#include <TargetConditionals.h>
#if !TARGET_OS_WATCH

#include <stddef.h>
#include "kubesense_pprof.h"

#ifdef __cplusplus
extern "C" {
#endif

/**
 * Returns the number of deduplicated samples stored in the profile.
 *
 * @param profile Profile pointer or NULL.
 * @return Sample count, or 0 if `profile` is NULL.
 *
 * @warning FOR TESTING USE ONLY - Not intended for production environments
 */
size_t kubesense_pprof_sample_count(kubesense_pprof_t* profile);

#ifdef __cplusplus
}
#endif

#endif // !TARGET_OS_WATCH
#endif // __APPLE__

#endif // KUBESENSE_PROFILER_KUBESENSE_PPROF_TESTING_H_
