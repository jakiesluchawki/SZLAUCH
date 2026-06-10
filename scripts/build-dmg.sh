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

export SZLAUCH_SIGN_IDENTITY="$SIGN_IDENTITY"
"$PROJECT_DIR/scripts/build-macos-app.sh"

APP_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
FINAL_DMG="$DIST_DIR/Szlauch-$APP_VERSION.dmg"
BACKGROUND_PATH="$BUILD_DIR/background.png"
BACKGROUND_DIR="$BUILD_DIR/.background"
LAYOUT_DMG="$BUILD_DIR/Szlauch-layout.dmg"
DMGBUILD_VENV="$TOOLS_DIR/dmgbuild"
MOUNT_POINT="/Volumes/$VOLUME_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR" "$TOOLS_DIR" "$DIST_DIR"
rm -f "$FINAL_DMG"

xcrun swiftc "$PROJECT_DIR/macos/DMGBackgroundGenerator.swift" \
  -o "$BUILD_DIR/dmg-background" \
  -framework AppKit
"$BUILD_DIR/dmg-background" "$BACKGROUND_PATH"
mkdir -p "$BACKGROUND_DIR"
ditto "$BACKGROUND_PATH" "$BACKGROUND_DIR/background.png"

if [[ ! -x "$DMGBUILD_VENV/bin/dmgbuild" ]]; then
  python3 -m venv "$DMGBUILD_VENV"
  "$DMGBUILD_VENV/bin/pip" -q install "dmgbuild==1.6.5"
fi

osascript -e "tell application \"Finder\" to try to close container window of disk \"$VOLUME_NAME\" end try" 2>/dev/null || true
hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true

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
    osascript -e "tell application \"Finder\" to try to close container window of (POSIX file \"$MOUNT_POINT\" as alias) end try" 2>/dev/null || true
    hdiutil detach "$MOUNT_POINT" -quiet 2>/dev/null || true
    MOUNTED=0
  fi
}
trap cleanup_layout_volume EXIT

hdiutil attach -nobrowse -readwrite -mountpoint "$MOUNT_POINT" "$LAYOUT_DMG" >/dev/null
MOUNTED=1

# macOS Tahoe ignores the legacy background alias emitted by dmgbuild. Let Finder
# create its own native reference, then compress that configured writable image.
if [[ ! -d "$MOUNT_POINT" ]]; then
  echo "Obraz DMG nie został zamontowany w $MOUNT_POINT." >&2
  exit 1
fi

osascript <<APPLESCRIPT
tell application "Finder"
  set targetFolder to (POSIX file "$MOUNT_POINT" as alias)
  open targetFolder
  repeat 40 times
    if exists disk "$VOLUME_NAME" then exit repeat
    delay 0.25
  end repeat
  if not (exists disk "$VOLUME_NAME") then error "Finder nie zarejestrował woluminu $VOLUME_NAME."
  tell disk "$VOLUME_NAME"
    set w to container window
    set current view of w to icon view
    set toolbar visible of w to false
    set statusbar visible of w to false
    set bounds of w to {120, 120, 840, 645}
    set v to icon view options of w
    set icon size of v to 96
    set text size of v to 12
    set arrangement of v to not arranged
    set background picture of v to (POSIX file "$MOUNT_POINT/.background/background.png" as alias)
    set position of item "Szlauch.app" to {180, 263}
    set position of item "Applications" to {540, 263}
    update without registering applications
    delay 1
    close w
  end tell
end tell
APPLESCRIPT

sync
cleanup_layout_volume
trap - EXIT

hdiutil convert "$LAYOUT_DMG" -format UDZO -imagekey zlib-level=9 -o "$FINAL_DMG" >/dev/null

hdiutil verify "$FINAL_DMG" >/dev/null

if [[ "$SIGN_IDENTITY" != "-" ]]; then
  codesign --force --timestamp --sign "$SIGN_IDENTITY" "$FINAL_DMG"
  if [[ -n "$NOTARY_PROFILE" ]]; then
    xcrun notarytool submit "$FINAL_DMG" --keychain-profile "$NOTARY_PROFILE" --wait
    xcrun stapler staple "$FINAL_DMG"
    xcrun stapler validate "$FINAL_DMG"
  else
    echo "DMG podpisany, ale bez notarization: ustaw SZLAUCH_NOTARY_PROFILE i zbuduj ponownie." >&2
  fi
else
  echo "DMG działa lokalnie, ale nie jest podpisany/notarized. Do bezproblemowej wysyłki potrzebny jest Developer ID Application." >&2
fi

echo "$FINAL_DMG"
