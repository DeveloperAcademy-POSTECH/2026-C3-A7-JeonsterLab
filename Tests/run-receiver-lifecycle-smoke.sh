#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
test_output_dir=$(mktemp -d /private/tmp/watchmotion-receiver-smoke.XXXXXX)
trap 'rm -rf "$test_output_dir"' EXIT
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
xcrun swiftc 'JeonstarLab Mac/Models/MacReceiverStatus.swift' \
  'JeonstarLab Mac/Connectivity/MacReceivedFileStore.swift' \
  'JeonstarLab Mac/Connectivity/MacPeerReceiver.swift' \
  Tests/ReceiverLifecycleSmokeTests.swift -o "$test_output_dir/receiver-test"
"$test_output_dir/receiver-test"
