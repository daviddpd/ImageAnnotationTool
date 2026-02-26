#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <app-store|developer-id> [team-id] [bundle-id]" >&2
  exit 1
fi

METHOD="$1"
TEAM_ID="${2:-}"
BUNDLE_ID="${3:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT="${REPO_ROOT}/ImageAnnotationTool.xcodeproj"
SCHEME="ImageAnnotationTool"
DIST_DIR="${REPO_ROOT}/dist"
STAMP="$(date +%Y%m%d-%H%M%S)"
ARCHIVE_PATH="${DIST_DIR}/archives/${METHOD}/ImageAnnotationTool-${STAMP}.xcarchive"

mkdir -p "$(dirname "${ARCHIVE_PATH}")"

XCODE_ARGS=(
  -project "${PROJECT}"
  -scheme "${SCHEME}"
  -configuration Release
  -destination "generic/platform=macOS"
  -archivePath "${ARCHIVE_PATH}"
  clean archive
)

if [[ -n "${TEAM_ID}" ]]; then
  XCODE_ARGS+=(DEVELOPMENT_TEAM="${TEAM_ID}" CODE_SIGN_STYLE=Automatic)
fi
if [[ -n "${BUNDLE_ID}" ]]; then
  XCODE_ARGS+=(PRODUCT_BUNDLE_IDENTIFIER="${BUNDLE_ID}")
fi

echo "Archiving ${SCHEME} (${METHOD}) -> ${ARCHIVE_PATH}"
xcodebuild "${XCODE_ARGS[@]}"

echo
echo "Archive created:"
echo "  ${ARCHIVE_PATH}"

