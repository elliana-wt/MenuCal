#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MenuCal"
BUNDLE_ID="com.elliana.MenuCal"
CONFIGURATION="${CONFIGURATION:-debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="${MENUCAL_DIST_DIR:-$ROOT_DIR/dist}"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"
XCODE_DERIVED_DIR="$ROOT_DIR/.build/xcode"
XCODE_PROJECT="$ROOT_DIR/MenuCal.xcodeproj"

case "$CONFIGURATION" in
  debug|Debug)
    XCODE_CONFIGURATION="Debug"
    ;;
  release|Release)
    XCODE_CONFIGURATION="Release"
    ;;
  *)
    echo "error: CONFIGURATION must be debug or release" >&2
    exit 1
    ;;
esac

if [[ -x "/Applications/Xcode.app/Contents/Developer/usr/bin/xcodebuild" ]]; then
  MENUCAL_DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
  XCODEBUILD=(
    env
    DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    xcodebuild
  )
else
  MENUCAL_DEVELOPER_DIR="$(xcode-select -p)"
  XCODEBUILD=(xcodebuild)
fi

MENUCAL_SDK_PATH="${MENUCAL_SWIFT_SDK:-$(DEVELOPER_DIR="$MENUCAL_DEVELOPER_DIR" xcrun --sdk macosx --show-sdk-path)}"
MENUCAL_SDK_VERSION="$(/usr/libexec/PlistBuddy -c 'Print :Version' "$MENUCAL_SDK_PATH/SDKSettings.plist")"
if [[ "${MENUCAL_SDK_VERSION%%.*}" -lt 26 ]]; then
  echo "error: MenuCal's modern system UI requires building with macOS SDK 26 or newer" >&2
  exit 1
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
for _ in {1..20}; do
  if ! pgrep -x "$APP_NAME" >/dev/null; then
    break
  fi
  sleep 0.1
done
pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true

if "${XCODEBUILD[@]}" -version >/dev/null 2>&1; then
  "${XCODEBUILD[@]}" \
    -project "$XCODE_PROJECT" \
    -scheme "$APP_NAME" \
    -configuration "$XCODE_CONFIGURATION" \
    -destination "platform=macOS,arch=arm64" \
    -derivedDataPath "$XCODE_DERIVED_DIR" \
    SDKROOT="$MENUCAL_SDK_PATH" \
    CODE_SIGNING_ALLOWED=NO \
    build

  rm -rf "$APP_BUNDLE"
  mkdir -p "$DIST_DIR"
  /usr/bin/ditto \
    "$XCODE_DERIVED_DIR/Build/Products/$XCODE_CONFIGURATION/$APP_NAME.app" \
    "$APP_BUNDLE"
else
  echo "Xcode unavailable; building the app bundle with SwiftPM."
  SWIFT_CONFIGURATION="$(echo "$XCODE_CONFIGURATION" | tr '[:upper:]' '[:lower:]')"
  # The current Swift Build backend writes SDK 14.0 into LC_BUILD_VERSION for
  # this package, opting AppKit into legacy appearance despite the newer SDK.
  # Use the native driver and verify the final Mach-O SDK before packaging.
  SWIFT_BUILD_OPTIONS=(--build-system native --sdk "$MENUCAL_SDK_PATH" --package-path "$ROOT_DIR" --arch arm64 -c "$SWIFT_CONFIGURATION")
  swift build "${SWIFT_BUILD_OPTIONS[@]}" --product "$APP_NAME"
  SWIFT_BIN_DIR="$(swift build "${SWIFT_BUILD_OPTIONS[@]}" --show-bin-path)"
  rm -rf "$APP_BUNDLE"
  mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
  cp "$SWIFT_BIN_DIR/$APP_NAME" "$APP_BINARY"
  cp "$ROOT_DIR/Packaging/Info.plist" "$APP_CONTENTS/Info.plist"
  # Precompiled from menucal.icon for builds without Xcode's asset compiler.
  cp "$ROOT_DIR/Packaging/menucal.icns" "$APP_CONTENTS/Resources/menucal.icns"
fi

LINKED_SDK_VERSION="$(xcrun vtool -show-build "$APP_BINARY" | awk '$1 == "sdk" { print $2; exit }')"
if [[ "$LINKED_SDK_VERSION" != "$MENUCAL_SDK_VERSION" ]]; then
  echo "error: linked SDK $LINKED_SDK_VERSION does not match selected SDK $MENUCAL_SDK_VERSION; refusing a legacy-appearance build" >&2
  exit 1
fi
echo "Verified linked macOS SDK: $LINKED_SDK_VERSION"

if [[ -n "${APP_VERSION:-}" ]]; then
  if [[ ! "$APP_VERSION" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]]; then
    echo "error: APP_VERSION must be a numeric dotted version" >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleShortVersionString $APP_VERSION" \
    "$APP_CONTENTS/Info.plist"
fi

if [[ -n "${BUILD_NUMBER:-}" ]]; then
  if [[ ! "$BUILD_NUMBER" =~ ^[0-9]+$ ]]; then
    echo "error: BUILD_NUMBER must be numeric" >&2
    exit 1
  fi
  /usr/libexec/PlistBuddy \
    -c "Set :CFBundleVersion $BUILD_NUMBER" \
    "$APP_CONTENTS/Info.plist"
fi

/usr/bin/xattr -cr "$APP_BUNDLE"
# File Provider can immediately reattach FinderInfo to bundles in Documents.
# Keep the runnable development bundle outside that managed directory when so.
if /usr/bin/xattr -p com.apple.FinderInfo "$APP_BUNDLE" >/dev/null 2>&1; then
  LOCAL_BUNDLE_DIR="$(mktemp -d "${TMPDIR:-/tmp}/MenuCal-build.XXXXXX")"
  /usr/bin/ditto --norsrc --noextattr --noqtn "$APP_BUNDLE" "$LOCAL_BUNDLE_DIR/$APP_NAME.app"
  APP_BUNDLE="$LOCAL_BUNDLE_DIR/$APP_NAME.app"
  APP_CONTENTS="$APP_BUNDLE/Contents"
  APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"
  echo "File Provider metadata detected; using local development bundle: $APP_BUNDLE"
fi
codesign --force --deep --sign - --timestamp=none "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

if ! file "$APP_BINARY" | grep -q "arm64"; then
  echo "error: packaged binary is not arm64" >&2
  exit 1
fi

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --package|package)
    echo "$APP_BUNDLE"
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--package|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
