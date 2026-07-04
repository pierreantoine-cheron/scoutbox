#!/bin/bash
set -euo pipefail

if [ -z "${APP_FLAVOR:-}" ] || { [ "$APP_FLAVOR" != "production" ] && [ "$APP_FLAVOR" != "staging" ]; }; then
  echo "ERROR: APP_FLAVOR must be 'production' or 'staging', got: '${APP_FLAVOR:-}'" >&2
  exit 1
fi

FLAVOR="$APP_FLAVOR"

BASE_VERSION="${OVERRIDE_VERSION_NAME:-}"
if [ -z "$BASE_VERSION" ]; then
  BASE_VERSION=$(git describe --tags --abbrev=0 2>/dev/null | sed 's/^v//' || true)
fi
if [ -z "$BASE_VERSION" ]; then
  BASE_VERSION=$(grep '^version:' pubspec.yaml | head -1 | sed 's/version: //' | cut -d+ -f1 | tr -d '[:space:]')
fi
if [ -z "$BASE_VERSION" ]; then
  echo "ERROR: Could not determine base version. Set OVERRIDE_VERSION_NAME or tag a release." >&2
  exit 1
fi

COMMIT_COUNT="${OVERRIDE_VERSION_CODE:-}"
if [ -z "$COMMIT_COUNT" ]; then
  COMMIT_COUNT=$(git rev-list --count HEAD 2>/dev/null || echo "1")
fi
if [ -z "$COMMIT_COUNT" ]; then
  COMMIT_COUNT=1
fi

SHORT_SHA=$(git rev-parse --short HEAD 2>/dev/null || echo "")

if [ "$APP_FLAVOR" = "staging" ]; then
  VERSION_NAME="${BASE_VERSION}-staging"
else
  VERSION_NAME="$BASE_VERSION"
fi
VERSION_CODE="$COMMIT_COUNT"
COMMIT="$SHORT_SHA"

export FLAVOR
export VERSION_NAME
export VERSION_CODE
export COMMIT
export SHORT_SHA

{
  echo "--- compute-version ---"
  echo "APP_FLAVOR  = $APP_FLAVOR"
  echo "FLAVOR      = $FLAVOR"
  echo "VERSION_NAME= $VERSION_NAME"
  echo "VERSION_CODE= $VERSION_CODE"
  echo "COMMIT      = $COMMIT"
  echo "-----------------------"
} >&2
