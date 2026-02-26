#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 </path/to/ImageAnnotationTool.app> [output.dmg]" >&2
  exit 1
fi

APP_PATH="$1"
OUTPUT_DMG="${2:-}"

if [[ ! -d "${APP_PATH}" ]]; then
  echo "App bundle not found: ${APP_PATH}" >&2
  exit 1
fi

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
DIST_DIR="${REPO_ROOT}/dist/dmg"
mkdir -p "${DIST_DIR}"

APP_NAME="$(basename "${APP_PATH}" .app)"
STAMP="$(date +%Y%m%d-%H%M%S)"
DMG_PATH="${OUTPUT_DMG:-${DIST_DIR}/${APP_NAME}-${STAMP}.dmg}"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/dmg-staging.XXXXXX")"
trap 'rm -rf "${STAGING_DIR}"' EXIT

cp -R "${APP_PATH}" "${STAGING_DIR}/"
ln -s /Applications "${STAGING_DIR}/Applications"

echo "Creating DMG:"
echo "  ${DMG_PATH}"
hdiutil create -volname "${APP_NAME}" -srcfolder "${STAGING_DIR}" -ov -format UDZO "${DMG_PATH}"

echo "DMG created:"
echo "  ${DMG_PATH}"

