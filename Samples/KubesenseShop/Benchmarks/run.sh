#!/bin/bash
# Unless explicitly stated otherwise all files in this repository are licensed under the Apache License Version 2.0.
# This product includes software developed at Datadog (https://www.datadoghq.com/).
# Kubesense addition to the fork of dd-sdk-ios, see docs/UPSTREAM_SYNC.md.
#
# Runs the SDK overhead benchmarks of the Kubesense Shop and prints the report.
#
#   DESTINATION='platform=iOS,name=My iPhone' ./Benchmarks/run.sh
#
# DESTINATION defaults to the iPhone 17 Pro simulator. A physical device gives steadier numbers and the
# hitch and frame-rate metrics, which the simulator does not report. Results go to build/benchmarks/.

set -euo pipefail
cd "$(dirname "$0")/.."

DESTINATION="${DESTINATION:-platform=iOS Simulator,name=iPhone 17 Pro}"
OUT="build/benchmarks/$(date +%Y%m%d-%H%M%S)"
mkdir -p "$OUT"

xcodegen generate --quiet
echo "Benchmarking on '$DESTINATION' (about 15 minutes); log: $OUT/xcodebuild.log"
if ! xcodebuild -project KubesenseShop.xcodeproj -scheme KubesenseShopBenchmarks \
    -destination "$DESTINATION" -derivedDataPath build/DerivedData \
    -resultBundlePath "$OUT/benchmarks.xcresult" test > "$OUT/xcodebuild.log" 2>&1; then
    grep -E "error:|failed" "$OUT/xcodebuild.log" | tail -20
    echo "Benchmarks failed; see $OUT/xcodebuild.log" >&2
    exit 1
fi

python3 Benchmarks/report.py "$OUT/benchmarks.xcresult" --output "$OUT/report.md"
echo
echo "Saved $OUT/report.md"
