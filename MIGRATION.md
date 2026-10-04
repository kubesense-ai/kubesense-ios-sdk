# Migration Guide

This document outlines breaking changes and migration steps between major versions of the project.

## Migration from 2.x to 3.0

This section describes the main changes introduced in SDK `3.0` compared to `2.x`.

### Product Modules 

All SDK products (RUM, Trace, Logs, SessionReplay, and so on) remain modular and separated into distinct libraries. The main change is that the `KubesenseObjc` module has been removed, with its contents integrated into the corresponding product modules.

The available `Kubesense` libraries in 3.0 are:
- `KubesenseCore`
- `KubesenseCrashReporting`
- `KubesenseLogs`
- `KubesenseRUM`
- `KubesenseSessionReplay`
- `KubesenseTrace`
- `KubesenseWebViewTracking`

<details>
  <summary>SPM</summary>

  ```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/kubesense-ai/kubesense-ios-sdk", from: "3.0.0")
    ],
    targets: [
        .target(
            ...
            dependencies: [
                .product(name: "KubesenseCore", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseCrashReporting", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseLogs", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseRUM", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseSessionReplay", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseTrace", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseWebViewTracking", package: "kubesense-ios-sdk"),
            ]
        ),
    ]
)
  ```
</details>

<details>
  <summary>CocoaPods</summary>

  ```ruby
  pod 'KubesenseCore'
  pod 'KubesenseCrashReporting'
  pod 'KubesenseLogs'
  pod 'KubesenseRUM'
  pod 'KubesenseSessionReplay'
  pod 'KubesenseTrace'
  pod 'KubesenseWebViewTracking'
  ```
</details>

<details>
  <summary>Carthage</summary>

  The `Cartfile` remains the same: 
  ```
  github "kubesense-ai/kubesense-ios-sdk"
  ```

  In Xcode, you **must** link the following frameworks:
  ```
  KubesenseCore.xcframework
  KubesenseInternal.xcframework
  ```

  Then select the product modules you intend to use:
  ```
  KubesenseCrashReporting.xcframework + CrashReporter.xcframework
  KubesenseLogs.xcframework
  KubesenseRUM.xcframework
  KubesenseSessionReplay.xcframework
  KubesenseTrace.xcframework
  KubesenseWebViewTracking.xcframework
  ```
</details>

### SDK Configuration

The SDK should be initialized as early as possible in the app lifecycle, specifically in the `AppDelegate`'s `application(_:didFinishLaunchingWithOptions:)` callback. This ensures accurate measurement of all metrics, including application startup duration. For apps built with SwiftUI, use `@UIApplicationDelegateAdaptor` to access the `AppDelegate`.

```swift
import KubesenseCore

Kubesense.initialize(
    with: Kubesense.Configuration(
        clientToken: "<client token>",
        env: "<environment>",
        service: "<service name>"
    ), 
    trackingConsent: .granted
)
```

**Note**: Initializing the SDK elsewhere (for example later during view loading) may result in inaccurate or missing telemetry, especially around app startup performance.

### RUM Product Changes

RUM View-level attributes are now automatically propagated to all related child events, including resources, user actions, errors, and long tasks. This ensures consistent metadata across events, making it easier to filter and correlate data on Kubesense dashboards.

To manage View level attributes more effectively, new APIs were added:
- `Monitor.addViewAttribute(forKey:value:)`
- `Monitor.addViewAttributes(_:)`
- `Monitor.removeViewAttribute(forKey:)`
- `Monitor.removeViewAttributes(forKeys:)`

Other notable changes:
- All Objective-C RUM APIs are now included in `KubesenseRUM`. The separate `KubesenseObjc` module is no longer available.
- App Hangs and Watchdog terminations are no longer reported from app extensions or widgets.
- A new property `trackMemoryWarnings` was added to `RUM.Configuration` to report memory warnings as RUM Errors.

API changes:

|`2.x`|`3.0`|
|---|---|
|-|`RUM.Configuration.trackMemoryWarnings`|
|`RUMView(path:attributes:)`|`RUMView(name:attributes:isUntrackedModal:)`|
|-|`Monitor.addViewAttribute(forKey:value:)`|
|-|`Monitor.addViewAttributes(:)`|
|-|`Monitor.removeViewAttribute(forKey:)`|
|-|`Monitor.removeViewAttributes(forKeys:)`|

### Logs Product Changes

The Logs product no longer reports fatal errors. To enable Error Tracking for crashes, Crash Reporting must be enabled in conjunction with RUM.

Additionally, all Objective-C Logs APIs are now included in `KubesenseLogs`. The separate `KubesenseObjc` module is no longer available.

### APM Trace Product Changes

Trace sampling is now deterministic when used alongside RUM. It uses the RUM `session.id` to ensure consistent sampling.

