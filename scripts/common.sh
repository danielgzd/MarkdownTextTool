#!/bin/bash
set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"
if [[ -z "${DEVELOPER_DIR:-}" && -d /Applications/Xcode.app/Contents/Developer ]]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
BUILD_DIR="${BUILD_DIR:-$PROJECT_ROOT/build}"
mkdir -p "$BUILD_DIR"

generate_project() {
  if [[ -n "${XCODEGEN_BIN:-}" ]]; then
    "$XCODEGEN_BIN" generate --spec project.yml
  elif command -v xcodegen >/dev/null 2>&1; then
    xcodegen generate --spec project.yml
  elif [[ -f MarkdownTextTool.xcodeproj/project.pbxproj ]]; then
    echo 'Using checked-in Xcode project (install XcodeGen to regenerate after adding files).'
  else
    echo 'XcodeGen is required. Install with: brew install xcodegen' >&2
    exit 1
  fi
}
