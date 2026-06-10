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
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-vpn
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-sleep
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-rate-format
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-network
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-hotspot-history
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-personal-hotspot
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-wifi-selection
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-navigation
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-weather
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-runtime
"$APP_PATH/Contents/MacOS/Szlauch" --self-test-theme

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
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-vpn
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-sleep
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-rate-format
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-network
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-hotspot-history
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-personal-hotspot
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-wifi-selection
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-navigation
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-weather
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-runtime
"$MOUNT_POINT/Szlauch.app/Contents/MacOS/Szlauch" --self-test-theme

echo "Release test: OK ($APP_VERSION, universal app, DMG layout, VPN, sleep, aggregate network, Wi-Fi selection, personal hotspot, navigation, weather details, hotspot history, palettes, read-only preview and rate units)"
