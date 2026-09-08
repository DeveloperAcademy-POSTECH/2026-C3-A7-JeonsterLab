#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
segment_test_dir=$(mktemp -d /private/tmp/watchmotion-segments.XXXXXX)
xcrun swiftc 'JeonstarLab Mac/Models/MotionCSVSample.swift' \
  'JeonstarLab Mac/Models/AutoSegmentReview.swift' \
  'JeonstarLab Mac/Services/AutoSegmentDetector.swift' Tests/AutoSegmentSmokeTests.swift \
  -o "$segment_test_dir/auto-segment-smoke"
"$segment_test_dir/auto-segment-smoke"
