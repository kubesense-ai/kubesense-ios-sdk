/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */

#import <XCTest/XCTest.h>

#if TARGET_OS_IOS

@import KubesenseSessionReplay;

@interface KubesenseSessionReplaySDK_apiTests : XCTestCase
@end

@implementation KubesenseSessionReplaySDK_apiTests

// MARK: Configuration

- (void)testConfigurationWithNewApi {
    KubesenseSessionReplayConfiguration *configuration = [[KubesenseSessionReplayConfiguration alloc] initWithReplaySampleRate:100
                                                                                        textAndInputPrivacyLevel:KubesenseTextAndInputPrivacyLevelMaskAll
                                                                                               imagePrivacyLevel:KubesenseImagePrivacyLevelMaskNone
                                                                                               touchPrivacyLevel:KubesenseTouchPrivacyLevelShow
                                                                                                    featureFlags:nil];

    configuration.textAndInputPrivacyLevel = KubesenseTextAndInputPrivacyLevelMaskSensitiveInputs;
    configuration.imagePrivacyLevel = KubesenseImagePrivacyLevelMaskAll;
    configuration.touchPrivacyLevel = KubesenseTouchPrivacyLevelHide;

    [KubesenseSessionReplaySDK enableWith:configuration];
}

- (void)testStartAndStopRecording {
    [KubesenseSessionReplaySDK startRecording];
    [KubesenseSessionReplaySDK stopRecording];
}

- (void)testSessionReplayInstanceNameAPI {
    KubesenseSessionReplayConfiguration *configuration = [[KubesenseSessionReplayConfiguration alloc] initWithReplaySampleRate:100
                                                                                        textAndInputPrivacyLevel:KubesenseTextAndInputPrivacyLevelMaskAll
                                                                                               imagePrivacyLevel:KubesenseImagePrivacyLevelMaskNone
                                                                                               touchPrivacyLevel:KubesenseTouchPrivacyLevelShow
                                                                                                    featureFlags:nil];
    NSString *instanceName = @"sr-test-instance";
    [KubesenseSessionReplaySDK enableWith:configuration instanceName:instanceName];
    [KubesenseSessionReplaySDK startRecordingWithInstanceName:instanceName];
    [KubesenseSessionReplaySDK stopRecordingWithInstanceName:instanceName];
}

- (void)testStartRecordingImmediately {
    KubesenseSessionReplayConfiguration *configuration = [[KubesenseSessionReplayConfiguration alloc] initWithReplaySampleRate:100
                                                                                        textAndInputPrivacyLevel:KubesenseTextAndInputPrivacyLevelMaskAll
                                                                                               imagePrivacyLevel:KubesenseImagePrivacyLevelMaskAll
                                                                                               touchPrivacyLevel:KubesenseTouchPrivacyLevelHide
                                                                                                    featureFlags:nil];

    configuration.startRecordingImmediately = false;

    XCTAssertFalse(configuration.startRecordingImmediately);
}

// MARK: Privacy Overrides
- (void)testSettingAndGettingOverrides {
    // Given
    UIView *view = [[UIView alloc] init];

    // When
    view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = KubesenseTextAndInputPrivacyLevelOverrideMaskAll;
    view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = KubesenseImagePrivacyLevelOverrideMaskAll;
    view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = KubesenseTouchPrivacyLevelOverrideHide;
    view.kubesenseSessionReplayPrivacyOverrides.hide = @YES;

    // Then
    XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy, KubesenseTextAndInputPrivacyLevelOverrideMaskAll);
    XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy, KubesenseImagePrivacyLevelOverrideMaskAll);
    XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy, KubesenseTouchPrivacyLevelOverrideHide);
    XCTAssertTrue(view.kubesenseSessionReplayPrivacyOverrides.hide.boolValue);
}

- (void)testClearingOverride {
    // Given
    UIView *view = [[UIView alloc] init];

    // Set initial values
    view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = KubesenseTextAndInputPrivacyLevelOverrideMaskAll;
    view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = KubesenseImagePrivacyLevelOverrideMaskAll;
    view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = KubesenseTouchPrivacyLevelOverrideHide;
    view.kubesenseSessionReplayPrivacyOverrides.hide = @YES;

    // When
    view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy = KubesenseTextAndInputPrivacyLevelOverrideNone;
    view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy = KubesenseImagePrivacyLevelOverrideNone;
    view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy = KubesenseTouchPrivacyLevelOverrideNone;
    view.kubesenseSessionReplayPrivacyOverrides.hide = nil;

    // Then
    XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.textAndInputPrivacy, KubesenseTextAndInputPrivacyLevelOverrideNone);
    XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.imagePrivacy, KubesenseImagePrivacyLevelOverrideNone);
    XCTAssertEqual(view.kubesenseSessionReplayPrivacyOverrides.touchPrivacy, KubesenseTouchPrivacyLevelOverrideNone);
    XCTAssertNil(view.kubesenseSessionReplayPrivacyOverrides.hide);
}
@end

#endif
