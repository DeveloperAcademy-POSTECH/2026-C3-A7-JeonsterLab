#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-transfer-smoke.XXXXXX)
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc 'JeonstarLab Mac/Connectivity/MacReceivedFileStore.swift' Tests/TransferStorageSmokeTests.swift -o "$test_output_dir/transfer-test"
"$test_output_dir/transfer-test"
