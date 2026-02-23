#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$(mktemp -d /tmp/iat-stage005.XXXXXX)"
BIN_PATH="$BUILD_DIR/stage005-validation"
SDK_PATH="$(xcrun --show-sdk-path --sdk macosx)"
MODULE_CACHE_DIR="$BUILD_DIR/ModuleCache"

cleanup() {
  rm -rf "$BUILD_DIR"
}
trap cleanup EXIT

xcrun swiftc \
  -sdk "$SDK_PATH" \
  -module-cache-path "$MODULE_CACHE_DIR" \
  "$REPO_ROOT/ImageAnnotationTool/Export/AnnotationDataStore.swift" \
  "$REPO_ROOT/Tests/Stage005/main.swift" \
  -o "$BIN_PATH"

"$BIN_PATH" "$REPO_ROOT"
