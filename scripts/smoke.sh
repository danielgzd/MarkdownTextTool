#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
generate_project

# A small regression smoke suite for text/HTML handling, then both UI builds.
swift test --scratch-path "$BUILD_DIR/swift-package"
xcodebuild -project MarkdownTextTool.xcodeproj -scheme MarkdownTextTool-macOS \
  -configuration Debug -destination 'platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData-macOS" \
  CODE_SIGNING_ALLOWED=NO build
xcodebuild -project MarkdownTextTool.xcodeproj -scheme MarkdownTextTool-iOS \
  -configuration Debug -destination 'generic/platform=iOS Simulator' \
  -derivedDataPath "$BUILD_DIR/DerivedData-iOS" \
  CODE_SIGNING_ALLOWED=NO build
echo 'Smoke suite and macOS/iOS Simulator builds passed.'
