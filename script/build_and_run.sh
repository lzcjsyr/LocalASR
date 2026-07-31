#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="LocalASR"
BUNDLE_ID="com.localasr.app"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
ENGINE_BINARY="$ROOT_DIR/vendor/whisper.cpp/build/bin/whisper-server"
ENGINE_DIR="$ROOT_DIR/vendor/whisper.cpp/build/bin"
ICON_FILE="$ROOT_DIR/Resources/AppIcon.icns"

export DEVELOPER_DIR="/Applications/Xcode.app/Contents/Developer"
export PATH="/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

pkill -x "$APP_NAME" >/dev/null 2>&1 || true

swift build -c debug
BUILD_BINARY="$(swift build -c debug --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES/bin"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"

if [[ -x "$ENGINE_BINARY" ]]; then
  cp "$ENGINE_BINARY" "$APP_RESOURCES/bin/whisper-server"
  cp -L "$ENGINE_DIR"/lib*.dylib "$APP_RESOURCES/bin/"
  install_name_tool -delete_rpath "$ENGINE_DIR" -add_rpath "@loader_path" "$APP_RESOURCES/bin/whisper-server"
  for library in "$APP_RESOURCES"/bin/*.dylib; do
    install_name_tool -delete_rpath "$ENGINE_DIR" -add_rpath "@loader_path" "$library" 2>/dev/null || true
  done
  chmod +x "$APP_RESOURCES/bin/whisper-server"
fi

if [[ -f "$ICON_FILE" ]]; then
  cp "$ICON_FILE" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>$APP_NAME</string>
  <key>CFBundleDisplayName</key>
  <string>本地 ASR</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
  <key>NSMicrophoneUsageDescription</key>
  <string>本地 ASR 需要使用麦克风进行离线语音转写。</string>
</dict>
</plist>
PLIST

if [[ -x "$APP_RESOURCES/bin/whisper-server" ]]; then
  for code in "$APP_RESOURCES"/bin/*.dylib "$APP_RESOURCES/bin/whisper-server"; do
    codesign --force --sign - "$code" >/dev/null
  done
fi
codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
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
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
