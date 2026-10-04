/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseTrace;

@interface KubesenseB3HTTPHeadersWriter_apiTests : XCTestCase
@end

/*
 * Objc APIs smoke tests - only check if the interface is available to Objc.
 */
@implementation KubesenseB3HTTPHeadersWriter_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

- (void)testInitWithSamplingRate {
    [[KubesenseB3HTTPHeadersWriter alloc] initWithInjectEncoding:KubesenseInjectEncodingSingle
                                    traceContextInjection:KubesenseTraceContextInjectionAll];
}

#pragma clang diagnostic pop

@end
