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
make test       # repository and catalog logic, no network
make ui-test    # one full shopping journey: add to cart, sign in, place an order, run diagnostics,
                # open the UIKit and WebView screen; needs the sample API and creates a real order
```

Both take `DESTINATION=...` (default: the iPhone 17 Pro simulator). The UI tests install a separate
`KubesenseShopUITests-Runner` app on the simulator; that is Xcode's test driver, not a second copy of
the shop.

## Benchmarks

`make benchmark` (here or at the repository root) measures what the SDK costs this app. It runs the
`KubesenseShopBenchmarks` scheme in Release, five iterations of each measurement, in four SDK
profiles:

| Profile | SDK |
| --- | --- |
| `off` | Not started: the baseline |
| `rum` | Core and RUM, with URLSession tracking |
| `replay` | Core, RUM and Session Replay with SwiftUI recording |
| `full` | Everything the sample enables: RUM, Logs, Trace, OpenTelemetry, Flags, Crash Reporting, Session Replay with SwiftUI recording |

and prints a table of medians with the change against `off`:

- **Launch:** cold launch until the app is responsive.
- **Scroll:** three flings down the catalog and back; CPU time and instructions, peak and final memory,
  scroll duration, and on a physical device the hitch time ratio and frame rate.

The app runs on its offline catalog so the shop's own API does not add noise, with
`KUBESENSE_ENV=benchmark` so these sessions can be filtered out on the dashboard. SDK uploads stay on,
since they are part of the cost. Results, with the result bundle and build log, go to
`build/benchmarks/<timestamp>/`.

The simulator shares the Mac's CPU, so treat its numbers as relative and compare runs on the same
machine. For numbers to publish, run on a device: `make benchmark DESTINATION='platform=iOS,name=<device>'`
(the app must be signed for it). The latest results are in
[docs/benchmarks.md](../../docs/benchmarks.md).

The profile can also be chosen by hand, for profiling in Instruments: set `KUBESENSE_SDK_PROFILE` to
`off`, `rum`, `replay` or `full` in the scheme's environment. Any key of `Config/local.json` can be overridden the
same way.

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
| SDK bootstrap | Core, RUM, Logs, Trace, OpenTelemetry, Flags, Crash Reporting, Session Replay with SwiftUI recording; `KUBESENSE_SDK_PROFILE` selects `off`, `rum`, `replay` or `full` |
| Benchmarks | Launch and scrolling overhead per SDK profile (`make benchmark`) |

The Diagnostics tab is compiled into Debug builds only. Destructive scenarios ask for confirmation;
reopen the app afterwards so the crash report is sent.
