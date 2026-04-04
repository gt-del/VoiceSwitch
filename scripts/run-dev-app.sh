#!/bin/sh
set -eu

SCRIPT_DIR="$(CDPATH= cd -- "$(dirname "$0")" && pwd)"
REPO_DIR="$(CDPATH= cd -- "$SCRIPT_DIR/.." && pwd)"
APP_ROOT="$REPO_DIR/.dev-app"
APP_BUNDLE="$APP_ROOT/VoiceSwitch.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
INFO_PLIST_SOURCE="$SCRIPT_DIR/VoiceSwitch-Info.plist"
EXECUTABLE_NAME="VoiceSwitchApp"

swift build --product "$EXECUTABLE_NAME"

BIN_DIR="$(swift build --show-bin-path)"
EXECUTABLE_PATH="$BIN_DIR/$EXECUTABLE_NAME"

if [ ! -x "$EXECUTABLE_PATH" ]; then
  echo "error: built executable not found at $EXECUTABLE_PATH" >&2
  exit 1
fi

mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
cp "$INFO_PLIST_SOURCE" "$CONTENTS_DIR/Info.plist"
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$EXECUTABLE_NAME"
chmod +x "$MACOS_DIR/$EXECUTABLE_NAME"

if command -v codesign >/dev/null 2>&1; then
  codesign --force --deep --sign - "$APP_BUNDLE" >/dev/null 2>&1 || true
fi

pkill -x "$EXECUTABLE_NAME" >/dev/null 2>&1 || true
pkill -f "$APP_BUNDLE/Contents/MacOS/$EXECUTABLE_NAME" >/dev/null 2>&1 || true
pkill -f "$REPO_DIR/.build/.*/$EXECUTABLE_NAME" >/dev/null 2>&1 || true

open "$APP_BUNDLE"
