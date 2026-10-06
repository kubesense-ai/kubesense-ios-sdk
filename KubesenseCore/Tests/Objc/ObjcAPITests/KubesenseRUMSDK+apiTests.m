/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseRUM;
@import KubesenseInternal;

// MARK: - KubesenseNetworkSettledResourcePredicate

@interface CustomKubesenseNetworkSettledResourcePredicate: NSObject
@end

@interface CustomKubesenseNetworkSettledResourcePredicate () <KubesenseNetworkSettledResourcePredicate>
@end

@implementation CustomKubesenseNetworkSettledResourcePredicate
- (BOOL)isInitialResourceFrom:(KubesenseTNSResourceParams * _Nonnull)resourceParams { return YES; }
@end

// MARK: - KubesenseNextViewActionPredicate

@interface CustomKubesenseNextViewActionPredicate: NSObject
@end

@interface CustomKubesenseNextViewActionPredicate () <KubesenseNextViewActionPredicate>
@end

@implementation CustomKubesenseNextViewActionPredicate
- (BOOL)isLastActionFrom:(KubesenseINVActionParams * _Nonnull)actionParams { return YES; }
@end

#if !TARGET_OS_WATCH

// MARK: - KubesenseUIKitRUMViewsPredicate

@interface CustomKubesenseUIKitRUMViewsPredicate: NSObject
@end

@interface CustomKubesenseUIKitRUMViewsPredicate () <KubesenseUIKitRUMViewsPredicate>
@end

@implementation CustomKubesenseUIKitRUMViewsPredicate
- (KubesenseRUMView * _Nullable)rumViewFor:(UIViewController * _Nonnull)viewController { return nil; }
@end

// MARK: - KubesenseUIKitRUMActionsPredicate

@interface CustomKubesenseUIKitRUMActionsPredicate: NSObject
@end

@interface CustomKubesenseUIKitRUMActionsPredicate () <KubesenseUIKitRUMActionsPredicate>
@end

@implementation CustomKubesenseUIKitRUMActionsPredicate
- (KubesenseRUMAction * _Nullable)rumActionWithTargetView:(UIView * _Nonnull)targetView { return nil; }
- (KubesenseRUMAction * _Nullable)rumActionWithPress:(enum UIPressType)type targetView:(UIView * _Nonnull)targetView { return nil; }

@end

#endif

// MARK: - KubesenseRUMSDK tests

@interface KubesenseRUMSDK_apiTests : XCTestCase
@end

/*
 * Objc APIs smoke tests - minimal assertions, mainly check if the interface is available to Objc.
 */
@implementation KubesenseRUMSDK_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

- (void)testKubesenseRUMAPI {
    KubesenseRUMConfiguration *config = [[KubesenseRUMConfiguration alloc] initWithApplicationID:@"app-id"];
    [KubesenseRUMSDK enableWith:config];
}

- (void)testKubesenseRUMInstanceNameAPI {
    KubesenseRUMConfiguration *config = [[KubesenseRUMConfiguration alloc] initWithApplicationID:@"app-id"];
    NSString *instanceName = @"rum-test-instance";
    [KubesenseRUMSDK enableWith:config instanceName:instanceName];
    KubesenseRUMMonitor *monitor = [KubesenseRUMMonitor sharedWithInstanceName:instanceName];
    (void)monitor;
}

