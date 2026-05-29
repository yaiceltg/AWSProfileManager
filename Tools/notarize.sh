#!/bin/bash
# Notarizes and staples dist/AWSProfileManager.app.
#
# One-time setup (creates an app-specific password at appleid.apple.com first):
#   xcrun notarytool store-credentials "AWSPM-Notary" \
#     --apple-id "<your-apple-id-email>" \
#     --team-id QUH3S7GQ36 \
#     --password "<app-specific-password>"
#
# Then: Tools/build_app.sh && Tools/notarize.sh
# Env override: NOTARY_PROFILE (defaults to AWSPM-Notary)
set -euo pipefail

APP_NAME="AWSProfileManager"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
APP="$ROOT/dist/$APP_NAME.app"
ZIP="$ROOT/dist/$APP_NAME.zip"
PROFILE="${NOTARY_PROFILE:-AWSPM-Notary}"

[ -d "$APP" ] || { echo "App not found. Run Tools/build_app.sh first."; exit 1; }

echo "==> Zipping for submission…"
rm -f "$ZIP"
ditto -c -k --keepParent "$APP" "$ZIP"

echo "==> Submitting to notarization (keychain profile: $PROFILE)…"
xcrun notarytool submit "$ZIP" --keychain-profile "$PROFILE" --wait

echo "==> Stapling the ticket to the app…"
xcrun stapler staple "$APP"

echo "==> Verifying with Gatekeeper…"
spctl -a -vvv -t exec "$APP"

echo "==> Notarized and stapled: $APP"
