#!/bin/bash
set -o pipefail

# Ensure we're running from the project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT" || exit 1

# Build the Debug configuration
xcodebuild \
  -workspace alt-tab-macos.xcworkspace \
  -scheme Debug \
  -configuration Debug \
  -destination 'platform=macOS,arch=arm64' \
  build \
  2>&1 | scripts/xcbeautify | grep -v "deployment target 'MACOSX_DEPLOYMENT_TARGET'" | grep -v "Run script build phase 'Run Script' will be run during every build"

BUILD_EXIT_CODE=$?

# If build succeeded, kill existing AltTab and launch the new one
if [ $BUILD_EXIT_CODE -eq 0 ]; then
  killall AltTab 2>/dev/null || true
  
  # Find the most recent build and launch it
  APP_PATH=$(ls -td ~/Library/Developer/Xcode/DerivedData/alt-tab-macos-*/Build/Products/Debug/AltTab.app/Contents/MacOS/AltTab 2>/dev/null | head -1)
  
  if [ -n "$APP_PATH" ]; then
    "$APP_PATH" --logs=debug --disable-modules=SystemPermissions &
  fi
fi
