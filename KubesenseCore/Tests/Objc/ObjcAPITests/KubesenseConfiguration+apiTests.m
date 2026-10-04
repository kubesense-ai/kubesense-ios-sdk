/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseCore;
@import KubesenseCrashReporting;

// MARK: - KubesenseDataEncryption

@interface CustomDDDataEncryption: NSObject <KubesenseDataEncryption>
@end

@implementation CustomDDDataEncryption

- (NSData * _Nullable)decryptWithData:(NSData * _Nonnull)data error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    return data;
}

- (NSData * _Nullable)encryptWithData:(NSData * _Nonnull)data error:(NSError * _Nullable __autoreleasing * _Nullable)error {
    return data;
}

@end

// MARK: - Tests

@interface KubesenseConfiguration_apiTests : XCTestCase
@end

/*
 * Objc APIs smoke tests - only check if the interface is available to Objc.
 */
@implementation KubesenseConfiguration_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

- (void)testDDSiteAPI {
    [KubesenseSite prod];
    [KubesenseSite staging];
}

- (void)testDDBatchSizeAPI {
    KubesenseBatchSizeSmall; KubesenseBatchSizeMedium; KubesenseBatchSizeLarge;
}

- (void)testDDUploadFrequencyAPI {
    KubesenseUploadFrequencyRare; KubesenseUploadFrequencyAverage; KubesenseUploadFrequencyFrequent;
}

- (void)testDDConfigurationBuilderAPI {
    KubesenseConfiguration *configuration = [[KubesenseConfiguration alloc] initWithClientToken:@"abc" env:@"def"];

    configuration.site = [KubesenseSite prod];
    configuration.site = [KubesenseSite staging];
    configuration.kubesenseRumEndpoint = @"collector.example.com";
    configuration.service = @"";
    configuration.bundle = [NSBundle mainBundle];
    configuration.batchSize = KubesenseBatchSizeMedium;
    configuration.uploadFrequency = KubesenseUploadFrequencyAverage;
    configuration.additionalConfiguration = @{@"additional": @"config"};
    [configuration setEncryption:[CustomDDDataEncryption new]];
    configuration.backgroundTasksEnabled = true;
    configuration.remoteConfigurationEnabled = false;
    configuration.remoteConfigurationRefreshPeriod = 3600;
}

- (void)testKubesenseCrashReporterAPI {
    [KubesenseCrashReporter enable];

    KubesenseCrashReporterConfiguration *configuration = [KubesenseCrashReporterConfiguration new];
    XCTAssertTrue(configuration.appHangBacktraceEnabled, @"App Hang backtraces are enabled by default");
    configuration.appHangBacktraceEnabled = NO;
    XCTAssertFalse(configuration.appHangBacktraceEnabled, @"The setter must write through to the wrapped configuration");

    [KubesenseCrashReporter enableWith:configuration];
}

#pragma clang diagnostic pop

@end
