#!/bin/zsh
set -euo pipefail

PROJECT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP="${1:-$PROJECT_DIR/Szlauch.app}/Contents/MacOS/Szlauch"

for SUITE in fonts command-runner vpn sleep rate-format network hotspot-history personal-hotspot wifi-selection navigation weather runtime theme regression; do
  "$APP" "--self-test-$SUITE"
done

if [[ "${SZLAUCH_REQUIRE_BRAND_FONTS:-0}" == "1" ]]; then
  "$APP" --self-test-fonts --require-brand-fonts
fi
