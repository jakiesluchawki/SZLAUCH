#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$PROJECT_DIR/.build-dmg"
TOOLS_DIR="$PROJECT_DIR/.build-tools"
DIST_DIR="$PROJECT_DIR/dist"
APP_PATH="$PROJECT_DIR/Szlauch.app"
VOLUME_NAME="Szlauch"
SIGN_IDENTITY="${SZLAUCH_SIGN_IDENTITY:--}"
NOTARY_PROFILE="${SZLAUCH_NOTARY_PROFILE:-}"
SIGN_KEYCHAIN="${SZLAUCH_SIGN_KEYCHAIN:-}"

export SZLAUCH_SIGN_IDENTITY="$SIGN_IDENTITY"
"$PROJECT_DIR/scripts/build-macos-app.sh"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
FINAL_DMG="$DIST_DIR/Szlauch-$APP_VERSION.dmg"
BACKGROUND_PATH="$BUILD_DIR/background.png"
BACKGROUND_DIR="$BUILD_DIR/.background"
LAYOUT_DMG="$BUILD_DIR/Szlauch-layout.dmg"
DMGBUILD_VENV="$TOOLS_DIR/dmgbuild"
MOUNT_POINT="$BUILD_DIR/mounted"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$TOOLS_DIR" "$DIST_DIR"
rm -f "$FINAL_DMG"

xcrun swiftc "$PROJECT_DIR/macos/DMGBackgroundGenerator.swift" \
  -o "$BUILD_DIR/dmg-background" \
  -framework AppKit -framework CoreText
"$BUILD_DIR/dmg-background" "$BACKGROUND_PATH" "$APP_PATH/Contents/Resources/Fonts"
mkdir -p "$BACKGROUND_DIR"
ditto "$BACKGROUND_PATH" "$BACKGROUND_DIR/background.png"

if [[ ! -x "$DMGBUILD_VENV/bin/dmgbuild" ]]; then
  python3 -m venv "$DMGBUILD_VENV"
  "$DMGBUILD_VENV/bin/pip" -q install "dmgbuild==1.6.5"
fi

"$DMGBUILD_VENV/bin/dmgbuild" \
  -s "$PROJECT_DIR/macos/DMGSettings.py" \
  -D app_path="$APP_PATH" \
  -D background_dir="$BACKGROUND_DIR" \
  -D icon_path="$APP_PATH/Contents/Resources/AppIcon.icns" \
  "$VOLUME_NAME" \
  "$LAYOUT_DMG"

MOUNTED=0
cleanup_layout_volume() {
  if [[ "$MOUNTED" == "1" ]]; then
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    MOUNTED=0
  fi
}
trap cleanup_layout_volume EXIT

mkdir -p "$MOUNT_POINT"
hdiutil attach -nobrowse -readwrite -mountpoint "$MOUNT_POINT" "$LAYOUT_DMG" >/dev/null
MOUNTED=1

# Store the native bookmark while the image is mounted on its own filesystem.
xcrun swift -e '
import Foundation
let url = URL(fileURLWithPath: CommandLine.arguments[1])
try url.bookmarkData().write(to: URL(fileURLWithPath: CommandLine.arguments[2]))
' "$MOUNT_POINT/.background/background.png" "$BUILD_DIR/background.bookmark"

"$DMGBUILD_VENV/bin/python" - "$MOUNT_POINT" "$BUILD_DIR/background.bookmark" <<'PY'
from pathlib import Path
import sys
from ds_store import DSStore, DSStoreEntry
from mac_alias import Alias

root = Path(sys.argv[1])
with DSStore.open(str(root / ".DS_Store"), "r+") as store:
    view = store["."]["icvp"]
    view["backgroundType"] = 2
    view["backgroundImageAlias"] = Alias.for_file(str(root / ".background/background.png")).to_bytes()
    store["."]["icvp"] = view
    store.insert(DSStoreEntry(".", b"pBBk", b"blob", Path(sys.argv[2]).read_bytes()))
PY

sync
cleanup_layout_volume
trap - EXIT

hdiutil convert "$LAYOUT_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null

hdiutil verify "$FINAL_DMG" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  SIGN_ARGS=(--force --timestamp --sign "$SIGN_IDENTITY")
  if [[ -n "$SIGN_KEYCHAIN" ]]; then SIGN_ARGS+=(--keychain "$SIGN_KEYCHAIN"); fi
  codesign "${SIGN_ARGS[@]}" "$FINAL_DMG"
  if [[ -n "$NOTARY_PROFILE" ]]; then
    NOTARY_ARGS=(--keychain-profile "$NOTARY_PROFILE")
    if [[ -n "$SIGN_KEYCHAIN" ]]; then NOTARY_ARGS+=(--keychain "$SIGN_KEYCHAIN"); fi
    xcrun notarytool submit "$FINAL_DMG" "${NOTARY_ARGS[@]}" --wait
    xcrun stapler staple "$FINAL_DMG"
    xcrun stapler validate "$FINAL_DMG"
  else
    echo "DMG podpisany, ale bez notarization: ustaw SZLAUCH_NOTARY_PROFILE i zbuduj ponownie." >&2
  fi
else
  echo "DMG działa lokalnie, ale nie jest podpisany/notarized. Do bezproblemowej wysyłki potrzebny jest Developer ID Application." >&2
fi

echo "$FINAL_DMG"
