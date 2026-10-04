#!/bin/bash
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
#
# Builds (or, with --tests, type-checks) Swift package targets without Xcode, using the Command Line Tools.
#
#   tools/kubesense-sync/verify/build.sh mac  KubesenseCore KubesenseLogs ...     # macOS
#   tools/kubesense-sync/verify/build.sh cat  KubesenseRUM KubesenseSessionReplay # Mac Catalyst (UIKit)
#   tools/kubesense-sync/verify/build.sh --tests cat KubesenseRUMTests ...        # test targets, XCTest stub
#
# Test targets are only type-checked: XCTest is not part of the Command Line Tools, so they are compiled
# against XCTestStub.swift, a declaration-only stand-in, and never linked or run.
# Build products go to $KS_VERIFY_DIR (default /tmp/kubesense-ios-verify), never into the repository.
set -euo pipefail

TESTS=0
if [ "${1:-}" = "--tests" ]; then TESTS=1; shift; fi
MODE=${1:?usage: build.sh [--tests] <mac|cat> <target>...}; shift
ROOT=$(cd "$(dirname "$0")/../../.." && pwd)
OUT=${KS_VERIFY_DIR:-/tmp/kubesense-ios-verify}
SDK=$(xcrun --show-sdk-path)
IOS_SUPPORT=$SDK/System/iOSSupport
mkdir -p "$OUT/logs"

# The Command Line Tools ship a stale usr/include/c++/v1 (three files) that shadows the SDK's libc++
# headers, so every C++ file of KSCrash and the profiler fails with "'string' file not found".
FLAGS=(-Xcxx -nostdinc++ -Xcxx -isystem -Xcxx "$SDK/usr/include/c++/v1")
if [ "$MODE" = cat ]; then
  FLAGS+=(--triple arm64-apple-ios17.0-macabi
    -Xcc -iframework -Xcc "$IOS_SUPPORT/System/Library/Frameworks" -Xcc -isystem -Xcc "$IOS_SUPPORT/usr/include"
    -Xswiftc -Fsystem -Xswiftc "$IOS_SUPPORT/System/Library/Frameworks" -Xswiftc -I -Xswiftc "$IOS_SUPPORT/usr/lib/swift")
  STUB_TARGET=arm64-apple-ios15.0-macabi
  STUB_FLAGS=(-Fsystem "$IOS_SUPPORT/System/Library/Frameworks" -I "$IOS_SUPPORT/usr/lib/swift")
elif [ "$MODE" = mac ]; then
  STUB_TARGET=arm64-apple-macosx12.6
  STUB_FLAGS=()
else
  echo "mode must be mac or cat" >&2; exit 2
fi

if [ $TESTS = 1 ]; then
  STUB="$OUT/xctest-stub/$MODE"
  mkdir -p "$STUB"
  swiftc -parse-as-library -emit-module -module-name XCTest -target $STUB_TARGET -sdk "$SDK" \
    "${STUB_FLAGS[@]+"${STUB_FLAGS[@]}"}" "$(dirname "$0")/XCTestStub.swift" -emit-module-path "$STUB/XCTest.swiftmodule"
  FLAGS+=(-Xswiftc -I -Xswiftc "$STUB" -Xswiftc -F -Xswiftc /Library/Developer/CommandLineTools/Library/Developer/Frameworks)
fi

status=0
for target in "$@"; do
  log="$OUT/logs/$MODE-$target.log"
  if swift build --build-system native --package-path "$ROOT" --scratch-path "$OUT/build-$MODE" \
      --cache-path "$OUT/cache" --config-path "$OUT/config" --security-path "$OUT/security" \
      "${FLAGS[@]}" --target "$target" > "$log" 2>&1; then
    echo "$MODE $target: OK"
  else
    echo "$MODE $target: FAILED ($(grep -c 'error:' "$log") error lines, see $log)"
    status=1
  fi
done
exit $status
