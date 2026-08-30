#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TrackpadWizard"
DISPLAY_NAME="Trackpad Wizard"
BUNDLE_ID="cc.jasonstu.trackpadwizard"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
PROJECT="$ROOT_DIR/TrackpadWizard.xcodeproj"
DERIVED_DATA="$ROOT_DIR/.build/XcodeRunDerivedData"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

XCODEBUILD_BIN="${DEVELOPER_DIR:+$DEVELOPER_DIR/usr/bin/}xcodebuild"
if [[ ! -x "$XCODEBUILD_BIN" ]]; then
  XCODEBUILD_BIN="$(xcrun --find xcodebuild)"
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

"$XCODEBUILD_BIN" \
  -quiet \
  -project "$PROJECT" \
  -scheme TrackpadWizard \
  -configuration Debug \
  -destination "platform=macOS,arch=$(uname -m)" \
  -derivedDataPath "$DERIVED_DATA" \
  build

BUILT_APP="$DERIVED_DATA/Build/Products/Debug/$DISPLAY_NAME.app"
if [[ ! -d "$BUILT_APP" ]]; then
  echo "Xcode did not produce $BUILT_APP" >&2
  exit 1
fi

mkdir -p "$DIST_DIR"
rm -rf "$APP_BUNDLE"
/usr/bin/ditto "$BUILT_APP" "$APP_BUNDLE"

codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1)"
if ! grep -q '^Authority=Apple Development:' <<<"$SIGNATURE_DETAILS"; then
  echo "The Xcode run build was not signed with Apple Development." >&2
  exit 1
fi
if ! grep -q '^TeamIdentifier=WBU2AFY549$' <<<"$SIGNATURE_DETAILS"; then
  echo "The Xcode run build was not signed for the configured development team." >&2
  exit 1
fi

APP_BINARY="$APP_BUNDLE/Contents/MacOS/$APP_NAME"

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    for _ in {1..20}; do
      if pgrep -x "$APP_NAME" >/dev/null; then
        exit 0
      fi
      sleep 0.1
    done
    echo "$DISPLAY_NAME did not stay running" >&2
    exit 1
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
