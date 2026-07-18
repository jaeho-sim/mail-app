#!/bin/bash
#
# Builds MailApp for macOS, archives it, exports a Developer ID–signed .app,
# submits it to Apple for notarization, staples the ticket, and packages the
# result into a DMG ready to upload.
#
# One-time setup before running this:
#   1. In Xcode: Signing & Capabilities → select your paid Developer team.
#   2. Get a "Developer ID Application" certificate (Xcode does this
#      automatically once your team is selected and you archive once).
#   3. Edit scripts/exportOptions-mac.plist and replace REPLACE_WITH_YOUR_TEAM_ID
#      with your Team ID (Apple Developer → Membership).
#   4. Store notarization credentials once, so this script never needs your
#      Apple ID password in plain text:
#        xcrun notarytool store-credentials "AC_NOTARY" \
#          --apple-id "your-apple-id@example.com" \
#          --team-id "REPLACE_WITH_YOUR_TEAM_ID" \
#          --password "an app-specific password from appleid.apple.com"
#
# Usage: ./scripts/build_and_notarize_mac.sh [version]
#   Pass the version to name the DMG (e.g. 1.0) — should match
#   MARKETING_VERSION in Xcode. Defaults to "1.0" if omitted.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
XCODEPROJ="$PROJECT_ROOT/MailApp/MailApp.xcodeproj"
SCHEME="MailApp"
NOTARY_PROFILE="AC_NOTARY"

BUILD_DIR="$PROJECT_ROOT/build"
ARCHIVE_PATH="$BUILD_DIR/MailApp-mac.xcarchive"
EXPORT_PATH="$BUILD_DIR/export-mac"
APP_NAME="MailApp.app"
VERSION="${1:-1.0}"
DMG_NAME="MailApp-${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

echo "==> Archiving ($SCHEME, macOS)…"
xcodebuild archive \
  -project "$XCODEPROJ" \
  -scheme "$SCHEME" \
  -destination "generic/platform=macOS" \
  -archivePath "$ARCHIVE_PATH" \
  -configuration Release

echo "==> Exporting Developer ID–signed app…"
xcodebuild -exportArchive \
  -archivePath "$ARCHIVE_PATH" \
  -exportPath "$EXPORT_PATH" \
  -exportOptionsPlist "$SCRIPT_DIR/exportOptions-mac.plist"

APP_PATH="$EXPORT_PATH/$APP_NAME"
if [ ! -d "$APP_PATH" ]; then
  echo "Export failed — expected app at $APP_PATH" >&2
  exit 1
fi

echo "==> Zipping for notarization…"
ZIP_PATH="$BUILD_DIR/MailApp-notarize.zip"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

echo "==> Submitting to Apple notary service (this can take a few minutes)…"
xcrun notarytool submit "$ZIP_PATH" --keychain-profile "$NOTARY_PROFILE" --wait

echo "==> Stapling notarization ticket…"
xcrun stapler staple "$APP_PATH"

echo "==> Packaging DMG…"
hdiutil create -volname "MailApp" -srcfolder "$APP_PATH" -ov -format UDZO "$DMG_PATH"

echo ""
echo "Done. Notarized, stapled DMG at:"
echo "  $DMG_PATH"
echo ""
echo "Next: python3 scripts/upload_release_to_firebase.py \"$DMG_PATH\""
