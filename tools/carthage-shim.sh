#!/bin/zsh

# Usage:
# - in repo root:
# $ ./tools/carthage-shim.sh [carthage commands and parameters]
# - in different directory:
# $ REPO_ROOT="../../" ../../tools/carthage-shim.sh [carthage commands and parameters]
#
# Runs Carthage from the repository root or another directory.

carthage "$@"
