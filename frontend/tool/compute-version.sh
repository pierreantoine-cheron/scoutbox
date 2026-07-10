#!/bin/bash
set -euo pipefail

if [ -z "${APP_FLAVOR:-}" ] || { [ "$APP_FLAVOR" != "production" ] && [ "$APP_FLAVOR" != "staging" ]; }; then
  echo "ERROR: APP_FLAVOR must be 'production' or 'staging', got: '${APP_FLAVOR:-}'" >&2
  exit 1
fi

if [ -z "${VERSION_NAME:-}" ]; then
  echo "ERROR: VERSION_NAME is required" >&2
  exit 1
fi

if [ -z "${VERSION_CODE:-}" ]; then
  echo "ERROR: VERSION_CODE is required" >&2
  exit 1
fi

FLAVOR="$APP_FLAVOR"
BASE_VERSION="$VERSION_NAME"
COMMIT_COUNT="$VERSION_CODE"

if [ "$APP_FLAVOR" = "staging" ]; then
  VERSION_NAME="${BASE_VERSION}-staging"
else
  VERSION_NAME="$BASE_VERSION"
fi
VERSION_CODE="$COMMIT_COUNT"

export FLAVOR
export VERSION_NAME
export VERSION_CODE

{
  echo "--- compute-version ---"
  echo "APP_FLAVOR  = $APP_FLAVOR"
  echo "FLAVOR      = $FLAVOR"
  echo "VERSION_NAME= $VERSION_NAME"
  echo "VERSION_CODE= $VERSION_CODE"
  echo "-----------------------"
} >&2
