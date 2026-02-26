#!/bin/bash
set -euo pipefail

if [[ $# -lt 1 ]]; then
  echo "usage: $0 <path/to/file.dmg>" >&2
  echo "  auth options:" >&2
  echo "    export NOTARYTOOL_PROFILE=<keychain-profile-name>" >&2
  echo "  or" >&2
  echo "    export APPLE_ID=<email> TEAM_ID=<teamid> APP_SPECIFIC_PASSWORD=<app-password>" >&2
  exit 1
fi

DMG_PATH="$1"
if [[ ! -f "${DMG_PATH}" ]]; then
  echo "DMG not found: ${DMG_PATH}" >&2
  exit 1
fi

SUBMIT_ARGS=(submit "${DMG_PATH}" --wait)
if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  SUBMIT_ARGS+=(--keychain-profile "${NOTARYTOOL_PROFILE}")
else
  : "${APPLE_ID:?APPLE_ID is required if NOTARYTOOL_PROFILE is not set}"
  : "${TEAM_ID:?TEAM_ID is required if NOTARYTOOL_PROFILE is not set}"
  : "${APP_SPECIFIC_PASSWORD:?APP_SPECIFIC_PASSWORD is required if NOTARYTOOL_PROFILE is not set}"
  SUBMIT_ARGS+=(--apple-id "${APPLE_ID}" --team-id "${TEAM_ID}" --password "${APP_SPECIFIC_PASSWORD}")
fi

echo "Submitting for notarization:"
echo "  ${DMG_PATH}"
xcrun notarytool "${SUBMIT_ARGS[@]}"

echo "Stapling notarization ticket..."
xcrun stapler staple "${DMG_PATH}"

echo "Notarized and stapled:"
echo "  ${DMG_PATH}"

