#!/bin/bash
set -euo pipefail

if [[ $# -lt 2 ]]; then
  echo "usage: $0 <git-tag> <artifact-path> [artifact-path...]" >&2
  echo "example: $0 v1.0.0 dist/dmg/ImageAnnotationTool-*.dmg" >&2
  exit 1
fi

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI 'gh' is required." >&2
  exit 1
fi

TAG="$1"
shift

if gh release view "${TAG}" >/dev/null 2>&1; then
  echo "Release ${TAG} exists; uploading assets..."
  gh release upload "${TAG}" "$@" --clobber
else
  echo "Creating release ${TAG} and uploading assets..."
  gh release create "${TAG}" "$@" --generate-notes
fi

echo "Done."

