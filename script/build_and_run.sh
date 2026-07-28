#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="MenuCal"
BUNDLE_ID="com.elliana.MenuCal"
CONFIGURATION="${CONFIGURATION:-debug}"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
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
  XCODEBUILD=(
    env
    DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
    xcodebuild
  )
else
  XCODEBUILD=(xcodebuild)
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
for _ in {1..20}; do
  if ! pgrep -x "$APP_NAME" >/dev/null; then
    break
  fi
  sleep 0.1
done
pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true

"${XCODEBUILD[@]}" \
  -project "$XCODE_PROJECT" \
  -scheme "$APP_NAME" \
  -configuration "$XCODE_CONFIGURATION" \
  -destination "platform=macOS,arch=arm64" \
  -derivedDataPath "$XCODE_DERIVED_DIR" \
  CODE_SIGNING_ALLOWED=NO \
  build

rm -rf "$APP_BUNDLE"
mkdir -p "$DIST_DIR"
/usr/bin/ditto \
  "$XCODE_DERIVED_DIR/Build/Products/$XCODE_CONFIGURATION/$APP_NAME.app" \
  "$APP_BUNDLE"

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
