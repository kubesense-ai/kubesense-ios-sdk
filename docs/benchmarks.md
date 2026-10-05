# SDK overhead benchmarks

What the Kubesense iOS SDK costs an app, measured on the Kubesense Shop sample
(`Samples/KubesenseShop`). Run them with `make benchmark` at the repository root; the sample's README
describes the options.

## Method

The `KubesenseShopBenchmarks` scheme runs XCTest performance tests in Release, five iterations each, in
four SDK profiles chosen with `KUBESENSE_SDK_PROFILE`:

| Profile | SDK |
| --- | --- |
| `off` | Not started: the baseline |
| `rum` | Core and RUM, with URLSession tracking |
| `replay` | Core, RUM and Session Replay with SwiftUI recording |
| `full` | RUM, Logs, Trace, OpenTelemetry, Flags, Crash Reporting and Session Replay with SwiftUI recording |

- **Launch:** cold launch until the app is responsive (`XCTApplicationLaunchMetric`).
- **Scroll:** three fast flings down the product grid and three back up, per iteration. CPU time and
  instructions of the app process, its peak and final physical memory, and the scroll's dragging and
  deceleration time. On a physical device the same test also reports the hitch time ratio and frame
  rate.

The shop uses its offline catalog, so its own API calls do not add noise. Product photos still load
from the network, as in the real app. SDK uploads stay on and go to the configured collector, with
`env:benchmark`. Session Replay uses the sample's settings: every session recorded, images unmasked,
sensitive inputs masked.

Each value is the median of the five iterations; the percentage is the change against `off`.

## Results

iPhone 17 Pro simulator, iOS 26.5, Xcode 26.6, SDK 1.0.0, 5 October 2026:

| Metric | off | rum | replay | full |
| --- | ---: | ---: | ---: | ---: |
| Launch to responsive | 1,538.8 ms | 1,584.1 ms (+2.9%) | 1,604.4 ms (+4.3%) | 1,707.9 ms (+11.0%) |
| Scroll duration | 2,582.9 ms | 2,550.5 ms (-1.3%) | 2,566.6 ms (-0.6%) | 2,551.2 ms (-1.2%) |
| CPU time while scrolling | 2,371.6 ms | 2,447.7 ms (+3.2%) | 7,180.6 ms (+202.8%) | 7,245.8 ms (+205.5%) |
| CPU instructions while scrolling | 7,216.8 M | 7,520.3 M (+4.2%) | 56,953.7 M (+689.2%) | 57,406.2 M (+695.4%) |
| Peak memory | 144.0 MB | 145.9 MB (+1.3%) | 154.5 MB (+7.3%) | 154.4 MB (+7.2%) |
| Memory after scrolling | 142.9 MB | 145.0 MB (+1.4%) | 149.3 MB (+4.4%) | 149.2 MB (+4.3%) |

- **RUM is cheap:** about 3% at launch, 3% CPU while scrolling, and 1% memory.
- **Session Replay is almost all of the cost.** `replay` and `full` are within noise of each other while
  scrolling: about three times the CPU time, eight times the instructions, and 10 MB more memory. Fast
  flings are its worst case, since the screen changes on every frame and each change is recorded.
- **Logs, Trace, Flags and Crash Reporting** add nothing measurable while scrolling, and about 6% to
  launch on top of `replay`.
- **Scrolling took the same time in every profile.** The simulator cannot say whether the extra CPU drops
  frames; a device run's hitch ratio can.

## Caveats

The simulator shares the Mac's CPU and runs the app on it, so read these numbers as relative, and
compare runs made on the same machine. Publishable numbers come from a device:

```bash
make benchmark DESTINATION='platform=iOS,name=<device>'
```

The levers for Session Replay's cost are its `replaySampleRate`, which records only a share of the
sessions RUM samples, and starting it only where it is needed (`startRecordingImmediately: false` with
`SessionReplay.startRecording()`).
