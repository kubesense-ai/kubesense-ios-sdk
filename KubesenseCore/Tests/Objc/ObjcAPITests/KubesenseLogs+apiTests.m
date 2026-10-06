/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseLogs;

@interface KubesenseLogs_apiTests : XCTestCase
@end

/*
 * Objc API for smoke tests - minimal assertions, mainly check if the interface is available to Objc.
 */
@implementation KubesenseLogs_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"
#pragma clang diagnostic ignored "-Wunused-variable"

- (void)testKubesenseLogsAPI {
    KubesenseLogsConfiguration *config = [[KubesenseLogsConfiguration alloc] init];
    [KubesenseLogs enableWith:config];

    [KubesenseLogs addAttributeForKey:@"key1" value:@"value"];
    [KubesenseLogs addAttributeForKey:@"key2" value:@1];
    [KubesenseLogs addAttributeForKey:@"key3" value:@YES];
    [KubesenseLogs addAttributeForKey:@"key4" value:@[@"array"]];
    [KubesenseLogs addAttributeForKey:@"key5" value:@{@"key": @"value"}];

    [KubesenseLogs removeAttributeForKey:@"key1"];
    [KubesenseLogs removeAttributeForKey:@"keyNotAdded"];
}

- (void)testKubesenseLogsInstanceNameAPI {
    NSString *instanceName = @"logs-test-instance";
    KubesenseLogsConfiguration *config = [[KubesenseLogsConfiguration alloc] init];
    [KubesenseLogs enableWith:config instanceName:instanceName];

    [KubesenseLogs addAttributeForKey:@"key1" value:@"value" instanceName:instanceName];
    [KubesenseLogs removeAttributeForKey:@"key1" instanceName:instanceName];
}

- (void)testKubesenseLoggerInstanceNameAPI {
    NSString *instanceName = @"logger-test-instance";
    KubesenseLoggerConfiguration *config = [[KubesenseLoggerConfiguration alloc] init];
    KubesenseLogger *logger = [KubesenseLogger createWith:config instanceName:instanceName];
    [logger debug:@"debug"];
}

- (void)testKubesenseLogsConfigurationAPI {
    KubesenseLogsConfiguration *config = [KubesenseLogsConfiguration new];

    [config setEventMapper:^KubesenseLogEvent * (KubesenseLogEvent* logEvent) {
        logEvent.message = @"log message";
        return logEvent;
    }];
}

- (void)testKubesenseLoggerAPI {
    KubesenseLoggerConfiguration *config = [[KubesenseLoggerConfiguration alloc] init];

    KubesenseLogger* logger = [KubesenseLogger createWith:config];
    [logger addAttributeForKey:@"key" value:@"value"];
    [logger removeAttributeForKey:@"key"];
    [logger addTagWithKey:@"key" value:@"value"];
    [logger removeTagWithKey:@"key"];
    [logger addWithTag:@"foo"];
    [logger removeWithTag:@"foo"];

    [logger debug:@"debug"];
    [logger debug:@"debug" attributes:@{}];
    [logger debug:@"debug" error: [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil] attributes:@{}];
    [logger info:@"info"];
    [logger info:@"info" attributes:@{}];
    [logger info:@"info" error: [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil] attributes:@{}];
    [logger notice:@"notice"];
    [logger notice:@"notice" attributes:@{}];
    [logger notice:@"notice" error: [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil] attributes:@{}];
    [logger warn:@"warn"];
    [logger warn:@"warn" attributes:@{}];
    [logger warn:@"warn" error: [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil] attributes:@{}];
    [logger error:@"error"];
    [logger error:@"error" attributes:@{}];
    [logger error:@"error" error: [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil] attributes:@{}];
    [logger critical:@"critical"];
    [logger critical:@"critical" attributes:@{}];
    [logger critical:@"critical" error: [NSError errorWithDomain:NSCocoaErrorDomain code:-1 userInfo:nil] attributes:@{}];
}

- (void)testKubesenseLoggerConfigurationAPI {
    KubesenseLoggerConfiguration *config = [[KubesenseLoggerConfiguration alloc]
                                     initWithService:nil
                                     name:nil
                                     networkInfoEnabled:NO
                                     bundleWithRumEnabled:NO
                                     bundleWithTraceEnabled:NO
                                     remoteSampleRate:0
                                     remoteLogThreshold:KubesenseLogLevelDebug
                                     printLogsToConsole:NO];

    XCTAssertNil(config.service);
    config.service = @"service";
    XCTAssertNotNil(config.service);

    XCTAssertNil(config.name);
    config.name = @"name";
    XCTAssertNotNil(config.name);

    XCTAssertFalse(config.networkInfoEnabled);
    config.networkInfoEnabled = YES;
    XCTAssertTrue(config.networkInfoEnabled);

    XCTAssertFalse(config.bundleWithRumEnabled);
    config.bundleWithRumEnabled = YES;
    XCTAssertTrue(config.bundleWithRumEnabled);

    XCTAssertFalse(config.bundleWithTraceEnabled);
    config.bundleWithTraceEnabled = YES;
    XCTAssertTrue(config.bundleWithTraceEnabled);

    XCTAssertEqual(config.remoteSampleRate, 0);
    config.remoteSampleRate = 100;
    XCTAssertEqual(config.remoteSampleRate, 100);

    XCTAssertEqual(config.remoteLogThreshold, KubesenseLogLevelDebug);
    config.remoteLogThreshold = KubesenseLogLevelError;
    XCTAssertEqual(config.remoteLogThreshold, KubesenseLogLevelError);

    XCTAssertFalse(config.printLogsToConsole);
    config.printLogsToConsole = YES;
    XCTAssertTrue(config.printLogsToConsole);
}


#pragma clang diagnostic pop

@end

