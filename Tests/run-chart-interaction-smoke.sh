#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_output_dir=$(mktemp -d /private/tmp/watchmotion-chart-smoke.XXXXXX)
xcrun swiftc 'JeonstarLab Mac/Views/ChartInteractionOverlay.swift' Tests/ChartInteractionSmokeTests.swift \
  -o "$test_output_dir/chart-interaction-smoke"
"$test_output_dir/chart-interaction-smoke"
