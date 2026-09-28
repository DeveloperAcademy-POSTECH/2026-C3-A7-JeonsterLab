#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
dataset_test_dir=$(mktemp -d /private/tmp/watchmotion-dataset-smoke.XXXXXX)
trap 'rm -rf "$dataset_test_dir"' EXIT
xcrun swiftc 'JeonstarLab Mac/Models/'*.swift \
 'JeonstarLab Mac/Services/ReceivedRecordingPackageLoader.swift' \
 'JeonstarLab Mac/Services/RecordingMetadataJSONParser.swift' \
 'JeonstarLab Mac/Services/SnapAnalysisJSONParser.swift' \
 'JeonstarLab Mac/Services/MotionCSVParser.swift' \
 'JeonstarLab Mac/Services/SnapSegmentExporter.swift' \
 'JeonstarLab Mac/Export/CreateMLActivityExporter.swift' \
 'JeonstarLab Mac/Export/CreateMLActivityExportReport.swift' \
 Tests/DatasetExportSmokeTests.swift -o "$dataset_test_dir/dataset-smoke"
"$dataset_test_dir/dataset-smoke"
