#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ICONSET_DIR="${REPO_ROOT}/ImageAnnotationTool/Assets.xcassets/AppIcon.appiconset"
FALLBACK_SWIFT="${SCRIPT_DIR}/generate_fallback_icon.swift"

if [[ ! -d "${ICONSET_DIR}" ]]; then
  echo "Missing iconset directory: ${ICONSET_DIR}" >&2
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

BASE_1024="${TMP_DIR}/icon-base-1024.png"

if [[ $# -ge 1 && -n "${1:-}" ]]; then
  INPUT_ICON="$1"
  if [[ ! -f "${INPUT_ICON}" ]]; then
    echo "Input icon not found: ${INPUT_ICON}" >&2
    exit 1
  fi
  cp "${INPUT_ICON}" "${BASE_1024}"
  # Force to a square 1024x1024 source (best if input is already square).
  sips -z 1024 1024 "${BASE_1024}" --out "${BASE_1024}" >/dev/null
  echo "Using custom base icon: ${INPUT_ICON}"
else
  swift -module-cache-path "${TMP_DIR}/ModuleCache.noindex" "${FALLBACK_SWIFT}" "${BASE_1024}"
  echo "Generated fallback 1024x1024 icon base."
fi

gen_size() {
  local pixels="$1"
  local out="$2"
  sips -z "${pixels}" "${pixels}" "${BASE_1024}" --out "${ICONSET_DIR}/${out}" >/dev/null
}

gen_size 16 icon_16x16.png
gen_size 32 icon_16x16@2x.png
gen_size 32 icon_32x32.png
gen_size 64 icon_32x32@2x.png
gen_size 128 icon_128x128.png
gen_size 256 icon_128x128@2x.png
gen_size 256 icon_256x256.png
gen_size 512 icon_256x256@2x.png
gen_size 512 icon_512x512.png
gen_size 1024 icon_512x512@2x.png

cat > "${ICONSET_DIR}/Contents.json" <<'JSON'
{
  "images" : [
    { "filename" : "icon_16x16.png", "idiom" : "mac", "scale" : "1x", "size" : "16x16" },
    { "filename" : "icon_16x16@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "16x16" },
    { "filename" : "icon_32x32.png", "idiom" : "mac", "scale" : "1x", "size" : "32x32" },
    { "filename" : "icon_32x32@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "32x32" },
    { "filename" : "icon_128x128.png", "idiom" : "mac", "scale" : "1x", "size" : "128x128" },
    { "filename" : "icon_128x128@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "128x128" },
    { "filename" : "icon_256x256.png", "idiom" : "mac", "scale" : "1x", "size" : "256x256" },
    { "filename" : "icon_256x256@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "256x256" },
    { "filename" : "icon_512x512.png", "idiom" : "mac", "scale" : "1x", "size" : "512x512" },
    { "filename" : "icon_512x512@2x.png", "idiom" : "mac", "scale" : "2x", "size" : "512x512" }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

echo "Wrote icon set to ${ICONSET_DIR}"
ls -1 "${ICONSET_DIR}" | sed 's/^/  - /'