- (void)testKubesenseRUMConfigurationAPI {
    KubesenseRUMConfiguration *config = [[KubesenseRUMConfiguration alloc] initWithApplicationID:@"app-id"];
    XCTAssertEqual(config.applicationID, @"app-id");

    XCTAssertEqual(config.sessionSampleRate, 100);
    config.sessionSampleRate = 10;
    XCTAssertEqual(config.sessionSampleRate, 10);

    XCTAssertEqual(config.telemetrySampleRate, 20);
    config.telemetrySampleRate = 30;
    XCTAssertEqual(config.telemetrySampleRate, 30);

    XCTAssertNotNil(config.networkSettledResourcePredicate);
    CustomKubesenseNetworkSettledResourcePredicate *tnsPredicate = [CustomKubesenseNetworkSettledResourcePredicate new];
    config.networkSettledResourcePredicate = tnsPredicate;
    XCTAssertIdentical(config.networkSettledResourcePredicate, tnsPredicate);

    KubesenseTimeBasedTNSResourcePredicate *defaultTNSPredicate = [[KubesenseTimeBasedTNSResourcePredicate alloc] initWithThreshold:0.2];
    config.networkSettledResourcePredicate = defaultTNSPredicate;
    XCTAssertNotNil(config.networkSettledResourcePredicate);

    XCTAssertNotNil(config.nextViewActionPredicate);
    CustomKubesenseNextViewActionPredicate *invPredicate = [CustomKubesenseNextViewActionPredicate new];
    config.nextViewActionPredicate = invPredicate;
    XCTAssertIdentical(config.nextViewActionPredicate, invPredicate);

    KubesenseTimeBasedINVActionPredicate *defaultINVPredicate = [[KubesenseTimeBasedINVActionPredicate alloc] initWithMaxTimeToNextView:5.0];
    config.nextViewActionPredicate = defaultINVPredicate;
    XCTAssertNotNil(config.nextViewActionPredicate);

#if !TARGET_OS_WATCH
    XCTAssertNil(config.uiKitViewsPredicate);
    CustomKubesenseUIKitRUMViewsPredicate *viewsPredicate = [CustomKubesenseUIKitRUMViewsPredicate new];
    config.uiKitViewsPredicate = viewsPredicate;
    XCTAssertIdentical(config.uiKitViewsPredicate, viewsPredicate);

    XCTAssertNil(config.uiKitActionsPredicate);
    CustomKubesenseUIKitRUMActionsPredicate *actionsPredicate = [CustomKubesenseUIKitRUMActionsPredicate new];
    config.uiKitActionsPredicate = actionsPredicate;
    XCTAssertIdentical(config.uiKitActionsPredicate, actionsPredicate);

    XCTAssertNil(config.swiftUIViewsPredicate);
    KubesenseDefaultSwiftUIRUMViewsPredicate *swiftUIViewsPredicate = [KubesenseDefaultSwiftUIRUMViewsPredicate new];
    config.swiftUIViewsPredicate = swiftUIViewsPredicate;
    XCTAssertIdentical(config.swiftUIViewsPredicate, swiftUIViewsPredicate);

    XCTAssertNil(config.swiftUIActionsPredicate);
    KubesenseDefaultSwiftUIRUMActionsPredicate *swiftUIActionsPredicate = [[KubesenseDefaultSwiftUIRUMActionsPredicate alloc] initWithIsLegacyDetectionEnabled:YES];
    config.swiftUIActionsPredicate = swiftUIActionsPredicate;
    XCTAssertIdentical(config.swiftUIActionsPredicate, swiftUIActionsPredicate);
#endif

    KubesenseRUMURLSessionTracking *urlSessionTracking = [KubesenseRUMURLSessionTracking new];
    KubesenseRUMFirstPartyHostsTracing *tracing;
    tracing = [[KubesenseRUMFirstPartyHostsTracing alloc] initWithHosts:[NSSet new] sampleRate:20];
    tracing = [[KubesenseRUMFirstPartyHostsTracing alloc] initWithHosts:[NSSet new]];
    tracing = [[KubesenseRUMFirstPartyHostsTracing alloc] initWithHostsWithHeaderTypes:@{}];
    tracing = [[KubesenseRUMFirstPartyHostsTracing alloc] initWithHostsWithHeaderTypes:@{} sampleRate:20];
    [urlSessionTracking setFirstPartyHostsTracing:tracing];
    [urlSessionTracking setResourceAttributesProvider:^NSDictionary<NSString *,id> * _Nullable(NSURLRequest * _Nonnull request,
                                                                                                NSURLResponse * _Nullable response,
                                                                                                NSData * _Nullable data,
                                                                                                NSError * _Nullable error) {
        return @{};
    }];

    XCTAssertTrue(config.trackFrustrations);
    config.trackFrustrations = NO;
    XCTAssertFalse(config.trackFrustrations);

    XCTAssertFalse(config.trackBackgroundEvents);
    config.trackBackgroundEvents = YES;
    XCTAssertTrue(config.trackBackgroundEvents);

    XCTAssertEqual(config.longTaskThreshold, 0.1);
    config.longTaskThreshold = 1;
    XCTAssertEqual(config.longTaskThreshold, 1);

    XCTAssertEqual(config.appHangThreshold, 0);
    config.appHangThreshold = 1;
    XCTAssertEqual(config.appHangThreshold, 1);

    XCTAssertEqual(config.vitalsUpdateFrequency, KubesenseRUMVitalsFrequencyAverage);
    config.vitalsUpdateFrequency = KubesenseRUMVitalsFrequencyFrequent;
    XCTAssertEqual(config.vitalsUpdateFrequency, KubesenseRUMVitalsFrequencyFrequent);
    config.vitalsUpdateFrequency = KubesenseRUMVitalsFrequencyNever;
    XCTAssertEqual(config.vitalsUpdateFrequency, KubesenseRUMVitalsFrequencyNever);

    KubesenseRUMTimeseriesConfiguration *timeseriesConfiguration = [[KubesenseRUMTimeseriesConfiguration alloc]
        initWithCollectTypes:@[KubesenseRUMTimeseriesType.memory, KubesenseRUMTimeseriesType.cpu]];
    [config setTimeseriesConfiguration:timeseriesConfiguration];

    [config setViewEventMapper:^KubesenseRUMViewEvent * _Nonnull(KubesenseRUMViewEvent * _Nonnull viewEvent) {
        viewEvent.view.url = @"";
        return viewEvent;
    }];
    [config setResourceEventMapper:^KubesenseRUMResourceEvent * _Nullable(KubesenseRUMResourceEvent * _Nonnull resourceEvent) {
        resourceEvent.resource.url = @"";
        return resourceEvent;
    }];
    [config setActionEventMapper:^KubesenseRUMActionEvent * _Nullable(KubesenseRUMActionEvent * _Nonnull actionEvent) {
        return nil;
    }];
    [config setErrorEventMapper:^KubesenseRUMErrorEvent * _Nullable(KubesenseRUMErrorEvent * _Nonnull errorEvent) {
        return nil;
    }];
    [config setLongTaskEventMapper:^KubesenseRUMLongTaskEvent * _Nullable(KubesenseRUMLongTaskEvent * _Nonnull longTaskEvent) {
        return nil;
    }];

    XCTAssertNil(config.onSessionStart);
    config.onSessionStart = ^(NSString * _Nonnull uuid, BOOL discarded) {};
    XCTAssertNotNil(config.onSessionStart);

    XCTAssertTrue(config.trackAnonymousUser);
    config.trackAnonymousUser = NO;
    XCTAssertFalse(config.trackAnonymousUser);

#if !TARGET_OS_WATCH
    XCTAssertTrue(config.trackMemoryWarnings);
    config.trackMemoryWarnings = NO;
    XCTAssertFalse(config.trackMemoryWarnings);

    XCTAssertFalse(config.collectAccessibility);
    config.collectAccessibility = YES;
    XCTAssertTrue(config.collectAccessibility);
#endif
}

#pragma clang diagnostic pop

@end
