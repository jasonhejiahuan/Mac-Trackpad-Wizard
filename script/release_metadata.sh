#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CHANGELOG="$ROOT_DIR/CHANGELOG.md"
PROJECT_FILE="$ROOT_DIR/TrackpadWizard.xcodeproj/project.pbxproj"

fail() {
  echo "release metadata error: $*" >&2
  exit 1
}

HEADER="$(awk '/^## Version / { print; exit }' "$CHANGELOG")"
if [[ ! "$HEADER" =~ ^##[[:space:]]Version[[:space:]]([0-9]+\.[0-9]+\.[0-9]+)[[:space:]]\(Build[[:space:]]([1-9][0-9]*)\)[[:space:]]-[[:space:]]([0-9]{4}-[0-9]{2}-[0-9]{2})$ ]]; then
  fail "the first release heading must be '## Version x.y.z (Build n) - YYYY-MM-DD'"
fi

VERSION="${BASH_REMATCH[1]}"
BUILD_NUMBER="${BASH_REMATCH[2]}"
RELEASE_DATE="${BASH_REMATCH[3]}"

PROJECT_VERSIONS="$(sed -nE 's/^[[:space:]]*MARKETING_VERSION = ([^;]+);/\1/p' "$PROJECT_FILE" | sort -u)"
PROJECT_BUILDS="$(sed -nE 's/^[[:space:]]*CURRENT_PROJECT_VERSION = ([^;]+);/\1/p' "$PROJECT_FILE" | sort -u)"

PROJECT_VERSION_COUNT="$(printf '%s\n' "$PROJECT_VERSIONS" | sed '/^$/d' | wc -l | tr -d ' ')"
PROJECT_BUILD_COUNT="$(printf '%s\n' "$PROJECT_BUILDS" | sed '/^$/d' | wc -l | tr -d ' ')"

[[ "$PROJECT_VERSION_COUNT" == "1" ]] || fail "Xcode must contain one shared MARKETING_VERSION"
[[ "$PROJECT_BUILD_COUNT" == "1" ]] || fail "Xcode must contain one shared CURRENT_PROJECT_VERSION"
[[ "$PROJECT_VERSIONS" == "$VERSION" ]] || fail "CHANGELOG version $VERSION does not match Xcode version $PROJECT_VERSIONS"
[[ "$PROJECT_BUILDS" == "$BUILD_NUMBER" ]] || fail "CHANGELOG build $BUILD_NUMBER does not match Xcode build $PROJECT_BUILDS"

TAG="v${VERSION}-build.${BUILD_NUMBER}"
DMG_NAME="Trackpad-Wizard-${VERSION}-build-${BUILD_NUMBER}.dmg"
RELEASE_TITLE="Trackpad Wizard ${VERSION} (Build ${BUILD_NUMBER})"

print_notes() {
  awk '
    /^## Version / {
      if (inside) exit
      inside = 1
      next
    }
    inside { print }
  ' "$CHANGELOG"
}

COMMAND="${1:-check}"
case "$COMMAND" in
  check)
    echo "Validated $RELEASE_TITLE from CHANGELOG and Xcode."
    ;;
  version)
    echo "$VERSION"
    ;;
  build)
    echo "$BUILD_NUMBER"
    ;;
  date)
    echo "$RELEASE_DATE"
    ;;
  tag)
    echo "$TAG"
    ;;
  dmg-name)
    echo "$DMG_NAME"
    ;;
  title)
    echo "$RELEASE_TITLE"
    ;;
  notes)
    print_notes
    ;;
  github-output)
    : "${GITHUB_OUTPUT:?GITHUB_OUTPUT is required for github-output}"
    {
      echo "version=$VERSION"
      echo "build=$BUILD_NUMBER"
      echo "date=$RELEASE_DATE"
      echo "tag=$TAG"
      echo "dmg_name=$DMG_NAME"
      echo "release_title=$RELEASE_TITLE"
    } >> "$GITHUB_OUTPUT"
    ;;
  *)
    echo "usage: $0 [check|version|build|date|tag|dmg-name|title|notes|github-output]" >&2
    exit 2
    ;;
esac
