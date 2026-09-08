#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-phone-smoke.XXXXXX)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc \
  'JeonstarLab Core/Models/MotionSample.swift' \
  'JeonstarLab Core/Models/RecordingSession.swift' \
  'JeonstarLab Core/Models/SnapDetectionMode.swift' \
  'JeonstarLab Core/Protocols/RecordingRepositoryProtocol.swift' \
  JeonstarLab/Models/MotionPreviewKind.swift \
  JeonstarLab/ViewModels/RecordingDetailViewModel.swift \
  JeonstarLab/UseCases/AnalyzeSnapUseCase.swift \
  JeonstarLab/Export/RecordingCSVExporter.swift \
  JeonstarLab/Export/RecordingMetadataExporter.swift \
  JeonstarLab/Export/SnapAnalysisJSONExporter.swift \
  JeonstarLab/Export/RecordingExportService.swift \
  Tests/PhoneUISmokeTests.swift \
  -o "$test_output_dir/phone-ui-smoke"
"$test_output_dir/phone-ui-smoke"
