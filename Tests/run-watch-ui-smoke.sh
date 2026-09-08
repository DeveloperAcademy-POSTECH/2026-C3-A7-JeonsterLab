#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-watch-smoke.XXXXXX)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc \
  'JeonstarLab Core/Models/MotionSample.swift' \
  'JeonstarLab Core/Models/RecordingSession.swift' \
  'JeonstarLab Core/Protocols/MotionRecorderProtocol.swift' \
  'JeonstarLab Core/Protocols/RecordingStorageProtocol.swift' \
  'JeonstarLab Core/Protocols/RecordingTransferProtocol.swift' \
  'JeonstarLab Watch App/Storage/WatchRecordingStorage.swift' \
  'JeonstarLab Watch App/UseCases/StartRecordingUseCase.swift' \
  'JeonstarLab Watch App/UseCases/StopRecordingUseCase.swift' \
  'JeonstarLab Watch App/ViewModels/RecordingViewModel.swift' \
  Tests/WatchUISmokeTests.swift \
  -o "$test_output_dir/watch-ui-smoke"
"$test_output_dir/watch-ui-smoke"
