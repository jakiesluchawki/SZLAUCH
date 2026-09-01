#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_PATH="$PROJECT_DIR/Szlauch.app"
APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
DMG_PATH="${1:-$PROJECT_DIR/dist/Szlauch-$APP_VERSION.dmg}"
MOUNT_POINT="/tmp/SzlauchReleaseTest.$$"

test -d "$APP_PATH"
test -f "$DMG_PATH"

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
lipo "$APP_PATH/Contents/MacOS/Szlauch" -verify_arch arm64 x86_64
zsh "$PROJECT_DIR/scripts/test-self.sh" "$APP_PATH"

mkdir -p "$MOUNT_POINT"
cleanup() {
  hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
  rmdir "$MOUNT_POINT" 2>/dev/null || true
}
trap cleanup EXIT

hdiutil verify "$DMG_PATH" >/dev/null
hdiutil attach -readonly -nobrowse -mountpoint "$MOUNT_POINT" "$DMG_PATH" >/dev/null

test -d "$MOUNT_POINT/Szlauch.app"
test -L "$MOUNT_POINT/Applications"
test -f "$MOUNT_POINT/.background/background.png"
codesign --verify --deep --strict --verbose=2 "$MOUNT_POINT/Szlauch.app"
lipo "$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" -verify_arch arm64 x86_64
MOUNTED_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$MOUNT_POINT/Szlauch.app/Contents/Info.plist")"
[[ "$MOUNTED_VERSION" == "$APP_VERSION" ]]
cmp "$APP_PATH/Contents/MacOS/Szlauch" "$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch"
test -f "$MOUNT_POINT/.DS_Store"
zsh "$PROJECT_DIR/scripts/test-self.sh" "$MOUNT_POINT/Szlauch.app"

if [[ "${SZLAUCH_REQUIRE_NOTARIZATION:-0}" == "1" ]]; then
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --type execute --verbose=4 "$MOUNT_POINT/Szlauch.app"
  spctl --assess --type open --context context:primary-signature --verbose=4 "$DMG_PATH"
fi

echo "Release test: OK ($APP_VERSION, universal app, DMG layout, VPN, sleep, aggregate network, Wi-Fi selection, personal hotspot, navigation, weather details, hotspot history, palettes, read-only preview and rate units)"
