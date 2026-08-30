#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH=""
OUTPUT_DIR="$ROOT_DIR/dist/release"
SIGNING_IDENTITY="${DMG_SIGNING_IDENTITY:-}"
BACKGROUND_1X="$ROOT_DIR/Assets/DMG/dmg-background.png"
BACKGROUND_2X="$ROOT_DIR/Assets/DMG/dmg-background@2x.png"

usage() {
  cat <<'USAGE'
usage: create_dmg.sh --app <signed.app> --signing-identity <Developer ID Application identity> [--output-dir <directory>]

Creates a versioned, compressed DMG with a Retina background, signs the DMG,
and prints its absolute path. The app version/build must match CHANGELOG.md.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --app)
      APP_PATH="${2:?missing value for --app}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?missing value for --output-dir}"
      shift 2
      ;;
    --signing-identity)
      SIGNING_IDENTITY="${2:?missing value for --signing-identity}"
      shift 2
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "unknown option: $1" >&2
      usage >&2
      exit 2
      ;;
  esac
done

[[ -d "$APP_PATH" ]] || { echo "app bundle not found: $APP_PATH" >&2; exit 1; }
[[ -n "$SIGNING_IDENTITY" ]] || { echo "a Developer ID Application signing identity is required" >&2; exit 1; }
[[ -f "$BACKGROUND_1X" && -f "$BACKGROUND_2X" ]] || { echo "DMG background assets are missing" >&2; exit 1; }

EXPECTED_VERSION="$($ROOT_DIR/script/release_metadata.sh version)"
EXPECTED_BUILD="$($ROOT_DIR/script/release_metadata.sh build)"
DMG_NAME="$($ROOT_DIR/script/release_metadata.sh dmg-name)"

INFO_PLIST="$APP_PATH/Contents/Info.plist"
[[ -f "$INFO_PLIST" ]] || { echo "app Info.plist not found" >&2; exit 1; }
APP_VERSION="$(plutil -extract CFBundleShortVersionString raw -o - "$INFO_PLIST")"
APP_BUILD="$(plutil -extract CFBundleVersion raw -o - "$INFO_PLIST")"
APP_DISPLAY_NAME="$(plutil -extract CFBundleDisplayName raw -o - "$INFO_PLIST")"

[[ "$APP_VERSION" == "$EXPECTED_VERSION" ]] || { echo "app version $APP_VERSION does not match CHANGELOG $EXPECTED_VERSION" >&2; exit 1; }
[[ "$APP_BUILD" == "$EXPECTED_BUILD" ]] || { echo "app build $APP_BUILD does not match CHANGELOG $EXPECTED_BUILD" >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
APP_SIGNATURE="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
grep -q '^Authority=Developer ID Application:' <<<"$APP_SIGNATURE" || { echo "app is not signed with Developer ID Application" >&2; exit 1; }

mkdir -p "$OUTPUT_DIR"
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
OUTPUT_PATH="$OUTPUT_DIR/$DMG_NAME"
[[ ! -e "$OUTPUT_PATH" ]] || { echo "refusing to overwrite existing artifact: $OUTPUT_PATH" >&2; exit 1; }

WORK_DIR="$(mktemp -d "${TMPDIR:-/tmp}/trackpadwizard-dmg-work.XXXXXX")"
MOUNT_DIR=""
RW_DMG="$WORK_DIR/TrackpadWizard-rw.dmg"
ATTACH_PLIST="$WORK_DIR/attach.plist"
MOUNTED=0

cleanup() {
  if [[ "$MOUNTED" == "1" ]]; then
    diskutil eject "$MOUNT_DIR" >/dev/null 2>&1 || true
  fi
  /bin/rm -rf "$WORK_DIR"
}
trap cleanup EXIT

VOLUME_NAME="$APP_DISPLAY_NAME $EXPECTED_VERSION"
IMAGE_SIZE_MB="$(du -sm "$APP_PATH" "$BACKGROUND_1X" "$BACKGROUND_2X" | awk '{ total += $1 } END { print total + 64 }')"

diskutil image create blank \
  --format RAW \
  --size "${IMAGE_SIZE_MB}m" \
  --volumeName "$VOLUME_NAME" \
  --fs APFS \
  "$RW_DMG" >/dev/null

diskutil image attach \
  --plist \
  "$RW_DMG" > "$ATTACH_PLIST"
MOUNT_DIR="$(plutil -p "$ATTACH_PLIST" | sed -n 's/.*"mount-point" => "\(.*\)"/\1/p' | tail -1)"
[[ -n "$MOUNT_DIR" && -d "$MOUNT_DIR" ]] || { echo "unable to determine the mounted volume path" >&2; exit 1; }
MOUNTED=1

mkdir -p "$MOUNT_DIR/.background"
/usr/bin/ditto "$APP_PATH" "$MOUNT_DIR/$APP_DISPLAY_NAME.app"
/bin/ln -s /Applications "$MOUNT_DIR/Applications"
/bin/cp "$BACKGROUND_1X" "$MOUNT_DIR/.background/dmg-background.png"
/bin/cp "$BACKGROUND_2X" "$MOUNT_DIR/.background/dmg-background@2x.png"

SETFILE_BIN="$(xcrun --find SetFile 2>/dev/null || true)"
if [[ -n "$SETFILE_BIN" ]]; then
  "$SETFILE_BIN" -a V "$MOUNT_DIR/.background"
fi

DMG_MOUNT_PATH="$MOUNT_DIR" DMG_APP_ITEM="$APP_DISPLAY_NAME.app" /usr/bin/osascript <<'APPLESCRIPT'
set mountPath to system attribute "DMG_MOUNT_PATH"
set appItemName to system attribute "DMG_APP_ITEM"

tell application "Finder"
  set dmgFolder to (POSIX file mountPath) as alias
  open dmgFolder
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set pathbar visible of container window of dmgFolder to false
  set bounds of container window of dmgFolder to {180, 180, 780, 580}
  set viewOptions to the icon view options of container window of dmgFolder
  set arrangement of viewOptions to not arranged
  set icon size of viewOptions to 128
  set text size of viewOptions to 12
  set background picture of viewOptions to (POSIX file (mountPath & "/.background/dmg-background.png") as alias)
  set position of item appItemName of dmgFolder to {170, 210}
  set position of item "Applications" of dmgFolder to {430, 210}
  update dmgFolder without registering applications
  delay 2
  close container window of dmgFolder
end tell
APPLESCRIPT

/bin/sync
diskutil eject "$MOUNT_DIR" >/dev/null
MOUNTED=0

diskutil image create from \
  --format UDZO \
  "$RW_DMG" \
  "$OUTPUT_PATH" >/dev/null

codesign --force --timestamp --sign "$SIGNING_IDENTITY" "$OUTPUT_PATH"
codesign --verify --verbose=2 "$OUTPUT_PATH"
hdiutil verify "$OUTPUT_PATH" >/dev/null

echo "$OUTPUT_PATH"
