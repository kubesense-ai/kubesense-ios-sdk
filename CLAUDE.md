# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is the Kubesense SDK for iOS and tvOS — a modular Swift/Objective-C library for observability (Logs,
Traces, RUM, Session Replay, Crash Reporting, WebView Tracking, Feature Flags and Profiling). It is a
rebranded fork of [DataDog/dd-sdk-ios](https://github.com/DataDog/dd-sdk-ios), sending data to the Kubesense
collector the same way the Kubesense Android and browser SDKs do.

**Start with `AGENTS.md`** — it is the entry point to the SDK documentation (architecture, conventions,
testing). It was inherited from upstream and mechanically rebranded, so a few of its workflows (JIRA,
Datadog CI, `develop` branch) describe upstream's process rather than this fork's.

## Relationship to upstream

**Before porting anything from upstream, or touching `tools/kubesense-sync/`, read
[`docs/UPSTREAM_SYNC.md`](docs/UPSTREAM_SYNC.md).** It holds the procedure, the token map, the list of
customizations that must survive an upgrade, and the traps already paid for.

- The fork is two layers: a mechanical rename (`tools/kubesense-sync/rebrand.py apply`) and hand-made
  customizations (`rebrand.py spec --ref upstream/<version>` prints them as a patch).
- The pristine upstream tree is the commit tagged `upstream/<version>`; Kubesense work lives on
  `kubesense/main`. The baseline is recorded in `tools/kubesense-sync/upstream.json`.
- Never rewrite `LICENSE`, `NOTICE`, `LICENSE-3rdparty.csv`, or the Datadog attribution/copyright header
  lines; `rebrand.py attribution --ref upstream/<version>` proves they survived.
- Wire names are load-bearing: `KUBESENSE-API-KEY`, `ksource`/`ktags`, `x-kubesense-*`, `_kubesense`,
  `window.KubeSenseEventBridge`, and the `/rum/api/v1/...` upload paths must match the collector and the
  other Kubesense SDKs. Renaming one is a breaking change, not a cleanup.
- Some Datadog-looking names are kept on purpose (`dd.trace_id` / `dd.span_id` in logs, `dd-client-token`,
  `dd-application-id`, `dd_env`, the `DD` and `.dd` Swift namespaces, the W3C `dd=` tracestate key); see the
  token map before "fixing" them. The RUM attributes `_kubesense.trace_id` / `_kubesense.span_id` are not
  among them.

## Building without Xcode

Only the Command Line Tools may be available. `docs/UPSTREAM_SYNC.md` ("Validation") has the exact
commands to build every library target for macOS and Mac Catalyst with `swift build`, to type-check the
test targets against a compile-only XCTest stub (XCTest tests cannot be run that way), and to run the
swift-testing tests of the Kubesense customizations in `tools/kubesense-sync/verify/runtime`, which do run.

## Available Skills

The skills under `.claude/skills` were inherited from upstream (branch/commit/PR conventions of Datadog's
repository) and rebranded; treat them as references, not as this fork's process.
