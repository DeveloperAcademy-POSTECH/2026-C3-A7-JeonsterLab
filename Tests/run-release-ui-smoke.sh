#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-smoke.XXXXXX)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc \
  'JeonstarLab Mac/Models/MotionCSVSample.swift' \
  'JeonstarLab Mac/Models/ChartTimeSelection.swift' \
  'JeonstarLab Mac/Models/ManualSnapDraft.swift' \
  'JeonstarLab Mac/Models/DatasetExportOptions.swift' \
  'JeonstarLab Mac/Services/MotionCSVParser.swift' \
  'JeonstarLab Mac/Services/SnapSelectionAnalyzer.swift' \
  'JeonstarLab Core/Models/SnapDetectionMode.swift' \
  Tests/ReleaseUISmokeTests.swift \
  -o "$test_output_dir/release-ui-smoke"
"$test_output_dir/release-ui-smoke"