Also:
- The `Trace.Configuration.URLSessionTracking.FirstPartyHostsTracing` configuration sets sampling for all requests by default and the trace context is injected only into sampled requests.
- All Objective-C Trace APIs are now included in `KubesenseTrace`. The separate `KubesenseObjc` module is no longer available.

**Note**: A similar configuration exists in `RUM.Configuration.URLSessionTracking.FirstPartyHostsTracing`.

### Session Replay Product Changes

Privacy settings are now more granular. The previous `defaultPrivacyLevel` parameter has been replaced with:
- `textAndInputPrivacyLevel`
- `imagePrivacyLevel`
- `touchPrivacyLevel`

Learn more about [privacy levels][1].

API changes:

|`2.x`|`3.0`|
|---|---|
|`SessionReplay.Configuration(replaySampleRate:defaultPrivacyLevel:startRecordingImmediately:customEndpoint:)`|`SessionReplay.Configuration(replaySampleRate:textAndInputPrivacyLevel:imagePrivacyLevel:touchPrivacyLevel:startRecordingImmediately:customEndpoint:featureFlags:)`|
|`SessionReplay.Configuration(replaySampleRate:defaultPrivacyLevel:startRecordingImmediately:customEndpoint:)`|`SessionReplay.Configuration(replaySampleRate:textAndInputPrivacyLevel:imagePrivacyLevel:touchPrivacyLevel:startRecordingImmediately:customEndpoint:featureFlags:)`|

### URLSession Instrumentation Changes

Legacy delegate types have been replaced by a unified instrumentation API:

|`2.x`|`3.0`|
|---|---|
|`KubesenseURLSessionDelegate()`|`URLSessionInstrumentation.enable(with:)`|
|`KubesenseURLSessionDelegate()`|`URLSessionInstrumentation.enable(with:)`|
|`KubesenseNSURLSessionDelegate()`|`URLSessionInstrumentation.enable(with:)`|

## Migration from 1.x to 2.0

This section describes the main changes introduced in SDK `2.0` compared to `1.x`.

### Product Modules 

All relevant products (RUM, Trace, Logs, etc.) are now extracted into different modules. That allows you to integrate only what is needed into your application.

Whereas all products in version 1.x were contained in the single module, `Kubesense`, you now need to adopt the following libraries:

- `KubesenseCore`
- `KubesenseLogs`
- `KubesenseTrace`
- `KubesenseRUM`
- `KubesenseWebViewTracking`

These come in addition to the existing `KubesenseCrashReporting` and `KubesenseObjc`.

<details>
  <summary>SPM</summary>

  ```swift
let package = Package(
    ...
    dependencies: [
        .package(url: "https://github.com/kubesense-ai/kubesense-ios-sdk", from: "2.0.0")
    ],
    targets: [
        .target(
            ...
            dependencies: [
                .product(name: "KubesenseCore", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseLogs", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseTrace", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseRUM", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseCrashReporting", package: "kubesense-ios-sdk"),
                .product(name: "KubesenseWebViewTracking", package: "kubesense-ios-sdk"),
            ]
        ),
    ]
)
  ```
</details>

<details>
  <summary>CocoaPods</summary>

  ```ruby
  pod 'KubesenseCore'
  pod 'KubesenseLogs'
  pod 'KubesenseTrace'
  pod 'KubesenseRUM'
  pod 'KubesenseCrashReporting'
  pod 'KubesenseWebViewTracking'
  pod 'KubesenseObjc'
  ```
</details>

<details>
  <summary>Carthage</summary>

  The `Cartfile` stays the same: 
  ```
  github "kubesense-ai/kubesense-ios-sdk"
  ```

  In Xcode, you **must** link the following frameworks:
  ```
  KubesenseInternal.xcframework
  KubesenseCore.xcframework
  ```

  Then you can select the modules you want to use:
  ```
  KubesenseLogs.xcframework
  KubesenseTrace.xcframework
  KubesenseRUM.xcframework
  KubesenseCrashReporting.xcframework + CrashReporter.xcframework
  KubesenseWebViewTracking.xcframework
  KubesenseObjc.xcframework
  ```
</details>

**Note**: In case of Crash Reporting and WebView Tracking usage it's also needed to add RUM and/or Logs modules to be able to report events to RUM and/or Logs respectively.

The `2.0` version of the iOS SDK also exposes unified API layouts and naming between iOS and Android SDKs and with other Kubesense products.

### SDK Configuration Changes

Better SDK granularity is achieved with the extraction of different products into independent modules, therefore all product-specific configurations have been moved to their dedicated modules.

> The SDK must be initialized before enabling any product.

The Builder pattern of the SDK initialization has been removed in favor of structure definitions. The following example shows how a `1.x` initialization would translate in `2.0`.

