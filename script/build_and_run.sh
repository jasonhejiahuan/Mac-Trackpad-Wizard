#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="TrackpadWizard"
DISPLAY_NAME="Trackpad Wizard"
BUNDLE_ID="com.jasonstu.trackpadwizard"
MIN_SYSTEM_VERSION="26.0"
MARKETING_VERSION="${MARKETING_VERSION:-0.1.0}"
BUILD_NUMBER="${BUILD_NUMBER:-1}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$DISPLAY_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT_BIN="${DEVELOPER_DIR:+$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/}swift"
if [[ ! -x "$SWIFT_BIN" ]]; then
  SWIFT_BIN="$(command -v swift)"
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

"$SWIFT_BIN" build --package-path "$ROOT_DIR"
BUILD_BIN_PATH="$("$SWIFT_BIN" build --package-path "$ROOT_DIR" --show-bin-path)"
BUILD_BINARY="$BUILD_BIN_PATH/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleDisplayName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundleName</key>
  <string>$DISPLAY_NAME</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$MARKETING_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

if [[ -f "$ROOT_DIR/Assets/TrackpadWizard.icns" ]]; then
  cp "$ROOT_DIR/Assets/TrackpadWizard.icns" "$APP_RESOURCES/TrackpadWizard.icns"
  /usr/libexec/PlistBuddy -c "Add :CFBundleIconFile string TrackpadWizard" "$INFO_PLIST"
fi

SIGNING_IDENTITY="${SIGNING_IDENTITY:-$(security find-identity -v -p codesigning 2>/dev/null | sed -n 's/.*"\(Apple Development:.*\)"/\1/p' | head -1)}"
if [[ -n "$SIGNING_IDENTITY" ]]; then
  codesign --force --options runtime --timestamp=none --sign "$SIGNING_IDENTITY" --identifier "$BUNDLE_ID" "$APP_BUNDLE"
else
  codesign --force --options runtime --timestamp=none --sign - --identifier "$BUNDLE_ID" "$APP_BUNDLE"
fi
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

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
