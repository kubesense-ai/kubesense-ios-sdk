/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
#include <sys/wait.h>
@import KubesenseCore;
@import KubesenseTrace;

#import <Foundation/Foundation.h>

@interface MockDelegate : NSObject <NSURLSessionDataDelegate>
@end

@implementation MockDelegate
@end

@interface KubesenseURLSessionInstrumentationTests_apiTests : XCTestCase
@end

@implementation KubesenseURLSessionInstrumentationTests_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

- (void)setUp {
    [super setUp];

    KubesenseConfiguration *configuration = [[KubesenseConfiguration alloc] initWithClientToken:@"abc" env:@"def"];
    [KubesenseSDK initializeWithConfiguration:configuration trackingConsent:[KubesenseTrackingConsent notGranted]];

    KubesenseTraceConfiguration *config = [[KubesenseTraceConfiguration alloc] init];
    KubesenseTraceFirstPartyHostsTracing *tracing = [[KubesenseTraceFirstPartyHostsTracing alloc] initWithHosts:[NSSet new] sampleRate:20];
    KubesenseTraceURLSessionTracking *urlSessionTracking = [[KubesenseTraceURLSessionTracking alloc] initWithFirstPartyHostsTracing:tracing];
    [config setURLSessionTracking:urlSessionTracking];
    [KubesenseTraceSDK enableWith:config];
}

- (void)tearDown {
    [super tearDown];

    [KubesenseSDK clearAllData];
    [KubesenseSDK flushAndDeinitialize];
}

- (void)testWorkflow {
    XCTestExpectation *expectation = [self expectationWithDescription:@"task completed"];
    KubesenseURLSessionInstrumentationConfiguration *config = [[KubesenseURLSessionInstrumentationConfiguration alloc] initWithDelegateClass:[MockDelegate class]];
    [KubesenseURLSessionInstrumentation enableDurationBreakdownWith:config];

    NSURLSession *session = [NSURLSession sessionWithConfiguration:[NSURLSessionConfiguration defaultSessionConfiguration]
                                                          delegate:[MockDelegate new] delegateQueue:nil];
    NSURLSessionTask *task = [session dataTaskWithURL:[NSURL URLWithString:@"https://status.kubesense.ai"]
                                    completionHandler:^(NSData * _Nullable data, NSURLResponse * _Nullable response, NSError * _Nullable error) {
        [expectation fulfill];
    }];
    [task resume];

    [self waitForExpectationsWithTimeout:10 handler:nil];

    [KubesenseURLSessionInstrumentation disableWithDelegateClass:[MockDelegate class]];
}

- (void)testURLSessionInstrumentationInstanceNameAPI {
    KubesenseURLSessionInstrumentationConfiguration *config = [[KubesenseURLSessionInstrumentationConfiguration alloc] initWithDelegateClass:[MockDelegate class]];
    NSString *instanceName = @"urlsession-test-instance";
    [KubesenseURLSessionInstrumentation enableDurationBreakdownWith:config instanceName:instanceName];
    [KubesenseURLSessionInstrumentation disableWithDelegateClass:[MockDelegate class] instanceName:instanceName];
}

#pragma clang diagnostic pop

@end
