#!/bin/bash
# Builds a signed, notarized, stapled DMG from dist/AWSProfileManager.app.
# Prereqs: Tools/build_app.sh (and ideally Tools/notarize.sh) have run, and the
# notary keychain profile exists. Usage: Tools/make_dmg.sh
# Env overrides: CODESIGN_IDENTITY, NOTARY_PROFILE
set -euo pipefail

APP_NAME="AWSProfileManager"
VOL_NAME="AWS Profile Manager"
IDENTITY="${CODESIGN_IDENTITY:-Developer ID Application: Yaicel Torres (QUH3S7GQ36)}"
PROFILE="${NOTARY_PROFILE:-AWSPM-Notary}"

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/$APP_NAME.app"
DMG="$ROOT/dist/$APP_NAME.dmg"
STAGE="$ROOT/dist/dmg-stage"

[ -d "$APP" ] || { echo "App not found. Run Tools/build_app.sh first."; exit 1; }

echo "==> Staging DMG contents…"
rm -rf "$STAGE" "$DMG"
mkdir -p "$STAGE"
cp -R "$APP" "$STAGE/$APP_NAME.app"
ln -s /Applications "$STAGE/Applications"

echo "==> Creating compressed DMG…"
hdiutil create -volname "$VOL_NAME" -srcfolder "$STAGE" -ov -format UDZO "$DMG" >/dev/null
rm -rf "$STAGE"

echo "==> Signing DMG ($IDENTITY)…"
codesign --force --timestamp --sign "$IDENTITY" "$DMG"

echo "==> Notarizing DMG (keychain profile: $PROFILE)…"
xcrun notarytool submit "$DMG" --keychain-profile "$PROFILE" --wait

echo "==> Stapling the ticket to the DMG…"
xcrun stapler staple "$DMG"

echo "==> Verifying…"
spctl -a -vvv -t open --context context:primary-signature "$DMG" 2>&1 || true
echo "==> Done: $DMG"
