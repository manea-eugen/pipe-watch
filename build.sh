#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="PipeWatch"
CONFIG="${1:-Debug}"

echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> Building ($CONFIG)..."
xcodebuild \
  -project PipeWatch.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  -allowProvisioningUpdates \
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