**V1 Initialization**
```swift
import Kubesense

Kubesense.initialize(
    appContext: .init(),
    trackingConsent: .granted,
    configuration: Kubesense.Configuration
        .builderUsing(
            clientToken: "<client token>",
            environment: "<environment>"
        )
        .set(serviceName: "<service name>")
        .build()
```
**V2 Initialization**
```swift
import KubesenseCore

Kubesense.initialize(
    with: Kubesense.Configuration(
        clientToken: "<client token>",
        env: "<environment>",
        service: "<service name>"
    ), 
    trackingConsent: .granted
)
```

API changes:

|`1.x`|`2.0`|
|---|---|
|`Kubesense.Configuration.Builder.set(serviceName:)`|`Kubesense.Configuration.service`|
|`Kubesense.Configuration.Builder.set(batchSize:)`|`Kubesense.Configuration.batchSize`|
|`Kubesense.Configuration.Builder.set(uploadFrequency:)`|`Kubesense.Configuration.uploadFrequency`|
|`Kubesense.Configuration.Builder.set(proxyConfiguration:)`|`Kubesense.Configuration.proxyConfiguration`|
|`Kubesense.Configuration.Builder.set(encryption:)`|`Kubesense.Configuration.encryption`|
|`Kubesense.Configuration.Builder.set(serverDateProvider:)`|`Kubesense.Configuration.serverDateProvider`|
|`Kubesense.AppContext(mainBundle:)`|`Kubesense.Configuration.bundle`|

### Logs Product Changes

All the classes related to Logs are now strictly in the `KubesenseLogs` module. You first need to enable the product:

```swift
import KubesenseLogs

Logs.enable(with: Logs.Configuration(...))
```

Then, you can create a logger instance:

```swift
import KubesenseLogs

let logger = Logger.create(
    with: Logger.Configuration(name: "<logger name>")
)
```

API changes:

|`1.x`|`2.0`|
|---|---|
|`Kubesense.Configuration.Builder.setLogEventMapper(_:)`|`Logs.Configuration.eventMapper`|
|`Kubesense.Configuration.Builder.set(loggingSamplingRate:)`|`Logs.Configuration.eventMapper`|
|`Logger.Builder.set(serviceName:)`|`Logger.Configuration.service`|
|`Logger.Builder.set(loggerName:)`|`Logger.Configuration.name`|
|`Logger.Builder.sendNetworkInfo(_:)`|`Logger.Configuration.networkInfoEnabled`|
|`Logger.Builder.bundleWithRUM(_:)`|`Logger.Configuration.bundleWithRumEnabled`|
|`Logger.Builder.bundleWithTrace(_:)`|`Logger.Configuration.bundleWithTraceEnabled`|
|`Logger.Builder.sendLogsToKubesense(false)`|`Logger.Configuration.remoteSampleRate = 0`|
|`Logger.Builder.set(kubesenseReportingThreshold:)`|`Logger.Configuration.remoteLogThreshold`|
|`Logger.Builder.printLogsToConsole(_:, usingFormat)`|`Logger.Configuration.consoleLogFormat`|

### APM Trace Product Changes

All the classes related to Trace are now strictly in the `KubesenseTrace` module. You first need to enable the product:

```swift
import KubesenseTrace

Trace.enable(
    with: Trace.Configuration(...)
)
```

Then, you can access the shared Tracer instance:

```swift
import KubesenseTrace

let tracer = Tracer.shared()
```

API changes:

|`1.x`|`2.0`|
|---|---|
|`Kubesense.Configuration.Builder.trackURLSession(_:)`|`Trace.Configuration.urlSessionTracking`|
|`Kubesense.Configuration.Builder.setSpanEventMapper(_:)`|`Trace.Configuration.eventMapper`|
|`Kubesense.Configuration.Builder.set(tracingSamplingRate:)`|`Trace.Configuration.sampleRate`|
|`Tracer.Configuration.serviceName`|`Trace.Configuration.service`|
|`Tracer.Configuration.sendNetworkInfo`|`Trace.Configuration.networkInfoEnabled`|
|`Tracer.Configuration.globalTags`|`Trace.Configuration.tags`|
|`Tracer.Configuration.bundleWithRUM`|`Trace.Configuration.bundleWithRumEnabled`|
|`Tracer.Configuration.samplingRate`|`Trace.Configuration.sampleRate`|

### RUM Product Changes

All the classes related to RUM are now strictly in the `KubesenseRUM` module. You will first need to enable the product:

```swift
import KubesenseRUM

RUM.enable(
    with: RUM.Configuration(applicationID: "<RUM Application ID>")
)
```

Then, you can access the shared RUM monitor instance:

```swift
import KubesenseRUM

let monitor = RUMMonitor.shared()
```

