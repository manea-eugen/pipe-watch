#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="PipeWatch"
CONFIG="${1:-Debug}"
DIST_DIR="$PROJECT_DIR/dist"

echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> Building ($CONFIG)..."
xcodebuild \
  -project PipeWatch.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  build 2>&1 | grep -E '(error:|warning:(?!.*appintentsmetadataprocessor)|BUILD)' || true

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/PipeWatch-*/Build/Products/"$CONFIG" -name "PipeWatch.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "==> Build failed."
  exit 1
fi

echo "==> Build succeeded: $APP_PATH"

if [ "$2" = "--run" ]; then
  echo "==> Launching..."
  pkill -f "PipeWatch" 2>/dev/null || true
  sleep 1
  open "$APP_PATH"
fi

if [ "$2" = "--dist" ]; then
  rm -rf "$DIST_DIR"
  mkdir -p "$DIST_DIR"
  cp -R "$APP_PATH" "$DIST_DIR/"
  xattr -cr "$DIST_DIR/PipeWatch.app"
  VERSION=$(/usr/libexec/PlistBuddy -c "Print CFBundleShortVersionString" "$DIST_DIR/PipeWatch.app/Contents/Info.plist")
  cd "$DIST_DIR"
  zip -qr "PipeWatch-${VERSION}-macos.zip" PipeWatch.app
  rm -rf PipeWatch.app
  echo "==> Distribution archive: $DIST_DIR/PipeWatch-${VERSION}-macos.zip"
fi
