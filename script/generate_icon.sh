#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/Assets"
SOURCE_PNG="$ASSET_DIR/TrackpadWizard-1024.png"
ICONSET_DIR="$ASSET_DIR/TrackpadWizard.iconset"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p "$ASSET_DIR" "$ICONSET_DIR"
/usr/bin/xcrun swift "$ROOT_DIR/script/generate_icon.swift" "$SOURCE_PNG"

for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  /usr/bin/sips -z "$double_size" "$double_size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ASSET_DIR/TrackpadWizard.icns"
echo "Generated $ASSET_DIR/TrackpadWizard.icns"
