#!/bin/bash
set -euo pipefail

if [ $# -lt 4 ]; then
  echo "Usage: build-apk-manifest.sh <apk-output-dir> <version-name> <version-code> <artifacts-out-dir>"
  exit 1
fi

APK_DIR="$1"
VERSION_NAME="$2"
VERSION_CODE="$3"
ARTIFACTS_DIR="$4"

echo "--- build-apk-manifest ---"
echo "APK_DIR: $APK_DIR"
echo "VERSION_NAME: $VERSION_NAME"
echo "VERSION_CODE: $VERSION_CODE"
echo "ARTIFACTS_DIR: $ARTIFACTS_DIR"
echo "ANDROID_HOME: ${ANDROID_HOME:-<not set>}"

APK_FILE=$(ls "$APK_DIR"/scoutbox-v*.apk 2>/dev/null | head -1) || true
if [ -z "$APK_FILE" ]; then
  APK_FILE=$(ls "$APK_DIR"/*.apk 2>/dev/null | head -1) || true
fi
if [ -z "$APK_FILE" ]; then
  echo "ERROR: No APK found in $APK_DIR"
  echo "Contents of $APK_DIR:"
  ls -la "$APK_DIR" 2>&1 || echo "(directory not found)"
  exit 1
fi
echo "APK_FILE: $APK_FILE"

APK_FILENAME=$(basename "$APK_FILE")

APK_BYTES=$(stat -c%s "$APK_FILE")
APK_SIZE=$(awk -v bytes="$APK_BYTES" 'BEGIN { printf "%.1f", bytes / 1048576 }' | sed 's/\./,/')
case "$APK_SIZE" in
  ,*) APK_SIZE="0${APK_SIZE}" ;;
esac
APK_SIZE="${APK_SIZE} Mo"
echo "APK_SIZE: $APK_SIZE"

SDK_VERSION=""
BUILD_TOOLS="${ANDROID_HOME:-}/build-tools"
echo "BUILD_TOOLS: $BUILD_TOOLS"
if [ -d "$BUILD_TOOLS" ]; then
  for bt_dir in "$BUILD_TOOLS"/*/; do
    echo "Checking: ${bt_dir}aapt"
    if [ -x "${bt_dir}aapt" ]; then
      SDK_VERSION=$("${bt_dir}aapt" dump badging "$APK_FILE" 2>/dev/null | grep "sdkVersion:" | sed "s/.*sdkVersion:'\([0-9]*\)'.*/\1/") || true
      echo "SDK_VERSION from aapt: $SDK_VERSION"
      break
    fi
  done
fi

if [ -z "$SDK_VERSION" ]; then
  echo "SDK_VERSION: using default 21"
  SDK_VERSION=21
fi

case "$SDK_VERSION" in
  19) ANDROID_VERSION="4.4" ;;
  20) ANDROID_VERSION="4.4W" ;;
  21) ANDROID_VERSION="5.0" ;;
  22) ANDROID_VERSION="5.1" ;;
  23) ANDROID_VERSION="6.0" ;;
  24) ANDROID_VERSION="7.0" ;;
  25) ANDROID_VERSION="7.1" ;;
  26) ANDROID_VERSION="8.0" ;;
  27) ANDROID_VERSION="8.1" ;;
  28) ANDROID_VERSION="9" ;;
  29) ANDROID_VERSION="10" ;;
  30) ANDROID_VERSION="11" ;;
  31) ANDROID_VERSION="12" ;;
  32) ANDROID_VERSION="12L" ;;
  33) ANDROID_VERSION="13" ;;
  34) ANDROID_VERSION="14" ;;
  35) ANDROID_VERSION="15" ;;
  36) ANDROID_VERSION="16" ;;
  *)  ANDROID_VERSION="$SDK_VERSION" ;;
esac
MIN_ANDROID="Android ${ANDROID_VERSION}+"

BASE_VERSION=$(echo "$VERSION_NAME" | sed 's/-staging$//')
FLAVOR=$(echo "$VERSION_NAME" | grep -q -- '-staging$' && echo "staging" || echo "production")

mkdir -p "$ARTIFACTS_DIR"

cat > "$ARTIFACTS_DIR/manifest.json" <<MANIFEST
{
  "version": "${BASE_VERSION}",
  "versionName": "${VERSION_NAME}",
  "build": ${VERSION_CODE},
  "flavor": "${FLAVOR}",
  "filename": "${APK_FILENAME}",
  "sizeBytes": ${APK_BYTES},
  "sizeLabel": "${APK_SIZE}",
  "minSdk": ${SDK_VERSION},
  "minAndroid": "${MIN_ANDROID}"
}
MANIFEST

cp "$APK_FILE" "$ARTIFACTS_DIR/"

echo "--- build-apk-manifest complete ---"
echo "Manifest written to: $ARTIFACTS_DIR/manifest.json"
echo "APK copied to: $ARTIFACTS_DIR/$APK_FILENAME"
cat "$ARTIFACTS_DIR/manifest.json"
