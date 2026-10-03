#!/usr/bin/env bash
# Builds RedmiBudsBar (universal), assembles an ad-hoc signed .app bundle and installs it to ~/Applications.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="RedmiBudsBar"
BUNDLE_ID="io.github.redmibudsbar.RedmiBudsBar"
VERSION="$(tr -d '[:space:]' < "$ROOT/VERSION")"
APP_DIR="$ROOT/build/$APP_NAME.app"
INSTALL_DIR="$HOME/Applications"

cd "$ROOT"
# Universal binary (Apple Silicon + Intel).
BUILD_FLAGS=(-c release --arch arm64 --arch x86_64)
swift build "${BUILD_FLAGS[@]}"
BIN_PATH="$(swift build "${BUILD_FLAGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS" "$APP_DIR/Contents/Resources"
cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"

# SwiftPM resource bundle (localized strings). Bundle.main resolves it from Contents/Resources.
RESOURCE_BUNDLE="$(dirname "$BIN_PATH")/${APP_NAME}_${APP_NAME}.bundle"
if [ ! -d "$RESOURCE_BUNDLE" ]; then
    echo "error: resource bundle not found at $RESOURCE_BUNDLE" >&2
    exit 1
fi
cp -R "$RESOURCE_BUNDLE" "$APP_DIR/Contents/Resources/"

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleDevelopmentRegion</key>
    <string>en</string>
    <key>CFBundleLocalizations</key>
    <array>
        <string>en</string>
        <string>es</string>
    </array>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>NSBluetoothAlwaysUsageDescription</key>
    <string>RedmiBudsBar uses Bluetooth to show battery status and change settings of your REDMI Buds.</string>
</dict>
</plist>
PLIST

# Ad-hoc signature (no developer account required).
codesign --force --deep -s - "$APP_DIR"

echo "Built $APP_DIR (version $VERSION)"

# Set SKIP_INSTALL=1 to build without copying to ~/Applications (used by package-release.sh).
if [ "${SKIP_INSTALL:-0}" != "1" ]; then
    mkdir -p "$INSTALL_DIR"
    rm -rf "$INSTALL_DIR/$APP_NAME.app"
    cp -R "$APP_DIR" "$INSTALL_DIR/$APP_NAME.app"
    echo "Installed $INSTALL_DIR/$APP_NAME.app"
fi
