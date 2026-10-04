# Kubesense SDK for iOS and tvOS

> Swift and Objective-C libraries to send RUM, logs, traces, Session Replay, crash reports and profiles
> from iOS and tvOS applications to [Kubesense](https://www.kubesense.ai).

This SDK is a fork of [Datadog's dd-sdk-ios](https://github.com/DataDog/dd-sdk-ios) (Apache-2.0), rebranded
and pointed at the Kubesense collector. It behaves like the Kubesense Android and browser SDKs on the wire.
The upstream version it is based on is recorded in [`tools/kubesense-sync/upstream.json`](tools/kubesense-sync/upstream.json);
how the fork is kept in sync with upstream is described in [`docs/UPSTREAM_SYNC.md`](docs/UPSTREAM_SYNC.md).

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

[Apache License, v2.0](LICENSE). This product includes software developed at Datadog
(https://www.datadoghq.com/); see [NOTICE](NOTICE) and [LICENSE-3rdparty.csv](LICENSE-3rdparty.csv).
