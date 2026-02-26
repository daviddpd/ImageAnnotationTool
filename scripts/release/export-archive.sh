#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <app-store|developer-id> <archive-path> [team-id]" >&2
  exit 1
fi

METHOD="$1"
ARCHIVE_PATH="$2"
TEAM_ID="${3:-}"

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECT_DIR="${REPO_ROOT}/ImageAnnotationTool.xcodeproj"
DIST_DIR="${REPO_ROOT}/dist/exports/${METHOD}"
mkdir -p "${DIST_DIR}"

case "${METHOD}" in
  app-store)
    EXPORT_PLIST_TEMPLATE="${PROJECT_DIR}/ExportOptions-AppStore.plist"
    ;;
  developer-id)
    EXPORT_PLIST_TEMPLATE="${PROJECT_DIR}/ExportOptions-DeveloperID.plist"
    ;;
  *)
    echo "Unknown export method: ${METHOD}" >&2
    exit 1
    ;;
esac

if [[ ! -f "${EXPORT_PLIST_TEMPLATE}" ]]; then
  echo "Missing export options plist: ${EXPORT_PLIST_TEMPLATE}" >&2
  exit 1
fi

TMP_PLIST="$(mktemp "${TMPDIR:-/tmp}/export-options.XXXXXX.plist")"
trap 'rm -f "${TMP_PLIST}"' EXIT
cp "${EXPORT_PLIST_TEMPLATE}" "${TMP_PLIST}"

if [[ -n "${TEAM_ID}" ]]; then
  /usr/libexec/PlistBuddy -c "Set :teamID ${TEAM_ID}" "${TMP_PLIST}"
fi

echo "Exporting archive (${METHOD}) from:"
echo "  ${ARCHIVE_PATH}"
echo "to:"
echo "  ${DIST_DIR}"

xcodebuild -exportArchive \
  -archivePath "${ARCHIVE_PATH}" \
  -exportOptionsPlist "${TMP_PLIST}" \
  -exportPath "${DIST_DIR}"

echo
echo "Export completed:"
ls -la "${DIST_DIR}"

