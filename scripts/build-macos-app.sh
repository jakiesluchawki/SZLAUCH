#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
FINAL_APP_DIR="$PROJECT_DIR/Szlauch.app"
LEGACY_APP_DIR="$PROJECT_DIR/Pulse Bar.app"
BUILD_DIR="$PROJECT_DIR/.build"
APP_DIR="$BUILD_DIR/Szlauch.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICONSET_DIR="$BUILD_DIR/AppIcon.iconset"
BUILD_VERSION="$(date +%Y%m%d%H%M%S)"
APP_VERSION="${SZLAUCH_VERSION:-0.4.0}"
FONT_DIR="${SZLAUCH_FONT_DIR:-$PROJECT_DIR/.local/brand-fonts}"
DEPLOYMENT_TARGET="${MACOSX_DEPLOYMENT_TARGET:-13.0}"
SIGN_IDENTITY="${SZLAUCH_SIGN_IDENTITY:--}"
SIGN_KEYCHAIN="${SZLAUCH_SIGN_KEYCHAIN:-}"
OPTIMIZATION="${SZLAUCH_OPTIMIZATION:--O}"
case "$OPTIMIZATION" in -O|-Osize|-Onone) ;; *) exit 2 ;; esac

rm -rf "$BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR" "$ICONSET_DIR"

FRAMEWORKS=(
  -framework AppKit
  -framework Combine
  -framework CoreText
  -framework CoreLocation
  -framework CoreWLAN
  -framework MapKit
  -framework Network
  -framework ServiceManagement
  -framework SwiftUI
  -framework SystemConfiguration
)

for ARCH in arm64 x86_64; do
  xcrun swiftc "$OPTIMIZATION" \
    -target "$ARCH-apple-macos$DEPLOYMENT_TARGET" \
    "$PROJECT_DIR/macos/SzlauchApp.swift" \
    -o "$BUILD_DIR/Szlauch-$ARCH" \
    "${FRAMEWORKS[@]}"
done

lipo -create \
  "$BUILD_DIR/Szlauch-arm64" \
  "$BUILD_DIR/Szlauch-x86_64" \
  -output "$MACOS_DIR/Szlauch"

xcrun swiftc "$PROJECT_DIR/macos/IconGenerator.swift" \
  -o "$BUILD_DIR/icon-generator" \
  -framework AppKit

"$BUILD_DIR/icon-generator" "$BUILD_DIR/AppIcon.png"
sips -z 16 16 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$BUILD_DIR/AppIcon.png" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
cp "$BUILD_DIR/AppIcon.png" "$RESOURCES_DIR/AppIcon.png"
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# Licensed brand fonts are local build inputs, never public source assets.
if [[ -d "$FONT_DIR" ]]; then
  mkdir -p "$RESOURCES_DIR/Fonts"
  for FONT in Romie-Regular Roobert-Regular Roobert-Bold; do
    if [[ ! -f "$FONT_DIR/$FONT.otf" ]]; then
      print -u2 "Missing brand font: $FONT_DIR/$FONT.otf"
      exit 1
    fi
    cp "$FONT_DIR/$FONT.otf" "$RESOURCES_DIR/Fonts/"
  done
elif [[ "${SZLAUCH_REQUIRE_BRAND_FONTS:-0}" == "1" ]]; then
  print -u2 "Brand fonts are required. Set SZLAUCH_FONT_DIR."
  exit 1
else
  print -u2 "Brand fonts not supplied; using the native system fallback."
fi

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>pl</string>
  <key>CFBundleDisplayName</key>
  <string>Szlauch</string>
  <key>CFBundleExecutable</key>
  <string>Szlauch</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIdentifier</key>
  <string>app.szlauch.macos</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Szlauch</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_VERSION</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSLocationWhenInUseUsageDescription</key>
  <string>Szlauch używa lokalizacji do lokalnej pogody oraz wyświetlania nazw pobliskich sieci Wi-Fi.</string>
  <key>NSLocationUsageDescription</key>
  <string>Szlauch używa lokalizacji do lokalnej pogody oraz wyświetlania nazw pobliskich sieci Wi-Fi.</string>
  <key>NSSystemAdministrationUsageDescription</key>
  <string>Szlauch potrzebuje jednorazowej zgody administratora tylko do przełączania systemowej blokady uśpienia.</string>
</dict>
</plist>
PLIST

printf 'APPL????' > "$CONTENTS_DIR/PkgInfo"
if [[ "$SIGN_IDENTITY" == "-" ]]; then
  codesign --force --deep --options runtime --sign - "$APP_DIR" >/dev/null
else
  SIGN_ARGS=(--force --deep --options runtime --timestamp --sign "$SIGN_IDENTITY")
  if [[ -n "$SIGN_KEYCHAIN" ]]; then SIGN_ARGS+=(--keychain "$SIGN_KEYCHAIN"); fi
  codesign "${SIGN_ARGS[@]}" "$APP_DIR" >/dev/null
fi

rm -rf "$FINAL_APP_DIR" "$LEGACY_APP_DIR"
mv "$APP_DIR" "$FINAL_APP_DIR"

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
if [[ -x "$LSREGISTER" ]]; then
  "$LSREGISTER" -f "$FINAL_APP_DIR" >/dev/null 2>&1 || true
fi

echo "$FINAL_APP_DIR"
