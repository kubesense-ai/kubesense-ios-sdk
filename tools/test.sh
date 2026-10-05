#!/bin/zsh

# Usage:
# $ ./tools/test.sh -h
# Executes unit tests for a specified --scheme, using the provided --os, --platform, and --device.

# Options:
#   --device: Specifies the simulator device for running tests, e.g. 'iPhone 15 Pro'
#   --scheme: Identifies the test scheme to execute
#   --platform: Defines the type of simulator platform for the tests, e.g. 'iOS Simulator'
#   --os: Sets the operating system version for the tests, e.g. '17.5'

set -eo pipefail
source ./tools/utils/argparse.sh
source ./tools/utils/echo-color.sh
source ./tools/utils/current-git.sh

set_description "Executes unit tests for a specified --scheme, using the provided --os, --platform, and --device."
define_arg "scheme" "" "Identifies the test scheme to execute" "string" "true"
define_arg "os" "" "Sets the operating system version for the tests, e.g. '17.5'" "string" "true"
define_arg "platform" "" "Defines the type of simulator platform for the tests, e.g. 'iOS Simulator'" "string" "true"
define_arg "device" "" "Specifies the simulator device for running tests, e.g. 'iPhone 15 Pro'" "string" "true"

check_for_help "$@"
parse_args "$@"

WORKSPACE="Kubesense.xcworkspace"
DESTINATION="platform=$platform,name=$device,OS=$os"
SCHEME=$scheme

# Suppress lint Build Phase during xcodebuild test runs. CI runs `make lint` standalone
export SKIP_LINT=1

set -x

xcodebuild -version

if [ "$CI" = "true" ]; then
    mkdir -p ResultBundles
    RESULT_BUNDLE_PATH="ResultBundles/${SCHEME}.xcresult"
    rm -rf "$RESULT_BUNDLE_PATH"
    # Tee the raw xcodebuild log to disk (flushed line-by-line) so it survives even if the
    # process gets killed mid-run, e.g. by RUNNER_SCRIPT_TIMEOUT on a hung test. The raw
    # .xcresult bundle and this log are uploaded as-is (no need to zip): GitLab's artifact
    # uploader already archives whatever paths match, zip or not.
    xcodebuild -workspace "$WORKSPACE" -destination "$DESTINATION" -scheme "$SCHEME" -resultBundlePath "$RESULT_BUNDLE_PATH" test 2>&1 | tee "ResultBundles/${SCHEME}.log" | xcbeautify
else
    xcodebuild -workspace "$WORKSPACE" -destination "$DESTINATION" -scheme "$SCHEME" test 2>&1 | xcbeautify
fi
