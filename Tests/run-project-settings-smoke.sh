#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-settings-smoke.XXXXXX)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc \
  'JeonstarLab Mac'/Models/*.swift \
  'JeonstarLab Mac/Services/ReceivedRecordingPackageLoader.swift' \
  'JeonstarLab Mac/Services/RecordingMetadataJSONParser.swift' \
  'JeonstarLab Mac/Services/SnapAnalysisJSONParser.swift' \
  'JeonstarLab Mac/Services/ReceiverProjectPackageService.swift' \
  Tests/ProjectSettingsSmokeTests.swift \
  -o "$test_output_dir/project-settings-smoke"
"$test_output_dir/project-settings-smoke"
