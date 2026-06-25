#!/bin/sh
set -e

# 1. Parse version from pubspec.yaml
VERSION_LINE=$(grep '^version:' pubspec.yaml | head -1 | tr -d '\r')
VERSION_NAME=$(echo "$VERSION_LINE" | sed 's/version: //' | cut -d+ -f1)
BUILD_NUMBER=$(echo "$VERSION_LINE" | sed 's/version: //' | cut -d+ -f2)
SCOUTBOX_VERSION="${VERSION_NAME} (${BUILD_NUMBER})"

# 2. Find APK file
APK_DIR="build/app/outputs/apk/release"
APK_FILE=$(ls "$APK_DIR"/scoutbox-*-release.apk 2>/dev/null | head -1) || true
if [ -z "$APK_FILE" ]; then
  APK_FILE=$(ls "$APK_DIR"/*.apk 2>/dev/null | head -1) || true
fi
APK_FILENAME=$(basename "$APK_FILE")

# 3. Compute APK size (French format: comma decimal, binary Mo)
APK_BYTES=$(stat -c%s "$APK_FILE")
APK_SIZE=$(awk -v bytes="$APK_BYTES" 'BEGIN { printf "%.1f", bytes / 1048576 }' | sed 's/\./,/')
case "$APK_SIZE" in
  ,*) APK_SIZE="0${APK_SIZE}" ;;
esac
APK_SIZE="${APK_SIZE} Mo"

# 4. Extract minSdkVersion from APK
SDK_VERSION=""
if [ -d "$ANDROID_HOME/build-tools" ]; then
  for bt_dir in "$ANDROID_HOME/build-tools"/*/; do
    if [ -x "${bt_dir}aapt" ]; then
      SDK_VERSION=$("${bt_dir}aapt" dump badging "$APK_FILE" 2>/dev/null | grep "sdkVersion:" | sed "s/.*sdkVersion:'\([0-9]*\)'.*/\1/") || true
      break
    fi
  done
fi

if [ -z "$SDK_VERSION" ]; then
  SDK_VERSION=21
fi

# Map API level to Android version
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

# 5. Inject into HTML template
mkdir -p /tmp/apk-download

sed \
  -e "s|{{SCOUTBOX_VERSION}}|${SCOUTBOX_VERSION}|g" \
  -e "s|{{APK_SIZE}}|${APK_SIZE}|g" \
  -e "s|{{MIN_ANDROID}}|${MIN_ANDROID}|g" \
  -e "s|{{APK_FILENAME}}|${APK_FILENAME}|g" \
  apk-release/index.html > /tmp/apk-download/index.html

echo "Injected metadata into HTML:"
echo "  Version: $SCOUTBOX_VERSION"
echo "  APK: $APK_FILENAME"
echo "  Size: $APK_SIZE"
echo "  Min Android: $MIN_ANDROID"
