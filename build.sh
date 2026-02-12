#!/bin/bash
set -e

PROJECT_DIR="$(cd "$(dirname "$0")" && pwd)"
SCHEME="PipelineNotifications"
CONFIG="${1:-Debug}"

echo "==> Generating Xcode project..."
cd "$PROJECT_DIR"
xcodegen generate

echo "==> Building ($CONFIG)..."
xcodebuild \
  -project PipelineNotifications.xcodeproj \
  -scheme "$SCHEME" \
  -configuration "$CONFIG" \
  build 2>&1 | grep -E '(error:|warning:(?!.*appintentsmetadataprocessor)|BUILD)' || true

APP_PATH=$(find ~/Library/Developer/Xcode/DerivedData/PipelineNotifications-*/Build/Products/"$CONFIG" -name "Pipeline Notifications.app" -maxdepth 1 2>/dev/null | head -1)

if [ -z "$APP_PATH" ]; then
  echo "==> Build failed."
  exit 1
fi

echo "==> Build succeeded: $APP_PATH"

if [ "$2" = "--run" ]; then
  echo "==> Launching..."
  pkill -f "Pipeline Notifications" 2>/dev/null || true
  sleep 1
  open "$APP_PATH"
fi
