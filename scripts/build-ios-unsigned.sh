#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
generate_project

xcodebuild -project MarkdownTextTool.xcodeproj -scheme MarkdownTextTool-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData-iOS-device" \
  -archivePath "$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive" \
  CODE_SIGNING_ALLOWED=NO archive

APP_PATH="$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive/Products/Applications/MarkdownTextTool.app"
if [[ ! -d "$APP_PATH" ]]; then
  echo "App not found at $APP_PATH" >&2
  exit 1
fi

IPA_STAGE="$(mktemp -d "$BUILD_DIR/unsigned-ipa-stage.XXXXXX")"
trap 'rm -rf "$IPA_STAGE"' EXIT
mkdir -p "$IPA_STAGE/Payload"
ditto "$APP_PATH" "$IPA_STAGE/Payload/MarkdownTextTool.app"
xattr -cr "$IPA_STAGE/Payload/MarkdownTextTool.app"
(
  cd "$IPA_STAGE"
  ditto -c -k --norsrc --keepParent Payload "$BUILD_DIR/MarkdownTextTool-iOS-iPadOS-unsigned.ipa"
)

ditto -c -k --sequesterRsrc --keepParent \
  "$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive" \
  "$BUILD_DIR/MarkdownTextTool-iOS-unsigned.xcarchive.zip"
echo 'Unsigned iOS/iPadOS IPA and archive created for build verification. The IPA is not installable on physical devices without Apple signing.'
