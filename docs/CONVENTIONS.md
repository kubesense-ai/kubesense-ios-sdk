# Coding Conventions

## Naming Conventions

**Types:** `PascalCase` for classes, structs, enums, protocols
**Functions/Properties:** `camelCase`
**Protocols:** Named as capabilities or contracts (e.g., `KubesenseCoreProtocol`, `FeatureScope`, `MessageBusReceiver`)
**Internal types:** Prefixed with module context (e.g., `RUMCommand`, `RUMViewScope`)
**Mock types:** Suffixed with `Mock` or `Spy` (e.g., `HTTPClientMock`, `SnapshotProcessorSpy`)
**Test files:** Mirror source path with `Tests` suffix (e.g., `RUMViewScopeTests.swift`)

**File naming patterns:**
- Feature entry point: `{Feature}.swift` (e.g., `RUM.swift`, `Logs.swift`)
- Feature configuration: `{Feature}Configuration.swift`
- Feature plugin: `Feature/{Feature}Feature.swift`
- Scope files: `RUM{ScopeName}Scope.swift`

## SwiftLint Rules (sources)

- `explicit_top_level_acl` — all top-level declarations must have explicit access control
- `force_cast`, `force_try`, `force_unwrapping` — forbidden in source code
- `todo_without_jira` — every TODO references a GitHub issue (`TODO: #123`); upstream code keeps its own tracker keys (`TODO: RUM-123`), leave those as they are
- `unsafe_uiapplication_shared` — see [UIApplication Access](#uiapplication-access) below
- `required_reason_api_name` — see [Required Reason API Names](#required-reason-api-names) below

Config: `tools/lint/sources.swiftlint.yml` (sources), `tools/lint/tests.swiftlint.yml` (tests)

### UIApplication Access

`UIApplication.shared` is **forbidden** in source code (lint severity: `error`). Apple marks it `@available(iOSApplicationExtension, unavailable)` — calling it in an app extension target is a compiler error. Since the SDK can be linked into both apps and extensions, all code must use the safe alternative:

```swift
// WRONG — lint error, compiler error in extensions
let app = UIApplication.shared

// CORRECT — returns nil in extension context, safe everywhere
let app = UIApplication.dd.managedShared
```

`UIApplication.dd.managedShared` (defined in `KubesenseInternal/Sources/Utils/UIKitExtensions.swift`) uses KVC (`value(forKeyPath:)`) to bypass the compiler restriction. It returns `UIApplication?` — `nil` in app extension context, the shared instance in a full app.

This restriction applies only to `UIApplication.shared`. `UIDevice.current` is safe in extensions and has no lint rule.

### Required Reason API Names

The `required_reason_api_name` rule (severity: `error`) bans declaring symbols whose names match Apple's Required Reason APIs. This prevents third-party static analysis tools from flagging false positives on SDK consumers.

**You cannot use these as property, variable, or function names** (even if your code has nothing to do with the restricted API):

| Category | Banned names |
|----------|-------------|
| File timestamps | `.creationDate`, `.modificationDate`, `.fileModificationDate`, `.creationDateKey`, `.contentModificationDateKey` |
| System uptime | `systemUptime`, `mach_absolute_time()` |
| Disk space | `volumeAvailableCapacityKey`, `volumeTotalCapacityKey`, `systemFreeSize`, `systemSize` |
| User defaults | `UserDefaults`, `NSUserDefaults`, `AppStorage` |
| Keyboards | `activeInputModes` |

These names are allowed in comments, doc comments, and string literals — only actual code references are blocked. Full list: `tools/lint/sources.swiftlint.yml` lines 101-155.

Do not disable lint rules except where the rule is incorrect and a GitHub issue tracks reinstating it.
Lint needs SwiftLint (`brew install swiftlint`); run it with `make lint`.

## Conditional Compilation

- `SPM_BUILD` — defined when building via Swift Package Manager
- `KUBESENSE_BENCHMARK` — set this environment variable when building the package to compile the SDK's internal performance metrics (`Package.swift`). The Kubesense Shop benchmarks (`make benchmark`) measure the app from the outside and do not need it
- `KUBESENSE_COMPILED_FOR_INTEGRATION_TESTS` — toggles `@testable` imports for integration tests
- Platform checks: `#if os(iOS)`, `#if canImport(UIKit)`, `#if os(tvOS)`

## Generated Models — DO NOT EDIT

The models in `KubesenseInternal/Sources/Models/` are generated and arrive with each upstream release. Never hand-edit them.

- RUM and Session Replay models come from upstream's public [rum-events-format](https://github.com/DataDog/rum-events-format) schema: regenerate with `make rum-models-generate GIT_REF=<ref>` (or `sr-models-generate`) and check with `make rum-models-verify`.
- The remote configuration models (`Models/RC/RCDataModels.swift`) come from a private upstream repository, so `rc-models-generate` cannot run here; take them as each release ships them.

One file there is the fork's own and is edited by hand: `Models/RC/RemoteConfigDocument.swift`, the Kubesense remote configuration document.

## File Headers

Apache-2.0 requires keeping upstream's attribution, so the header depends on where a file came from.

**Files that came from upstream** keep their header exactly as it is, however much the fork changes them. Never remove or reword it; `rebrand.py attribution` checks that every upstream notice is still there:

```swift
/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Copyright 2019-Present Datadog, Inc.
 */
```

**New files written for the fork** name the project they add to, and carry no Datadog copyright:

```swift
/*
 * Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
 * This product includes software developed at Datadog (https://www.datadoghq.com/).
 * Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
 */
```

Python and shell scripts use the same three lines as `#` comments. The rebrand rules leave this header line alone.

`NOTICE` states that the SDK is derived from dd-sdk-ios and carries upstream's notice; `LICENSE` is upstream's. Neither is rebranded.

## Working on Upstream Code

Every change to a file that came from upstream is replayed onto each new upstream release (see [UPSTREAM_SYNC.md](UPSTREAM_SYNC.md)) and can conflict there. Keep those changes small and put new behaviour in new files where you can. Paths the fork deletes go on `REMOVED_PATHS` in `tools/kubesense-sync/rebrand.py`, not just `git rm`, so an upgrade does not bring them back.

## Branches, Commits and Pull Requests

### Branches

- `main` is protected: every change lands through a pull request with an approving review. No direct pushes, no force pushes.
- Branch from an up-to-date `main` and name the branch after the change type: `feat/kubesense-shop-sample`, `fix/carthage-otel-binary`, `chore/trim-tools`, `docs/kubesense-license`.
- A change that needs an open pull request branches from that pull request's branch and targets it. GitHub retargets it to `main` when the first one merges and its branch is deleted.

### Commits

- [Conventional Commits](https://www.conventionalcommits.org/): `type(scope): subject`, for example `feat(samples): Kubesense Shop sample app for iOS` or `chore(podspecs): declare iOS only`. Types: `feat`, `fix`, `docs`, `chore`, `refactor`, `test`, `perf`; the scope, the area touched, is optional.
- Subject in the imperative, starting lowercase after the colon, no trailing period, at most 72 characters. The body explains what changed and why, wrapped at 72.
- **No "Datadog" and no "dd" in commit messages, pull request titles or descriptions.** The check is a case-insensitive substring match, so it also rules out words such as *add*, *address*, *hidden*, *embedded* and *middle*, and paths such as `xcshareddata`. Say "upstream" for the upstream project and its company, and reword the rest. Check a message before committing:

  ```bash
  grep -inE 'dd|datadog' <<< "$message"   # must print nothing
  ```

  File contents are not covered: attribution, external URLs and wire names keep their spelling.
- Stage files by name and read `git status` first. Never `git add -A` or `git add -f`: credentials live in git-ignored files (`Samples/KubesenseShop/Config/local.json`, `*.local.xcconfig`).
- Commits are not signed; GitHub signs the merge commits.

### Pull Requests

- The title follows the commit subject format.
- The description has three parts: **What and why?**, **How?**, and **Verification**: the commands run and their results, and anything that was not run.
- After approval, merge with a merge commit and delete the branch.

### Checks before opening a pull request

There is no CI, so run what the change touches, locally. Build and test with Xcode 26: Xcode 27 rejects the iOS 12 deployment target of the KSCrash and OpenTelemetry packages.

| Change | Run |
| --- | --- |
| SDK sources | `make test-ios SCHEME="<Module>"`, `make lint` |
| Public API | `make api-surface` and commit `api-surface-swift` / `api-surface-objc`; `make api-surface-verify` |
| Files from upstream, rebrand rules, `tools/kubesense-sync` | `rebrand.py apply` (0 changes), `rebrand.py check` (0 leftovers), `rebrand.py attribution --ref upstream/3.18.0` (0 missing) |
| License headers | `make license-check` |
| Feature docs (`*_FEATURE.md`) | `make feature-docs-verify` |
| Sample app | `make -C Samples/KubesenseShop test`, and `ui-test` against the sample API |
| Performance-sensitive code | `make benchmark`; compare with [benchmarks.md](benchmarks.md) |

### Releases

- `make bump` sets the version in `Versioning.swift` and every podspec and commits `chore: bump version to <version>`.
- The podspecs declare iOS only. They are published in dependency order with `make release-publish-internal-podspecs`, then `make release-publish-dependent-podspecs`, using the session of `pod trunk register`.
