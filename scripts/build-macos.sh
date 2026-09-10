#!/bin/bash
set -euo pipefail
source "$(dirname "$0")/common.sh"
generate_project

xcodebuild -project MarkdownTextTool.xcodeproj -scheme MarkdownTextTool-macOS \
  -configuration Release -destination 'generic/platform=macOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData-macOS-release" \
  ARCHS='arm64 x86_64' ONLY_ACTIVE_ARCH=NO CODE_SIGNING_ALLOWED=NO build
APP_PATH="$BUILD_DIR/DerivedData-macOS-release/Build/Products/Release/MarkdownTextTool.app"
STAGING_DIR="$(mktemp -d "$BUILD_DIR/dmg-stage.XXXXXX")"
trap 'rm -rf "$STAGING_DIR"' EXIT
ditto "$APP_PATH" "$STAGING_DIR/MarkdownTextTool.app"
xattr -cr "$STAGING_DIR/MarkdownTextTool.app"
# Ad-hoc signing preserves sandbox entitlements and supports local execution on
# Apple Silicon. This is not Developer ID signing or notarization.
codesign --force --deep --sign - --entitlements Config/macOS.entitlements \
  "$STAGING_DIR/MarkdownTextTool.app"
codesign --verify --deep --strict "$STAGING_DIR/MarkdownTextTool.app"
ln -s /Applications "$STAGING_DIR/Applications"
cat > "$STAGING_DIR/READ-ME.txt" <<'NOTICE'
MarkdownTextTool — development build
This app has an ad-hoc signature only. It is not signed with Developer ID and is
not notarized by Apple. macOS Gatekeeper may prevent opening a downloaded copy.
Use a local Xcode build or a trusted signed/notarized release for distribution.
NOTICE
hdiutil create -volname MarkdownTextTool -srcfolder "$STAGING_DIR" \
  -ov -format UDZO "$BUILD_DIR/MarkdownTextTool-macOS-unsigned.dmg"
echo "Created $BUILD_DIR/MarkdownTextTool-macOS-unsigned.dmg (ad-hoc signed, not notarized)."
