#!/usr/bin/env bash
# Regenerate all iOS AppIcon sizes from assets/icon/app_icon_1024.png
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SRC="$ROOT_DIR/assets/icon/app_icon_1024.png"
DEST="$ROOT_DIR/ios/Runner/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  echo "Missing source icon: $SRC" >&2
  exit 1
fi

if ! command -v sips >/dev/null 2>&1; then
  echo "sips is required (macOS)." >&2
  exit 1
fi

resize() {
  sips -z "$1" "$1" "$SRC" --out "$DEST/$2" >/dev/null
}

resize 20  "Icon-App-20x20@1x.png"
resize 40  "Icon-App-20x20@2x.png"
resize 60  "Icon-App-20x20@3x.png"
resize 29  "Icon-App-29x29@1x.png"
resize 58  "Icon-App-29x29@2x.png"
resize 87  "Icon-App-29x29@3x.png"
resize 40  "Icon-App-40x40@1x.png"
resize 80  "Icon-App-40x40@2x.png"
resize 120 "Icon-App-40x40@3x.png"
resize 120 "Icon-App-60x60@2x.png"
resize 180 "Icon-App-60x60@3x.png"
resize 76  "Icon-App-76x76@1x.png"
resize 152 "Icon-App-76x76@2x.png"
resize 167 "Icon-App-83.5x83.5@2x.png"
cp "$SRC" "$DEST/Icon-App-1024x1024@1x.png"

echo "Updated iOS icons in $DEST"
