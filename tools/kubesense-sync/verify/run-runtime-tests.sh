#!/bin/bash
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
#
# Runs the swift-testing tests of tools/kubesense-sync/verify/runtime on macOS, without Xcode: the Command
# Line Tools ship swift-testing (Testing.framework) but not XCTest. Build products go to $KS_VERIFY_DIR.
set -euo pipefail
HERE=$(cd "$(dirname "$0")" && pwd)
OUT=${KS_VERIFY_DIR:-/tmp/kubesense-ios-verify}
SDK=$(xcrun --show-sdk-path)
FW=/Library/Developer/CommandLineTools/Library/Developer/Frameworks
swift test --build-system native --package-path "$HERE/runtime" --scratch-path "$OUT/build-runtime" \
  --cache-path "$OUT/cache" --config-path "$OUT/config" --security-path "$OUT/security" \
  -Xcxx -nostdinc++ -Xcxx -isystem -Xcxx "$SDK/usr/include/c++/v1" \
  -Xswiftc -F -Xswiftc "$FW" -Xlinker -F -Xlinker "$FW" -Xlinker -rpath -Xlinker "$FW" \
  -Xlinker -rpath -Xlinker /Library/Developer/CommandLineTools/Library/Developer/usr/lib
