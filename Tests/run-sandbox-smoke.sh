#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
test_build_dir=$(mktemp -d /private/tmp/watchmotion-sandbox-build.XXXXXX)
xcodebuild -project JeonstarLab.xcodeproj -scheme 'JeonstarLab Mac' \
  -configuration Debug -destination 'platform=macOS' -derivedDataPath "$test_build_dir" \
  CODE_SIGNING_ALLOWED=NO build
test_app="$test_build_dir/Build/Products/Debug/WatchMotion Editor.app"
codesign --force --sign - --entitlements 'JeonstarLab Mac/JeonstarLab_Mac.entitlements' "$test_app"
"$test_app/Contents/MacOS/WatchMotion Editor" --sandbox-smoke
