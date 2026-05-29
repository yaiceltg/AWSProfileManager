#!/bin/bash
# Builds a signed AWSProfileManager.app from the SwiftPM executable.
# Usage: Tools/build_app.sh
# Env overrides: CODESIGN_IDENTITY, CONFIG (release|debug)
set -euo pipefail

APP_NAME="AWSProfileManager"
DISPLAY_NAME="AWS Profile Manager"
BUNDLE_ID="com.yaiceltg.AWSProfileManager"
VERSION="1.0.5"
BUILD_NUMBER="6"
MIN_OS="14.0"
CONFIG="${CONFIG:-release}"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Yaicel Torres (QUH3S7GQ36)}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT/.build/$CONFIG"
APP="$ROOT/dist/$APP_NAME.app"
RES_BUNDLE="${APP_NAME}_${APP_NAME}.bundle"

echo "==> Building ($CONFIG)…"
swift build -c "$CONFIG" --product "$APP_NAME"

echo "==> Assembling $APP_NAME.app…"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

cp "$BUILD_DIR/$APP_NAME" "$APP/Contents/MacOS/$APP_NAME"
cp "$ROOT/Sources/AWSProfileManager/Resources/AppIcon.icns" "$APP/Contents/Resources/AppIcon.icns"

# Copy the SPM resource bundle so Bundle.module resolves inside the .app.
if [ -d "$BUILD_DIR/$RES_BUNDLE" ]; then
  cp -R "$BUILD_DIR/$RES_BUNDLE" "$APP/Contents/Resources/$RES_BUNDLE"
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>$APP_NAME</string>
    <key>CFBundleDisplayName</key><string>$DISPLAY_NAME</string>
    <key>CFBundleIdentifier</key><string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key><string>$APP_NAME</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>$VERSION</string>
    <key>CFBundleVersion</key><string>$BUILD_NUMBER</string>
    <key>CFBundleInfoDictionaryVersion</key><string>6.0</string>
    <key>LSMinimumSystemVersion</key><string>$MIN_OS</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
    <key>NSHumanReadableCopyright</key><string>Yaicel Torres</string>
</dict>
</plist>
PLIST

echo "==> Signing with: $IDENTITY"
# The SPM resource bundle carries no code, so it is sealed as a resource when
# the app is signed (no separate signature needed). Sign the app with the
# hardened runtime (required for notarization).
codesign --force --timestamp --options runtime --sign "$IDENTITY" "$APP"

echo "==> Verifying signature…"
codesign --verify --strict --verbose=2 "$APP"

echo "==> Done: $APP"
echo "    Team: QUH3S7GQ36 — ready to notarize (see README)."
