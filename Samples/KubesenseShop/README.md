# Kubesense Shop for iOS

A small shopping app for testing the Kubesense iOS SDK end to end: SwiftUI tabs for Shop, Search, Cart
and Account, a checkout that places real orders against the sample API, a debug-only Diagnostics tab
that sends one signal at a time, and a UIKit screen with an embedded web page. It is the iOS
counterpart of the Android sample in `kubesense-android-sdk/sample/kubesense-app` and talks to the same
backend.

The app links the SDK from this repository through Swift Package Manager (`path: ../..`), so it always
runs the code next to it.

## Configure

Copy the example configuration and fill in your RUM application:

```bash
cd Samples/KubesenseShop
cp Config/example.json Config/local.json
```

```json
{
  "KUBESENSE_CLIENT_TOKEN": "<client token>",
  "KUBESENSE_APPLICATION_ID": "<RUM application ID>",
  "KUBESENSE_RUM_ENDPOINT": "your-collector.example.com:34443",
  "KUBESENSE_ENV": "dev",
  "SAMPLE_API_BASE_URL": "https://your-sample-api.example.com",
  "FLAVOR": "local"
}
```

`Config/local.json` is git-ignored. A build script bundles it as `config.json`, and falls back to
`Config/example.json` when it is missing. With an empty token or application ID the app runs in preview
mode: everything works, nothing is uploaded.

`KUBESENSE_RUM_ENDPOINT` is a host with an optional port. RUM, Logs, Traces and Session Replay all upload
to `https://<endpoint>/rum/api/v1/...`.

`SAMPLE_API_BASE_URL` points at the shop backend from the Android repository
(`sample/kubesense-app/backend/server.py`, or the `tykevision/kubesense-shop` image). Leave it empty to
use the built-in offline catalog of 104 products. For a backend on your Mac, use `http://127.0.0.1:8080`;
local networking is allowed in `Info.plist`. The seeded QA login is `admin@kubesense.ai` / `Kube@1234$`.

## Build and run

The Xcode project is generated from `project.yml` with [XcodeGen](https://github.com/yonaskolb/XcodeGen)
and is not checked in.

```bash
brew install xcodegen
cd Samples/KubesenseShop
xcodegen generate
open KubesenseShop.xcodeproj
```

Run the `KubesenseShop` scheme on an iOS 16+ simulator or device. From the command line:

```bash
xcodebuild -project KubesenseShop.xcodeproj -scheme KubesenseShop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' build
```

Build with Xcode 26. Xcode 27 rejects the iOS 12 deployment target that the KSCrash and
OpenTelemetry packages still declare.

## Tests

```bash
# Repository and catalog logic, no network.
xcodebuild -project KubesenseShop.xcodeproj -scheme KubesenseShop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KubesenseShopTests test

# One full shopping journey: add to cart, sign in, place an order, run diagnostics,
# open the UIKit and WebView screen. Needs the sample API and creates a real order.
xcodebuild -project KubesenseShop.xcodeproj -scheme KubesenseShop \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:KubesenseShopUITests test
```

The UI tests install a separate `KubesenseShopUITests-Runner` app on the simulator; that is Xcode's test
driver, not a second copy of the shop.

## Feature map

| Area | Coverage |
| --- | --- |
| Shop, search, product, cart | SwiftUI views named after the Android routes (`shop`, `product/{id}`, ...), tap actions, `checkout.confirmed` timing, URLSession resources with duration breakdown and tracing headers |
| Account | User info on sign-in and sign-out, current session ID, masked password field |
| Diagnostics: RUM | Manual actions, view attributes, timing, handled errors, feature operations |
| Diagnostics: Network | Manual resource, instrumented URLSession request |
| Diagnostics: Logs and traces | Logger, Kubesense and OpenTelemetry spans, Swift concurrency and Combine error reporting |
| Diagnostics: Replay and context | Start and stop Session Replay, user and account info, feature flag evaluation |
| Diagnostics: Reliability | Long task, plus confirmed Swift crash, SIGSEGV and a 20 second app hang |
| UIKit and WebView | Auto-tracked UIKit view, secure text field, slider action, `WebViewTracking` bridge |
| SDK bootstrap | Core, RUM, Logs, Trace, OpenTelemetry, Flags, Crash Reporting, Session Replay with SwiftUI recording |

The Diagnostics tab is compiled into Debug builds only. Destructive scenarios ask for confirmation;
reopen the app afterwards so the crash report is sent.
