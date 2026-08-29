#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode-beta.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
elif [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi

SWIFT_BIN="${DEVELOPER_DIR:+$DEVELOPER_DIR/Toolchains/XcodeDefault.xctoolchain/usr/bin/}swift"
if [[ ! -x "$SWIFT_BIN" ]]; then
  SWIFT_BIN="$(command -v swift)"
fi

XCODEBUILD_BIN="${DEVELOPER_DIR:+$DEVELOPER_DIR/usr/bin/}xcodebuild"
if [[ ! -x "$XCODEBUILD_BIN" ]]; then
  XCODEBUILD_BIN="$(xcrun --find xcodebuild)"
fi

AVAILABLE_SIGNING_IDENTITIES="$(security find-identity -v -p codesigning 2>/dev/null)"
if ! grep -q '"Apple Development:' <<<"$AVAILABLE_SIGNING_IDENTITIES"; then
  echo "An Apple Development signing identity is required for verification." >&2
  exit 1
fi

DERIVED_DATA="$ROOT_DIR/.build/XcodeDerivedData"
PROJECT="$ROOT_DIR/TrackpadWizard.xcodeproj"
DESTINATION="platform=macOS,arch=$(uname -m)"

"$SWIFT_BIN" test --package-path "$ROOT_DIR"
"$SWIFT_BIN" build --package-path "$ROOT_DIR" -c release

"$XCODEBUILD_BIN" \
  -project "$PROJECT" \
  -scheme TrackpadWizard \
  -configuration Debug \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  test

"$XCODEBUILD_BIN" \
  -project "$PROJECT" \
  -scheme TrackpadWizard \
  -configuration Release \
  -destination "$DESTINATION" \
  -derivedDataPath "$DERIVED_DATA" \
  build

APP_BUNDLE="$DERIVED_DATA/Build/Products/Release/Trackpad Wizard.app"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"
SIGNATURE_DETAILS="$(codesign -dv --verbose=4 "$APP_BUNDLE" 2>&1)"
if ! grep -q '^Authority=Apple Development:' <<<"$SIGNATURE_DETAILS"; then
  echo "Release verification build was not signed with Apple Development." >&2
  exit 1
fi
if ! grep -q '^TeamIdentifier=WBU2AFY549$' <<<"$SIGNATURE_DETAILS"; then
  echo "Release verification build was not signed for the configured development team." >&2
  exit 1
fi
