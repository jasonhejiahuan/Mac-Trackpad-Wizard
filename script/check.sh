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

"$SWIFT_BIN" test --package-path "$ROOT_DIR"
"$SWIFT_BIN" build --package-path "$ROOT_DIR" -c release
