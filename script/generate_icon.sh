#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ASSET_DIR="$ROOT_DIR/Assets"
ICON_SOURCE="$ASSET_DIR/TrackpadWizard.icon"
SOURCE_PNG="$ASSET_DIR/TrackpadWizard-1024.png"
ICONSET_DIR="$ASSET_DIR/TrackpadWizard.iconset"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

mkdir -p "$ASSET_DIR" "$ICONSET_DIR"
ICTOOL="$DEVELOPER_DIR/../Applications/Icon Composer.app/Contents/Executables/ictool"
if [[ ! -x "$ICTOOL" ]]; then
  ICTOOL="/Applications/Icon Composer.app/Contents/Executables/ictool"
fi
if [[ ! -x "$ICTOOL" ]]; then
  echo "Icon Composer's export tool was not found." >&2
  exit 1
fi
ICON_TEMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trackpadwizard-icon.XXXXXX")"
RENDERED_PNG="$ICON_TEMP_DIR/TrackpadWizard-1024.png"
trap '/bin/rm -rf "$ICON_TEMP_DIR"' EXIT

if ! "$ICTOOL" "$ICON_SOURCE" \
  --export-image \
  --output-file "$RENDERED_PNG" \
  --platform macOS \
  --rendition Default \
  --width 1024 \
  --height 1024 \
  --scale 1 \
  --design-generation 27 >/dev/null; then
  /bin/rm -f "$RENDERED_PNG"
  "$ICTOOL" "$ICON_SOURCE" \
    --export-image \
    --output-file "$RENDERED_PNG" \
    --platform macOS \
    --rendition Default \
    --width 1024 \
    --height 1024 \
    --scale 1 \
    --design-generation 26 >/dev/null
fi

/bin/cp "$RENDERED_PNG" "$SOURCE_PNG"

for size in 16 32 128 256 512; do
  /usr/bin/sips -z "$size" "$size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}.png" >/dev/null
  double_size=$((size * 2))
  /usr/bin/sips -z "$double_size" "$double_size" "$SOURCE_PNG" --out "$ICONSET_DIR/icon_${size}x${size}@2x.png" >/dev/null
done

/usr/bin/iconutil -c icns "$ICONSET_DIR" -o "$ASSET_DIR/TrackpadWizard.icns"
echo "Rendered $ICON_SOURCE and generated $ASSET_DIR/TrackpadWizard.icns"
