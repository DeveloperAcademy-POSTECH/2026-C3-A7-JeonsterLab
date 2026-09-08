#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-inbox-smoke.XXXXXX)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc JeonstarLab/Receive/PendingRecordingInbox.swift JeonstarLab/Storage/RecordingFileStore.swift Tests/PhoneInboxSmokeTests.swift -o "$test_output_dir/inbox-test"
"$test_output_dir/inbox-test"
