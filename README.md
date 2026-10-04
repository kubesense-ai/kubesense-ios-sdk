# Kubesense SDK for iOS and tvOS

> Swift and Objective-C libraries to send RUM, logs, traces, Session Replay, crash reports and profiles
> from iOS applications to [Kubesense](https://www.kubesense.ai).


## Modules

| Module | Purpose |
| --- | --- |
| `KubesenseCore` | SDK initialization, storage, upload, remote configuration (required) |
| `KubesenseRUM` | Real User Monitoring |
| `KubesenseLogs` | Log collection |
| `KubesenseTrace` | Distributed tracing (OpenTracing / OpenTelemetry) |
| `KubesenseSessionReplay` | Session Replay |
| `KubesenseCrashReporting` | Crash reporting (KSCrash) |
| `KubesenseWebViewTracking` | Tracks web views instrumented with the Kubesense browser SDK |
| `KubesenseFlags` | Feature flags |
| `KubesenseProfiling` | Application launch and continuous profiling |

## Installation

Swift Package Manager:

```swift
.package(url: "https://github.com/kubesense-ai/kubesense-ios-sdk.git", from: "1.0.0")
```

CocoaPods: `pod 'KubesenseCore'`, `pod 'KubesenseRUM'`, …

## Getting started

```swift
import KubesenseCore
import KubesenseRUM

Kubesense.initialize(
    with: Kubesense.Configuration(
        clientToken: "<client token>",
        env: "<environment>",
        site: .prod                         // us2.kubesense.ai (default); `.staging` is dev.kubesense.ai
        // kubesenseRumEndpoint: "collector.example.com"   // your own collector host, optional
    ),
    trackingConsent: .granted
)

RUM.enable(with: RUM.Configuration(applicationID: "<rum application id>"))
```

Objective-C uses the same API with the `Kubesense` prefix: `[KubesenseSDK initializeWithConfiguration:…]`,
`KubesenseConfiguration`, `KubesenseRUMConfiguration`, …

Every feature uploads to one collector host, under `https://<host>/rum/api/v1/...`. The dashboard-managed
remote configuration (`GET /rum/api/v1/sdk-config`) is enabled by default: the document cached by the
previous launch is applied at initialization and a fresh one is fetched for the next launch. Turn it off
with `remoteConfigurationEnabled: false`.

## License

Copyright 2026 KubeSense Technologies. Licensed under the [Apache License, Version 2.0](LICENSE).
Attribution notices for the code this SDK builds on are in [NOTICE](NOTICE), and third-party licenses
in [LICENSE-3rdparty.csv](LICENSE-3rdparty.csv).
