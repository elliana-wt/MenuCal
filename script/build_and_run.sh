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
APP_MACOS="$APP_CONTENTS/MacOS"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$ROOT_DIR/Packaging/Info.plist"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
for _ in {1..20}; do
  if ! pgrep -x "$APP_NAME" >/dev/null; then
    break
  fi
  sleep 0.1
done
pkill -9 -x "$APP_NAME" >/dev/null 2>&1 || true

SWIFT_BUILD_ARGS=(--arch arm64 --configuration "$CONFIGURATION")
swift build "${SWIFT_BUILD_ARGS[@]}"
BUILD_BINARY="$(swift build "${SWIFT_BUILD_ARGS[@]}" --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$INFO_PLIST" "$APP_CONTENTS/Info.plist"
chmod +x "$APP_BINARY"

/usr/bin/xattr -cr "$APP_BUNDLE"
codesign --force --sign - --timestamp=none "$APP_BUNDLE"

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
