#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
OUTPUT_DIR="$ROOT_DIR/dist/release"
SIGNING_IDENTITY="${RELEASE_SIGNING_IDENTITY:-}"
NOTARY_PROFILE=""
MODE=""
TEAM_ID="WBU2AFY549"

usage() {
  cat <<'USAGE'
usage: release_local.sh (--package-only | --notary-profile <profile>) [options]

Options:
  --package-only                 Build and sign the app and DMG without notarizing.
  --notary-profile <profile>     Submit with a notarytool Keychain profile, then staple.
  --signing-identity <identity>  Override the Developer ID Application identity.
  --output-dir <directory>       Write the DMG and checksum here.

Package-only output is deliberately not described as release-ready.
USAGE
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --package-only)
      MODE="package-only"
      shift
      ;;
    --notary-profile)
      MODE="notarize"
      NOTARY_PROFILE="${2:?missing value for --notary-profile}"
      shift 2
      ;;
    --signing-identity)
      SIGNING_IDENTITY="${2:?missing value for --signing-identity}"
      shift 2
      ;;
    --output-dir)
      OUTPUT_DIR="${2:?missing value for --output-dir}"
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

[[ -n "$MODE" ]] || { usage >&2; exit 2; }

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

XCODEBUILD_BIN="${DEVELOPER_DIR:+$DEVELOPER_DIR/usr/bin/}xcodebuild"
if [[ ! -x "$XCODEBUILD_BIN" ]]; then
  XCODEBUILD_BIN="$(xcrun --find xcodebuild)"
fi

if [[ -z "$SIGNING_IDENTITY" ]]; then
  SIGNING_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null \
    | grep '"Developer ID Application:.*(WBU2AFY549)"' \
    | head -1 \
    | sed -E 's/.*"([^"]+)".*/\1/')"
fi
[[ -n "$SIGNING_IDENTITY" ]] || { echo "Developer ID Application identity for team $TEAM_ID was not found" >&2; exit 1; }

"$ROOT_DIR/script/release_metadata.sh" check
VERSION="$($ROOT_DIR/script/release_metadata.sh version)"
BUILD_NUMBER="$($ROOT_DIR/script/release_metadata.sh build)"
DMG_NAME="$($ROOT_DIR/script/release_metadata.sh dmg-name)"

ARCHIVE_DIR="$ROOT_DIR/.build/ReleaseArchives"
ARCHIVE_PATH="$ARCHIVE_DIR/TrackpadWizard-${VERSION}-${BUILD_NUMBER}.xcarchive"
mkdir -p "$ARCHIVE_DIR" "$OUTPUT_DIR"
/bin/rm -rf "$ARCHIVE_PATH"

"$XCODEBUILD_BIN" \
  -project "$ROOT_DIR/TrackpadWizard.xcodeproj" \
  -scheme TrackpadWizard \
  -configuration Release \
  -destination 'generic/platform=macOS' \
  -archivePath "$ARCHIVE_PATH" \
  CODE_SIGN_STYLE=Manual \
  CODE_SIGN_IDENTITY="$SIGNING_IDENTITY" \
  DEVELOPMENT_TEAM="$TEAM_ID" \
  ARCHS='arm64 x86_64' \
  ONLY_ACTIVE_ARCH=NO \
  archive

APP_PATH="$ARCHIVE_PATH/Products/Applications/Trackpad Wizard.app"
[[ -d "$APP_PATH" ]] || { echo "archive did not contain Trackpad Wizard.app" >&2; exit 1; }

codesign --verify --deep --strict --verbose=2 "$APP_PATH"
APP_SIGNATURE="$(codesign -dv --verbose=4 "$APP_PATH" 2>&1)"
grep -q '^Authority=Developer ID Application:' <<<"$APP_SIGNATURE" || { echo "archive is not Developer ID signed" >&2; exit 1; }
grep -q "^TeamIdentifier=$TEAM_ID$" <<<"$APP_SIGNATURE" || { echo "archive uses the wrong development team" >&2; exit 1; }

DMG_PATH="$("$ROOT_DIR/script/create_dmg.sh" \
  --app "$APP_PATH" \
  --output-dir "$OUTPUT_DIR" \
  --signing-identity "$SIGNING_IDENTITY" \
  | tail -1)"
[[ -f "$DMG_PATH" ]] || { echo "DMG creation did not return a valid artifact path" >&2; exit 1; }

if [[ "$MODE" == "notarize" ]]; then
  xcrun notarytool submit \
    "$DMG_PATH" \
    --keychain-profile "$NOTARY_PROFILE" \
    --wait \
    --timeout 30m
  xcrun stapler staple "$DMG_PATH"
  xcrun stapler validate "$DMG_PATH"
  spctl --assess --verbose=2 --type open --context context:primary-signature "$DMG_PATH"
  echo "Notarized and stapled: $DMG_PATH"
else
  echo "Package-only artifact (signed, NOT notarized): $DMG_PATH"
fi

(
  cd "$OUTPUT_DIR"
  shasum -a 256 "$DMG_NAME" > "$DMG_NAME.sha256"
)

echo "Checksum: $OUTPUT_DIR/$DMG_NAME.sha256"
