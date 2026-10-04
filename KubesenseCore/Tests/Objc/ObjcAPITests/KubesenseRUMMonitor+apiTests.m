/*
* Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
* This product includes software developed at Datadog (https://www.datadoghq.com/).
* Copyright 2019-Present Datadog, Inc.
*/

#import <XCTest/XCTest.h>
@import KubesenseRUM;

@interface KubesenseRUMMonitor_apiTests : XCTestCase
@end

/*
 * Objc APIs smoke tests - only check if the interface is available to Objc.
 */
@implementation KubesenseRUMMonitor_apiTests

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wunused-value"

#if !TARGET_OS_WATCH
- (void)testDDRUMViewAPI {
    KubesenseRUMView *view = [[KubesenseRUMView alloc] initWithName:@"abc" attributes:@{@"foo": @"bar"}];
    XCTAssertEqual(view.name, @"abc");
    XCTAssertNotNil(view.attributes[@"foo"]); // TODO: RUMM-1583 assert with `XCTAssertEqual`
}

- (void)testDDRUMActionAPI {
    KubesenseRUMAction *action = [[KubesenseRUMAction alloc] initWithName:@"abc" attributes:@{@"foo": @"bar"}];
    XCTAssertEqual(action.name, @"abc");
    XCTAssertNotNil(action.attributes[@"foo"]); // TODO: RUMM-1583 assert with `XCTAssertEqual`
}
#endif

- (void)testDDRUMErrorSourceAPI {
    KubesenseRUMErrorSourceSource; KubesenseRUMErrorSourceNetwork; KubesenseRUMErrorSourceWebview; KubesenseRUMErrorSourceConsole; KubesenseRUMErrorSourceCustom;
}

- (void)testDDRUMActionTypeAPI {
    KubesenseRUMActionTypeTap; KubesenseRUMActionTypeScroll; KubesenseRUMActionTypeSwipe; KubesenseRUMActionTypeCustom;
}

- (void)testDDRUMResourceTypeAPI {
    KubesenseRUMResourceTypeImage; KubesenseRUMResourceTypeXhr; KubesenseRUMResourceTypeBeacon; KubesenseRUMResourceTypeCss; KubesenseRUMResourceTypeDocument;
    KubesenseRUMResourceTypeFetch; KubesenseRUMResourceTypeFont; KubesenseRUMResourceTypeJs; KubesenseRUMResourceTypeMedia; KubesenseRUMResourceTypeOther;
    KubesenseRUMResourceTypeNative;
}

- (void)testDDRUMMethodAPI {
    KubesenseRUMMethodPost; KubesenseRUMMethodGet; KubesenseRUMMethodHead; KubesenseRUMMethodPut; KubesenseRUMMethodDelete; KubesenseRUMMethodPatch; KubesenseRUMMethodConnect;
    KubesenseRUMMethodTrace; KubesenseRUMMethodOptions;
}

- (void)testDDRUMFeatureOperationFailureReasonAPI {
    KubesenseRUMFeatureOperationFailureReasonError; KubesenseRUMFeatureOperationFailureReasonAbandoned; KubesenseRUMFeatureOperationFailureReasonOther;
}

- (void)testDDRUMMonitorAPI {
    KubesenseRUMMonitor *monitor = [KubesenseRUMMonitor shared];
    [monitor currentSessionIDWithCompletion:^(NSString * _Nullable sessionID) {}];
    [monitor stopSession];
    [monitor reportAppFullyDisplayed];

    [monitor addViewAttributeForKey:@"key" value: @"value"];
    [monitor addViewAttributes:@{@"string": @"value", @"integer": @1, @"boolean": @true}];
    [monitor removeViewAttributeForKey:@"key"];
    [monitor removeViewAttributesForKeys:@[@"string",@"integer",@"boolean"]];
    [monitor startViewWithKey:@"view" name:@"" attributes:@{}];
    [monitor stopViewWithKey:@"view" attributes:@{}];
    [monitor startViewWithKey:@"" name:nil attributes:@{}];
    [monitor stopViewWithKey:@"" attributes:@{}];
    [monitor addViewLoadingTimeWithOverwrite:YES];

    [monitor addErrorWithMessage:@"" stack:nil source:KubesenseRUMErrorSourceCustom attributes:@{}];
    [monitor addErrorWithError:[NSError errorWithDomain:NSCocoaErrorDomain code:-100 userInfo:nil]
                        source:KubesenseRUMErrorSourceNetwork attributes:@{}];

    [monitor startResourceWithResourceKey:@"" request:[NSURLRequest new] attributes:@{}];
    [monitor startResourceWithResourceKey:@"" url:[NSURL new] attributes:@{}];
    [monitor startResourceWithResourceKey:@"" httpMethod:KubesenseRUMMethodGet urlString:@"" attributes:@{}];
    [monitor addResourceMetricsWithResourceKey:@"" metrics:[NSURLSessionTaskMetrics new] attributes:@{}];
    [monitor stopResourceWithResourceKey:@"" response:[NSURLResponse new] size:nil attributes:@{}];
    [monitor stopResourceWithResourceKey:@"" statusCode:nil kind:KubesenseRUMResourceTypeOther size:nil attributes:@{}];
    [monitor stopResourceWithErrorWithResourceKey:@""
                                                   error:[NSError errorWithDomain:NSURLErrorDomain code:-99 userInfo:nil] response:nil attributes:@{}];
    [monitor stopResourceWithErrorWithResourceKey:@"" message:@"" response:nil attributes:@{}];
    [monitor startActionWithType:KubesenseRUMActionTypeSwipe name:@"" attributes:@{}];
    [monitor stopActionWithType:KubesenseRUMActionTypeSwipe name:nil attributes:@{}];
    [monitor addActionWithType:KubesenseRUMActionTypeTap name:@"" attributes:@{}];
    [monitor addAttributeForKey:@"key" value:@"value"];
    [monitor removeAttributeForKey:@"key"];
    [monitor addAttributes:@{@"string": @"value", @"integer": @1, @"boolean": @true}];
    [monitor removeAttributesForKeys:@[@"string",@"integer",@"boolean"]];
    [monitor addFeatureFlagEvaluationWithName: @"name" value: @"value"];
    KubesenseProfilingOptions * options = [[KubesenseProfilingOptions alloc] initWithSampleRate: 100.0];
    [monitor startOperationWithName:@"test_flow" operationKey:@"operation_1" attributes:@{} options: options];
    [monitor succeedOperationWithName:@"test_flow" operationKey:@"operation_1" attributes:@{}];
    [monitor failOperationWithName:@"test_flow" operationKey:@"operation_1" reason:KubesenseRUMFeatureOperationFailureReasonError attributes:@{}];

    [monitor _internal_sync_addError:[NSError errorWithDomain:NSCocoaErrorDomain code:-100 userInfo:nil]
                              source:KubesenseRUMErrorSourceCustom attributes:@{}];

    [monitor setDebug:YES];
    [monitor setDebug:NO];
}

#pragma clang diagnostic pop

@end
