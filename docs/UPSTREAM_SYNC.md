# Rebasing onto a new upstream version

This SDK is a rebranded fork of [DataDog/dd-sdk-ios](https://github.com/DataDog/dd-sdk-ios). The upstream
release it was cut from, and the module version map, are in
[`tools/kubesense-sync/upstream.json`](../tools/kubesense-sync/upstream.json).

The fork is three things at once:

- a **rename**: every `Datadog`/`datadog`/`DD`/`dd` identifier, module, product, pod, path and string,
  done by a script;
- a **backend swap**: the Kubesense site and collector model, upload paths, wire names and remote
  configuration of the Kubesense Android SDK, in place of Datadog's regions and intake;
- the **attribution Apache-2.0 requires**, kept intact.

## Git layout

There is no shared history with upstream: the fork started from a release tarball.

| Ref | Content |
| --- | --- |
| `upstream/<version>` (tag) | The pristine upstream tree, committed as `import dd-sdk-ios <version>` |
| `kubesense/main` | The fork: the rebranded tree plus the customizations |

## The two layers

A merge of upstream never works, because every rebranded line would conflict. What works is keeping the
fork as two layers and re-applying the second one to a newer release:

1. **Mechanical** — `tools/kubesense-sync/rebrand.py apply` rewrites a checkout (content through the token
   map, paths with `git mv`). It is deterministic and idempotent, so it is never stored as a diff.
2. **Customizations** — everything the script cannot express. `rebrand.py spec --ref upstream/<version>`
   prints this layer as a patch, by exporting the baseline tag, rebranding it in a temporary directory and
   diffing it against the working tree.

## Procedure

```bash
# 0. Capture the customization layer against the CURRENT baseline (see upstream.json)
python3 tools/kubesense-sync/rebrand.py spec --ref upstream/3.18.0 > /tmp/customizations.diff

# 1. Import the new release as a pristine commit on top of the old baseline, and tag it
git checkout -b import/<version> upstream/3.18.0
rsync -a --delete --exclude .git /path/to/dd-sdk-ios-<version>/ ./
git add -A -f . && git commit -m "import dd-sdk-ios <version>" && git tag upstream/<version>
#    (`git add -f`: the release tarball contains a few files upstream's .gitignore ignores)

# 2. Rebrand it on a new branch
git checkout -b kubesense/upgrade-<version> upstream/<version>
git checkout kubesense/main -- tools/kubesense-sync docs/UPSTREAM_SYNC.md
python3 tools/kubesense-sync/rebrand.py collisions      # BEFORE apply: identifiers the rules would merge
python3 tools/kubesense-sync/rebrand.py apply
python3 tools/kubesense-sync/rebrand.py apply           # must report 0 changes (idempotency)
python3 tools/kubesense-sync/rebrand.py check           # must report 0 leftover(s)
python3 tools/kubesense-sync/rebrand.py attribution --ref upstream/<version>   # must report 0 missing

# 3. Re-apply the customizations
git apply --reject --whitespace=nowarn /tmp/customizations.diff
find . -name '*.rej'                                    # resolve each one by hand, then delete it
# Binary files cannot travel in a patch; `spec` lists the fork's as comments. Copy them over:
grep -E '^# binary file (added|differs): ' /tmp/customizations.diff | sed -E 's/^# binary file [a-z]+: //' \
  | xargs git checkout kubesense/main --
```

Then update `upstream.json`, the versions (below) and `CHANGELOG.md`, and validate.

Before step 3, read upstream's `CHANGELOG.md` between the two baselines. New sites, new upload paths,
new per-feature endpoint options, changes to `RemoteConfigurationProvider` and new public API do not show
up as conflicts: they arrive in the rebranded code as Datadog behaviour under Kubesense names, and have to
be found by reading. `git grep -n 'api/v2\|site\.endpoint\|customEndpoint'` after `apply` is a good start.

**`collisions`** lists distinct upstream identifiers that the rules map to the same name. Most groups are
harmless (an Objective-C name such as `DDSite` next to the Swift type `DatadogSite`), but two classes or
two file names in the same module are a compile error: for 3.18.0 that was `DDConfigurationTests` /
`DatadogConfigurationTests` and `DDProfilerTests` / `DatadogProfilerTests`, now handled by dedicated rules.
`apply` also refuses to run when renames would collide on disk (case-insensitively) or would give two
sources of one module the same file name.

## Versions

The Kubesense SDK has its own version line, starting at **1.0.0**. It lives in every `*.podspec`
(`s.version`), `KubesenseCore/Sources/Versioning.swift` (`__sdkVersion`, sent as `KUBESENSE-EVP-ORIGIN-VERSION`
and in every event) and the `sdk_version` front matter of the `*_FEATURE.md` docs.

## Validation

Only the Command Line Tools may be installed (no Xcode, no iOS SDK, no simulator, no XCTest). Everything
below runs with them; build products go to `/tmp/kubesense-ios-verify` (override with `KS_VERIFY_DIR`).

```bash
swift package describe --type json > /dev/null          # the manifest resolves

# Library targets. `mac` = macOS; `cat` = Mac Catalyst, which has UIKit and so covers the iOS-only code
tools/kubesense-sync/verify/build.sh mac KubesenseInternal KubesenseCore KubesenseLogs KubesenseTrace \
    KubesenseWebViewTracking KubesenseSessionReplay KubesenseFlags KubesenseCrashReporting KubesenseProfiling
tools/kubesense-sync/verify/build.sh cat KubesenseInternal KubesenseCore KubesenseLogs KubesenseTrace KubesenseRUM \
    KubesenseSessionReplay KubesenseWebViewTracking KubesenseCrashReporting KubesenseProfiling KubesenseFlags

# Test targets: type-checked only, against a declaration-only XCTest stub (never linked or run)
tools/kubesense-sync/verify/build.sh --tests cat TestUtilities KubesenseInternalTests KubesenseLogsTests \
    KubesenseTraceTests KubesenseRUMTests KubesenseSessionReplayTests KubesenseWebViewTrackingTests \
    KubesenseCrashReportingTests KubesenseFlagsTests KubesenseProfilingTests

# swift-testing tests of the customizations, which do run (Testing.framework ships with the CLT): sites,
# endpoint normalization, the remote configuration document and provider, a real core applying a cached
# document, and the upload URLs and headers of Logs, Trace and Flags exposures
tools/kubesense-sync/verify/run-runtime-tests.sh
```

Compare the test type-check against the same command on the pristine `upstream/<version>` tree: export it
(`git archive upstream/<version> | tar -x -C /tmp/upstream`), copy `verify/build.sh` and
`verify/XCTestStub.swift` to the same place in it, and run it there with the `Datadog*Tests` target names
and `KS_VERIFY_DIR=/tmp/upstream-verify`. The stub is not XCTest, and some errors (Swift 6 isolation of
`XCTestCase`, test-only compilation flags, `XCTestExpectation` APIs the stub lacks) exist on both sides.
Only new errors matter: compare the sorted, de-duplicated `error:` lines of both sides.
For 3.18.0 the Session Replay (Swift 6 main-actor isolation in two test files) and WebView Tracking
(`#if`-gated test hooks) test targets fail identically on both sides, and the Profiling test target's
type-check did not finish within 10 minutes.
`KubesenseCore/Tests`, `Kubesense/IntegrationUnitTests` and the `IntegrationTests` and `SmokeTests` apps are
only part of the Xcode project and are not covered.

What really validates the SDK is Xcode: `make test` (unit tests on the simulator), `make api-surface-verify`
(the `api-surface-swift` / `api-surface-objc` files are regenerated by `xcodebuild`; the fork edited them by
hand for its API changes), and a run of the example app against a collector.

## What must survive every upgrade

`rebrand.py spec` lists these; this is the same list in human terms.

| Area | Where |
| --- | --- |
| Site model | `KubesenseSite { prod, staging }` with hosts `us2.kubesense.ai` / `dev.kubesense.ai` (`KubesenseInternal/Sources/Context/KubesenseSite.swift`); `objc_KubesenseSite.prod()` / `.staging()`; default `.prod` in `Kubesense.Configuration` |
| Collector endpoint | `Kubesense.Configuration.kubesenseRumEndpoint` and `kubesenseRumEndpointURL` (host only, always https, like Android `useKubesenseRumEndpoint`); `KubesenseContext.intakeEndpoint`, threaded through `KubesenseContextProvider` in `Kubesense.swift` / `KubesenseCore.swift` |
| Upload paths | `context.intakeEndpoint.appendingPathComponent(...)` in each feature's request builder: RUM `rum/api/v1`, Logs `rum/api/v1/logs`, Trace `rum/api/v1/spans`, Session Replay segments and resources `rum/api/v1/replay`, Profiling `rum/api/v1/profile`, Flags exposures `rum/api/v1/exposures`, evaluations `rum/api/v1/flagevaluation`, assignments `precompute-assignments` (`FlagAssignmentsFetcher.swift`); the Datadog flags CDN hosts are removed |
| Per-feature endpoints | `customEndpoint` of RUM, Logs, Trace, Session Replay, Profiling and Flags' `customFlagsEndpoint` / `customExposureEndpoint` / `customEvaluationEndpoint` are `internal` test hooks: removed from the public inits and the Objective-C wrappers. Tests and the `IntegrationTests` runner set them through `@testable import` |
| Remote configuration | `RemoteConfigDocument` (`KubesenseInternal/Sources/Models/RC/RemoteConfigDocument.swift`: Android document, fail-safe accessors, `RemoteConfiguration(document:)` translation onto upstream's typed model, `isFeatureDisabledRemotely`); `KubesenseCoreProtocol.remoteConfigDocument`; `RemoteConfigurationProvider` rewritten for `GET /rum/api/v1/sdk-config` with `KUBESENSE-API-KEY`, cache `kubesense-sdk-config.json`, apply-at-next-launch, periodic refresh; `Kubesense.Configuration.remoteConfigurationEnabled` / `remoteConfigurationRefreshPeriod` (replacing upstream's `RemoteConfiguration(id:customURL:)`), their Objective-C properties; core `batchSize` / `uploadFrequency` override in `Kubesense.swift` |
| Remote settings in features | `features.*` switches in `RUM.swift`, `SessionReplay.swift`, `Trace.swift`, `Logs.swift`, `Flags.swift`, `Profiling.swift`; `rum.sessionSampleRate`, `rum.collectAccessibility`, `sessionReplay.startRecordingImmediately`, `trace.networkInfoEnabled`, `flags.*`, and the `logs` section (`Logger.Configuration.applying(remoteConfigDocument:)`). Android-only keys with no iOS setting are ignored: `rum.trackNonFatalAnrs`, `logs.logcatLogsEnabled`, `sessionReplay.dynamicOptimizationEnabled` / `minRAMSizeMb` / `minCPUCoreNumber`, `imagePrivacy: MASK_LARGE_ONLY` |
| Profiling quota | No quota request: `ProfilerFeature` defaults to `AdmittingProfilingQuotaChecker` (`ProfilingQuotaChecker.swift`), which admits every profile. Neither kubecol nor the Android SDK has a quota service; upstream's `ProfilingQuotaChecker` (`quota.<host>/api/v2/profiling/quota`) is kept, unused, with its tests |
| WebView bridge | `window.KubeSenseEventBridge` (rule `DatadogEventBridge`), the name the browser fork reads |
| Versions | 1.0.0 in podspecs, `Versioning.swift`, feature docs |
| Podspec metadata | `s.authors = { "Kubesense" => "info@kubesense.ai" }`, `s.homepage`, no `social_media_url` |
| Podspec platforms | iOS only: the `tvos`, `watchos` and `visionos` deployment targets upstream declares are removed from every `Kubesense*.podspec`, with a comment saying they are planned. CocoaPods validates every declared platform on `pod trunk push`, so add them back only with those platforms tested. `Package.swift` keeps upstream's platform list |
| Xcode project | `RemoteConfigDocument.swift` and `RemoteConfigDocumentTests.swift` registered in `Kubesense/Kubesense.xcodeproj` (`tools/kubesense-sync/xcodeproj_add.py`) |
| Tests | Site, endpoint, request-builder URL, remote-configuration and Objective-C tests rewritten for the Kubesense model; remote document tests per feature (`features.*` switches and feature settings in `RUMTests`, `TraceTests`, `SessionReplayTests`, `ProfilingTest`, `LogsTests`, `FlagsTests`); `TestUtilities` mocks (`KubesenseSite` mocks, `remoteConfigDocument`, `Kubesense.Configuration.mockWith(remoteConfigurationEnabled: false)`); the swift-testing copies in `tools/kubesense-sync/verify/runtime` |
| App settings | `CUSTOM_RUM_URL` in `xcconfigs/Kubesense.xcconfig` is the Example app's `kubesenseRumEndpoint` host |
| API surface | `api-surface-swift` / `api-surface-objc` edited by hand for the API changes above |
| Fork-owned files | `README.md`, `CLAUDE.md`, `CHANGELOG.md` (Kubesense entry on top of upstream's history), this file |
| Removed | Not a patch: `REMOVED_PATHS` in `rebrand.py`, which `apply` deletes from every new release (`spec` then never shows them, and `attribution` does not expect their notices). Datadog's CI and its tooling: `.gitlab-ci.yml`, `.github/chainguard/`, `.github/CODEOWNERS`, the Confluence publish workflow, `E2ETests/` and `BenchmarkTests/` (Synthetics apps), `tools/dogfooding/`, the Vault-backed `tools/{e2e-build-upload,benchmark-build-upload,runner-setup,upload-smoke-test-reports}.sh`; the Session Replay snapshot tests (`KubesenseSessionReplay/SRSnapshotTests/` except its `SRFixtures` package, which `IntegrationTests` imports, `tools/sr-snapshots/`, `tools/sr-snapshot-test.sh`), whose reference images live in Datadog's private snapshots repository; `tools/secrets/` (the Vault client), `tools/env-check.sh` (checks Datadog's CI tools), `tools/xcode-templates/` (they stamp new files with Datadog's copyright), `tools/protoc-pprof.sh` and `tools/doc-build.sh` (generators for the shipped profiling protobuf code and Swift Package Index docs); and `MIGRATION.md` and `docs/session_replay_performance.md`, which describe Datadog's releases and benchmarks. The `Makefile` targets, lint paths and license-check exclusions for them are removed in the customization layer. With them go the Test Visibility setup of `tools/test.sh` (it uploads test results to Datadog) and the CI token block of `tools/carthage-shim.sh` |
| Release scripts | `tools/release/publish-podspec.sh` uses the `pod trunk register` session (or `COCOAPODS_TRUNK_TOKEN`) and `publish-github.sh` the `gh` login, instead of tokens from Datadog's Vault and `dd-octo-sts` |

## The token map

`rebrand.py` holds the rules. The non-obvious ones, each checked against the Kubesense Android SDK
(`main`) or browser SDK:

| Upstream | Kubesense | Why |
| --- | --- | --- |
| `DD-API-KEY`, `DD-EVP-ORIGIN(-VERSION)`, `DD-REQUEST-ID`, `DD-IDEMPOTENCY-KEY` | `KUBESENSE-*` | Android `RequestFactory`; kubecol reads `Kubesense-Api-Key` (case-insensitive) |
| `ddsource`, `ddtags` | `ksource`, `ktags` | Android query parameters; kubecol `GetRequestTags` |
| `x-datadog-*`, `TracingHeaderType.datadog` | `x-kubesense-*`, `.kubesense` | Android `TracingInterceptor` |
| `_dd`, `_dd.*`, `_dd-custom-header-graph-ql-*` | `_kubesense`, `_kubesense.*`, `_kubesense-custom-header-graph-ql-*` | Android event schemas and `GraphQLHeaders` |
| `DatadogEventBridge` | `KubeSenseEventBridge` | browser fork `eventBridge.ts` (capital S) |
| `Datadog` (Swift entry point) / `DDDatadog` (Objective-C) | `Kubesense` / `KubesenseSDK` | `KubesenseKubesense` otherwise; `Kubesense` alone collides with the `DatadogTests` test case |
| `DD` + capital (`DDRUMMonitor`, `DDSpan`, `DDAssertEqual`) | `Kubesense` + capital | Not `KS`: KSCrash, imported by crash reporting, owns that prefix (`KSCrashReport`) |
| `dd` + capital (`ddTags`, `ddAPIKeyHeader`) | `kubesense` + capital | what the Flutter plugin already calls (`kubesenseAPIKeyHeader`) |
| `DD_*`, `dd_*` (macros, env vars, C functions) | `KUBESENSE_*`, `kubesense_*` | |
| `com.datadoghq.*` (and the `com.datadogqh.*` typo) | `ai.kubesense.*` | bundle ids, queue labels, storage directories |
| `dd-sdk-ios` | `kubesense-ios-sdk` | repository, SPM identity, telemetry `service` |

Kept as they are, on purpose:

- `dd.trace_id`, `dd.span_id` (log correlation; Android `LogAttributes`). They are kept only as whole names
  (`PRESERVED_PATTERNS`): the RUM cross-platform attributes `_dd.trace_id` / `_dd.span_id` become
  `_kubesense.trace_id` / `_kubesense.span_id`, like Android `RumAttributes.TRACE_ID` / `SPAN_ID`.
- `dd-client-token` / `DD-CLIENT-TOKEN` and
  `dd-application-id` (flags assignment headers; `DD-CLIENT-TOKEN` is the same header, compared
  case-insensitively to recognise the SDK's own requests), `dd_env` (flags request body) — the Android fork
  kept them.
- The W3C `tracestate` vendor key `dd=` — Android kept it.
- The bare `DD` namespace (`DD.logger`, `DD.telemetry`) and the bare `dd` identifier (the `.dd` extension
  namespace such as `view.dd.sessionReplayPrivacyOverrides`, and the `dd: DD` property of the generated
  models). A bare two-letter identifier cannot be renamed safely by text substitution (date formats,
  local variables, generated models), and the Flutter plugin calls `DD.logger`.
- External projects and tools: `rum-events-format`, `dd-go`, `datadog-ci`, `dd-octo-sts`,
  `dd-sdk-swift-testing` and its `DatadogSDKTesting` product / `.datadogTesting` trait,
  `dd-sdk-ios-apollo-interceptor`, `dd-openfeature-provider-swift`, `dd-mobile-session-replay-snapshots`,
  `dd-trace-java`, `dd-trace-go`, `datadoghq.atlassian.net`, the `datadoghq.dev` test page.
- Interface Builder object ids (`ADw-wv-DDT`), which the rules mask.

## Traps

- **Attribution notices.** Besides "This product includes software developed at Datadog" and
  "Copyright … Datadog, Inc.", upstream carries "Copyright © 2023 Datadog. All rights reserved." in example
  app Info.plist settings, "… altered by Datadog." / "… modified by Datadog." in third-party files
  (Kronos, Sysctl, Flight School), and `\authors Datadog Inc.` crediting Datadog's changes to the vendored
  protobuf-c (`KubesenseProfiling/Mach/include/protobuf-c.h`). `PRESERVED_LINE` covers all of them; `rebrand.py attribution` proves
  every such line of the baseline still exists verbatim.
- **Preserved tokens are masked as substrings.** `dd.trace_id` in `PRESERVED_TOKENS` also masked the
  `dd.trace_id` inside `_dd.trace_id`, so the RUM attribute silently kept its Datadog name. Tokens that
  must only match as whole names go in `PRESERVED_PATTERNS` (regular expressions with a lookbehind).
- **`\b` does not match after `_`.** `_dd.x` and `_dd-custom-header` need a lookbehind rule, and so do the
  identifier rules (`(?<![A-Za-z0-9])DD(?=[A-Z])`).
- **BSD tools.** `sed -E` and `git grep -E` on macOS silently ignore `\b`; use `perl`, Python or
  `git grep -P`.
- **Case-insensitive filesystem.** Check renames for collisions before moving anything (`apply` does).
- **Paths and contents must use the same rules**, or `Package.swift`, the podspecs and `project.pbxproj`
  stop pointing at the files. `rename_path` applies the content rules to each path component.
- **New files are not picked up by the Xcode project.** SwiftPM and CocoaPods glob; `project.pbxproj`
  lists files. Use `xcodeproj_add.py` and `plutil -lint` the result.
- **The Command Line Tools' libc++ headers are shadowed** by a stale `usr/include/c++/v1`, so KSCrash and
  the profiler fail with `'string' file not found`. `verify/build.sh` passes `-nostdinc++` and the SDK's
  libc++ path.
- **`swift build` on the repository writes `Package.resolved`** at its root (git-ignored); delete it.
- **Remote configuration and tests.** It is on by default, so a test or sample that initializes the SDK
  with a plain `Kubesense.Configuration` fetches from the network. `Kubesense.Configuration.mockWith`
  defaults it to off; do the same in new tests.

## Downstream

- **Flutter** (`kubesense-flutter-sdk`, written against dd-sdk-ios 3.15.0). Its iOS Swift code type-checks
  against this fork (Mac Catalyst, stub `Flutter` module) except `RUM.Configuration.customEndpoint` and
  `Logs.Configuration.customEndpoint`, which are internal here. What it needs:
  - `Kubesense.Configuration(fromEncoded:)` (`KubesenseSdkPlugin.swift`) to map `kubesenseRumEndpoint`
    (`String` → `kubesenseRumEndpoint`, normalized by the SDK), `remoteConfigurationEnabled`
    (`Bool` → `remoteConfigurationEnabled`) and `remoteConfigurationRefreshPeriodMs`
    (milliseconds → `remoteConfigurationRefreshPeriod`, seconds), like its Android plugin does;
  - `KubesenseRumPlugin.swift` / `KubesenseLogsPlugin.swift` to stop reading `customEndpoint` (Dart no longer
    sends it; the properties are not public here);
  - its own Session Replay request builders (`RequestBuilder.swift`, `ResourceRequestBuilder.swift`) moved
    from `context.site.endpoint` + `api/v2/replay` to `context.intakeEndpoint` + `rum/api/v1/replay`;
  - the dependency moved to this SDK's `1.0.0` (`Package.swift` pins `exact: "3.15.0"` or `from: "3.0.0"`,
    podspecs `'3.15.0'`, `'~> 3'`, `'~> 3.0'`) and the minimum raised to iOS 15 (upstream 3.17; the plugins
    declare iOS 12 / 13);
  - on the Dart side, `lib/src/rum/attributes.dart` still sends `_dd.trace_id` / `_dd.span_id`, which both
    native SDKs now read as `_kubesense.trace_id` / `_kubesense.span_id`.
- **Collector (kubecol).** `POST /rum/api/v1/logs`, `/profile` and `/exposures` are accepted and dropped;
  `/precompute-assignments` answers 501 (and, with authentication on, reads `Kubesense-Api-Key` while the
  flags request carries `dd-client-token`, as on Android); `/rum/api/v1/flagevaluation` does not exist (404,
  the batch is dropped). Its default `sdk-config` document switches `logs`, `trace` and `profiling` off, so
  apps without a stored configuration lose those features from their second launch on.
- **Android.** Registers its WebView bridge as `KubesenseEventBridge`, while the browser SDK reads
  `KubeSenseEventBridge` (this SDK uses the browser's spelling).
- **Staging hosts differ.** `KubesenseSite.staging` is `dev.kubesense.ai` here and on Android, but
  `rum.tyke.ai` in the browser SDK.
