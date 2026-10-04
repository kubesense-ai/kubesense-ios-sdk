/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseCore;
@import KubesenseInternal;

@interface KubesenseSDK_apiTests : XCTestCase
@end

/*
 * Objc APIs smoke tests - only check if the interface is available to Objc.
 */
@implementation KubesenseSDK_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

- (void)testDDTrackingConsentAPI {
    [KubesenseTrackingConsent granted];
    [KubesenseTrackingConsent notGranted];
    [KubesenseTrackingConsent pending];
}

- (void)testDDKubesense {
    KubesenseConfiguration *configuration = [[KubesenseConfiguration alloc] initWithClientToken:@"abc" env:@"def"];

    [KubesenseSDK initializeWithConfiguration:configuration trackingConsent:[KubesenseTrackingConsent notGranted]];

    [KubesenseSDK isInitialized];

    KubesenseCoreLoggerLevel verbosity = [KubesenseSDK verbosityLevel];
    [KubesenseSDK setVerbosityLevel:verbosity];

    [KubesenseSDK setUserInfoWithUserId:@"" name:@"" email:@"" extraInfo:@{}];
    [KubesenseSDK addUserExtraInfo:@{}];
    [KubesenseSDK setTrackingConsentWithConsent:[KubesenseTrackingConsent notGranted]];

    [KubesenseSDK clearAllData];
    [KubesenseSDK stopInstance];
}

- (void)testDDKubesenseInstanceNameAPI {
    NSString *instanceName = @"test-instance";
    KubesenseConfiguration *configuration = [[KubesenseConfiguration alloc] initWithClientToken:@"abc" env:@"def"];

    [KubesenseSDK initializeWithConfiguration:configuration trackingConsent:[KubesenseTrackingConsent notGranted] instanceName:instanceName];

    XCTAssertTrue([KubesenseSDK isInitializedWithInstanceName:instanceName]);

    [KubesenseSDK setUserInfoWithUserId:@"user-id" instanceName:instanceName name:@"name" email:@"email" extraInfo:@{}];
    [KubesenseSDK addUserExtraInfo:@{} instanceName:instanceName];
    [KubesenseSDK clearUserInfoWithInstanceName:instanceName];

    [KubesenseSDK setAccountInfoWithAccountId:@"account-id" instanceName:instanceName name:@"name" extraInfo:@{}];
    [KubesenseSDK addAccountExtraInfo:@{} instanceName:instanceName];
    [KubesenseSDK clearAccountInfoWithInstanceName:instanceName];

    [KubesenseSDK setTrackingConsentWithConsent:[KubesenseTrackingConsent notGranted] instanceName:instanceName];
    [KubesenseSDK clearAllDataWithInstanceName:instanceName];
    [KubesenseSDK stopInstanceWithInstanceName:instanceName];
}

#pragma clang diagnostic pop

@end
