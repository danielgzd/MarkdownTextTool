#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
generate_project

xcodebuild -project MarkdownTextTool.xcodeproj -scheme MarkdownTextTool-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData-iOS-device" \
  -archivePath "$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive" \
  CODE_SIGNING_ALLOWED=NO archive
ditto -c -k --sequesterRsrc --keepParent \
  "$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive" \
  "$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive.zip"
echo 'Unsigned archive created for build verification; it is not an installable IPA.'
