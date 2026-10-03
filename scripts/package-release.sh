#!/usr/bin/env bash
# Builds the app and packages dist/RedmiBudsBar-<version>.zip for a GitHub Release.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="RedmiBudsBar"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
ZIP="$ROOT/dist/$APP_NAME-$VERSION.zip"

SKIP_INSTALL=1 "$ROOT/scripts/build-app.sh"

mkdir -p "$ROOT/dist"
rm -f "$ZIP"
ditto -c -k --keepParent "$ROOT/build/$APP_NAME.app" "$ZIP"
echo "Created $ZIP"
