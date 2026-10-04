/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseTrace;

@interface KubesenseTrace_apiTests : XCTestCase
@end

/*
 * Objc APIs smoke tests - minimal assertions, mainly check if the interface is available to Objc.
 */
@implementation KubesenseTrace_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"
#pragma clang diagnostic ignored "-Wunused-variable"

- (void)testDDTraceAPI {
    KubesenseTraceConfiguration *config = [[KubesenseTraceConfiguration alloc] init];
    [KubesenseTrace enableWith:config];
}

- (void)testDDTraceInstanceNameAPI {
    KubesenseTraceConfiguration *config = [[KubesenseTraceConfiguration alloc] init];
    NSString *instanceName = @"trace-test-instance";
    [KubesenseTrace enableWith:config instanceName:instanceName];
    id<OTTracer> tracer = [KubesenseTracer sharedWithInstanceName:instanceName];
    (void)tracer;
}

- (void)testDDTraceConfigurationAPI {
    KubesenseTraceConfiguration *config = [[KubesenseTraceConfiguration alloc] init];

    XCTAssertEqual(config.sampleRate, 100);
    config.sampleRate = 10;
    XCTAssertEqual(config.sampleRate, 10);

    XCTAssertNil(config.service);
    config.service = @"custom-service";
    XCTAssertNotNil(config.service);

    XCTAssertNil(config.tags);
    config.tags = @{};
    XCTAssertNotNil(config.tags);

    KubesenseTraceFirstPartyHostsTracing *tracing;
    tracing = [[KubesenseTraceFirstPartyHostsTracing alloc] initWithHosts:[NSSet new] sampleRate:20];
    tracing = [[KubesenseTraceFirstPartyHostsTracing alloc] initWithHosts:[NSSet new]];
    tracing = [[KubesenseTraceFirstPartyHostsTracing alloc] initWithHostsWithHeaderTypes:@{}];
    tracing = [[KubesenseTraceFirstPartyHostsTracing alloc] initWithHostsWithHeaderTypes:@{} sampleRate:20];
    KubesenseTraceURLSessionTracking *urlSessionTracking = [[KubesenseTraceURLSessionTracking alloc] initWithFirstPartyHostsTracing:tracing];

    config.bundleWithRumEnabled = NO;
    XCTAssertFalse(config.bundleWithRumEnabled);

    config.networkInfoEnabled = YES;
    XCTAssertTrue(config.networkInfoEnabled);
}

- (void)testDDTracerAPI {
    id<OTSpan> rootSpan = [[KubesenseTracer shared] startRootSpan:@"" tags:NULL startTime:NULL customSampleRate:NULL];
    [rootSpan setActive];
    [[KubesenseTracer shared] startSpan:@""];
    [[KubesenseTracer shared] startSpan:@"" tags:@{}];
    [[KubesenseTracer shared] startSpan:@"" childOf:NULL];
    id<OTSpan> span = [[KubesenseTracer shared] startSpan:@"" childOf:NULL tags:NULL startTime:NULL];
    [span finish];
    [span finishWithTime:NULL];
}

#pragma clang diagnostic pop

@end
