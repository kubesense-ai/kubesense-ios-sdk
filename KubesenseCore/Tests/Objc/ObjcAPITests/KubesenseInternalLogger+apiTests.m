/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseInternal;

@interface KubesenseInternalLogger_apiTests : XCTestCase
@end

/*
 * `KubesenseInternalLogger` APIs smoke tests - only check if the interface is available to Objc.
 */
@implementation KubesenseInternalLogger_apiTests

- (void)testKubesenseInternalLogger {

    [KubesenseInternalLogger consolePrint:@"" :KubesenseCoreLoggerLevelWarn];
    [KubesenseInternalLogger telemetryDebugWithId:@"" message:@""];
    [KubesenseInternalLogger telemetryErrorWithId:@"" message:@"" kind:@"" stack:@""];
}

@end
