#!/bin/bash
set -euo pipefail
phone_archive="${1:?Pass the unsigned iOS xcarchive path}"
mac_archive="${2:?Pass the unsigned macOS xcarchive path}"
phone_app="$phone_archive/Products/Applications/WatchMotion Editor.app"
watch_app="$phone_app/Watch/WatchMotion Editor.app"
mac_app="$mac_archive/Products/Applications/WatchMotion Editor.app/Contents"
value() { /usr/libexec/PlistBuddy -c "Print :$2" "$1"; }
test "$(value "$phone_app/Info.plist" CFBundleIdentifier)" = com.Jeonster.WatchMotionEditor
test "$(value "$watch_app/Info.plist" CFBundleIdentifier)" = com.Jeonster.WatchMotionEditor.watchkitapp
test "$(value "$mac_app/Info.plist" CFBundleIdentifier)" = com.Jeonster.WatchMotionEditor.mac
test "$(value "$watch_app/Info.plist" WKCompanionAppBundleIdentifier)" = com.Jeonster.WatchMotionEditor
test "$(value "$phone_app/Info.plist" UIDeviceFamily:0)" = 1
if value "$phone_app/Info.plist" UIDeviceFamily:1 2>/dev/null; then
  echo 'FAIL: Unexpected native iPad device family'; exit 1
fi
if value "$watch_app/Info.plist" WKBackgroundModes 2>/dev/null; then
  echo 'FAIL: Unsupported Watch background session mode'; exit 1
fi
for app in "$phone_app" "$watch_app" "$mac_app"; do
  test "$(value "$app/Info.plist" CFBundleDisplayName)" = 'WatchMotion Editor'
  test "$(value "$app/Info.plist" CFBundleShortVersionString)" = 1.0
done
for manifest in "$phone_app/PrivacyInfo.xcprivacy" "$watch_app/PrivacyInfo.xcprivacy" "$mac_app/Resources/PrivacyInfo.xcprivacy"; do
  plutil -lint "$manifest"
  test "$(value "$manifest" NSPrivacyTracking)" = false
done
test -f "$mac_app/Resources/THIRD_PARTY_NOTICES.txt"
if rg -a -q SANDBOX_SMOKE_PASS "$mac_app/MacOS/WatchMotion Editor"; then
  echo 'FAIL: Debug-only sandbox fixture found in Release'; exit 1
fi
echo 'PASS: release identities, companion link, iPhone family, Watch modes, privacy manifests and bundled license'
echo 'Unsigned archives do not validate distribution profiles, entitlements, App Store Connect records or review acceptance.'
