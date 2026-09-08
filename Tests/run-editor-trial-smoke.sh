#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
trial_build_dir=$(mktemp -d /private/tmp/watchmotion-trial.XXXXXX)
xcrun swiftc 'JeonstarLab Mac/Models/EditorTrial.swift' Tests/EditorTrialSmokeTests.swift -o "$trial_build_dir/trial-tests"
"$trial_build_dir/trial-tests"
