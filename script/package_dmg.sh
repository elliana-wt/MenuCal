#!/usr/bin/env bash
set -euo pipefail

# Package an already built and signed application without changing its contents.
APP_PATH="${1:?usage: package_dmg.sh /path/to/MenuCal.app /path/to/output.dmg}"
OUTPUT_PATH="${2:?output DMG path is required}"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP_PATH/Contents/Info.plist")"
codesign --verify --deep --strict "$APP_PATH"
STAGING_DIR="$(mktemp -d "${TMPDIR:-/tmp}/MenuCal-dmg-content.XXXXXX")"
/usr/bin/ditto --norsrc --noextattr --noqtn "$APP_PATH" "$STAGING_DIR/MenuCal.app"
ln -s /Applications "$STAGING_DIR/Applications"
codesign --verify --deep --strict "$STAGING_DIR/MenuCal.app"
mkdir -p "$(dirname "$OUTPUT_PATH")"
hdiutil create -volname "MenuCal $VERSION" -srcfolder "$STAGING_DIR" -format UDZO -ov "$OUTPUT_PATH"
hdiutil verify "$OUTPUT_PATH"
shasum -a 256 "$OUTPUT_PATH"