API changes:

|`1.x`|`2.0`|
|---|---|
|`Kubesense.Configuration.Builder.trackURLSession(_:)`|`RUM.Configuration.urlSessionTracking`|
|`Kubesense.Configuration.Builder.set(rumSessionsSamplingRate:)`|`RUM.Configuration.sessionSampleRate`|
|`Kubesense.Configuration.Builder.onRUMSessionStart`|`RUM.Configuration.onSessionStart`|
|`Kubesense.Configuration.Builder.trackUIKitRUMViews(using:)`|`RUM.Configuration.uiKitViewsPredicate`|
|`Kubesense.Configuration.Builder.trackUIKitRUMActions(using:)`|`RUM.Configuration.uiKitActionsPredicate`|
|`Kubesense.Configuration.Builder.trackRUMLongTasks(threshold:)`|`RUM.Configuration.longTaskThreshold`|
|`Kubesense.Configuration.Builder.setRUMViewEventMapper(_:)`|`RUM.Configuration.viewEventMapper`|
|`Kubesense.Configuration.Builder.setRUMResourceEventMapper(_:)`|`RUM.Configuration.resourceEventMapper`|
|`Kubesense.Configuration.Builder.setRUMActionEventMapper(_:)`|`RUM.Configuration.actionEventMapper`|
|`Kubesense.Configuration.Builder.setRUMErrorEventMapper(_:)`|`RUM.Configuration.errorEventMapper`|
|`Kubesense.Configuration.Builder.setRUMLongTaskEventMapper(_:)`|`RUM.Configuration.longTaskEventMapper`|
|`Kubesense.Configuration.Builder.setRUMResourceAttributesProvider(_:)`|`RUM.Configuration.urlSessionTracking.resourceAttributesProvider`|
|`Kubesense.Configuration.Builder.trackBackgroundEvents(_:)`|`RUM.Configuration.trackBackgroundEvents`|
|`Kubesense.Configuration.Builder.trackFrustrations(_:)`|`RUM.Configuration.frustrationsTracking`|
|`Kubesense.Configuration.Builder.set(mobileVitalsFrequency:)`|`RUM.Configuration.vitalsUpdateFrequency`|
|`Kubesense.Configuration.Builder.set(sampleTelemetry:)`|`RUM.Configuration.telemetrySampleRate`|

### Crash Reporting Changes

To enable Crash Reporting, make sure to also enable RUM and/or Logs.

```swift
import KubesenseCrashReporting

CrashReporting.enable()
```

|`1.x`|`2.0`|
|---|---|
|`Kubesense.Configuration.Builder.enableCrashReporting()`|`CrashReporting.enable()`|

### WebView Tracking Changes

To enable WebViewTracking, make sure to also enable RUM and/or Logs.

```swift
import WebKit
import KubesenseWebViewTracking

let webView = WKWebView(...)
WebViewTracking.enable(webView: webView)
```

|`1.x`|`2.0`|
|---|---|
|`WKUserContentController.startTrackingKubesenseEvents`|`WebViewTracking.enable(webView:)`|

### Using a Secondary Instance of the SDK

Previously Kubesense SDK implemented a singleton and only one SDK instance could exist in the application process. This created obstacles for use-cases like the usage of the SDK by 3rd party libraries.

With version 2.0 we addressed this limitation:

* Now it is possible to initialize multiple instances of the SDK, associating them with a name.
* Many methods of the SDK can optionally take a SDK instance as an argument. If not provided, the call will be associated with the default (nameless) SDK instance.

Here is an example illustrating how to initialize a secondary core instance and enable products:

```swift
import KubesenseCore
import KubesenseRUM
import KubesenseLogs
import KubesenseTrace

let core = Kubesense.initialize(
    with: configuration, 
    trackingConsent: trackingConsent, 
    instanceName: "my-instance"
)

RUM.enable(
    with: RUM.Configuration(applicationID: "<RUM Application ID>"),
    in: core
)

Logs.enable(in: core)

Trace.enable(in: core)
```

**Note**: The SDK instance name should have the same value between application runs. Storage paths for SDK events are associated with it.

Once initialized, you can retrieve the named SDK instance by calling `Kubesense.sdkInstance(named: "<name>")` and use it for accessing the products.

```swift
import KubesenseCore

let core = Kubesense.sdkInstance(named: "my-instance")
```

#### Logs
```swift
import KubesenseLogs

let logger = Logger.create(in: core)
```

#### Trace
```swift
import KubesenseRUM

let monitor = RUMMonitor.shared(in: core)
```

#### RUM
```swift
import KubesenseRUM

let monitor = RUMMonitor.shared(in: core)
```

[1]: /real_user_monitoring/session_replay/mobile/privacy_options?platform=ios