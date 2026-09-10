#!/bin/bash
# Intended for a disposable macOS CI runner. Never enable shell tracing here.
set -euo pipefail
set +x
source "$(dirname "$0")/common.sh"

required=(IOS_P12_BASE64 IOS_P12_PASSWORD IOS_PROFILE_BASE64 APPLE_TEAM_ID IOS_BUNDLE_ID)
for key in "${required[@]}"; do
  if [[ -z "${!key:-}" ]]; then
    echo "Missing signing setting: $key" >&2
    exit 1
  fi
done
export IOS_EXPORT_METHOD="${IOS_EXPORT_METHOD:-release-testing}"
case "$IOS_EXPORT_METHOD" in
  release-testing|app-store-connect) ;;
  *) echo 'IOS_EXPORT_METHOD must be release-testing or app-store-connect.' >&2; exit 1 ;;
esac

SIGNING_DIR="$(mktemp -d "${RUNNER_TEMP:-${TMPDIR:-/tmp}}/markdown-signing.XXXXXX")"
chmod 700 "$SIGNING_DIR"
export SIGNING_DIR
KEYCHAIN_PATH="$SIGNING_DIR/signing.keychain-db"
KEYCHAIN_PASSWORD="$(openssl rand -base64 32)"
ORIGINAL_KEYCHAINS=()
while IFS= read -r keychain; do
  ORIGINAL_KEYCHAINS+=("$keychain")
done < <(security list-keychains -d user | python3 -c 'import shlex,sys; print("\n".join(shlex.split(sys.stdin.read())))')
INSTALLED_PROFILES=()
cleanup() {
  local result=$?
  trap - EXIT
  security list-keychains -d user -s "${ORIGINAL_KEYCHAINS[@]}" >/dev/null 2>&1 || true
  security delete-keychain "$KEYCHAIN_PATH" >/dev/null 2>&1 || true
  for profile in "${INSTALLED_PROFILES[@]}"; do
    rm -f "$profile"
  done
  rm -rf "$SIGNING_DIR"
  exit "$result"
}
trap cleanup EXIT
trap 'exit 130' INT
trap 'exit 143' TERM

python3 - <<'PY'
import base64, os
from pathlib import Path
root = Path(os.environ['SIGNING_DIR'])
for variable, filename in [('IOS_P12_BASE64', 'certificate.p12'), ('IOS_PROFILE_BASE64', 'profile.mobileprovision')]:
    encoded = ''.join(os.environ[variable].split())
    path = root / filename
    path.write_bytes(base64.b64decode(encoded, validate=True))
    path.chmod(0o600)
PY
security create-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security set-keychain-settings -lut 21600 "$KEYCHAIN_PATH"
security unlock-keychain -p "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH"
security import "$SIGNING_DIR/certificate.p12" -P "$IOS_P12_PASSWORD" \
  -k "$KEYCHAIN_PATH" -T /usr/bin/codesign -T /usr/bin/security >/dev/null
security set-key-partition-list -S apple-tool:,apple:,codesign: -s \
  -k "$KEYCHAIN_PASSWORD" "$KEYCHAIN_PATH" >/dev/null
security list-keychains -d user -s "$KEYCHAIN_PATH" "${ORIGINAL_KEYCHAINS[@]}"
security cms -D -i "$SIGNING_DIR/profile.mobileprovision" > "$SIGNING_DIR/profile.plist"

PROFILE_UUID="$(python3 - <<'PY'
import datetime, fnmatch, os, plistlib
from pathlib import Path
root = Path(os.environ['SIGNING_DIR'])
profile = plistlib.loads((root / 'profile.plist').read_bytes())
team = os.environ['APPLE_TEAM_ID']
bundle = os.environ['IOS_BUNDLE_ID']
if team not in profile['TeamIdentifier']:
    raise SystemExit('The provisioning profile does not match APPLE_TEAM_ID.')
expiration = profile['ExpirationDate']
if expiration.replace(tzinfo=datetime.timezone.utc) <= datetime.datetime.now(datetime.timezone.utc):
    raise SystemExit('The provisioning profile has expired.')
identifier = profile['Entitlements']['application-identifier']
prefix = profile['ApplicationIdentifierPrefix'][0]
if not fnmatch.fnmatchcase(prefix + '.' + bundle, identifier):
    raise SystemExit('The provisioning profile does not match IOS_BUNDLE_ID.')
method = os.environ['IOS_EXPORT_METHOD']
if profile['Entitlements'].get('get-task-allow', False):
    raise SystemExit('Use an Apple Distribution certificate and distribution profile.')
if method == 'release-testing' and not profile.get('ProvisionedDevices'):
    raise SystemExit('release-testing requires an Ad Hoc profile with registered devices.')
if method == 'app-store-connect' and (profile.get('ProvisionedDevices') or profile.get('ProvisionsAllDevices')):
    raise SystemExit('app-store-connect requires an App Store distribution profile.')
options = {
    'method': method,
    'destination': 'export',
    'teamID': team,
    'signingStyle': 'manual',
    'signingCertificate': 'Apple Distribution',
    'provisioningProfiles': {bundle: profile['UUID']},
    'manageAppVersionAndBuildNumber': False,
    'uploadSymbols': True,
}
(root / 'ExportOptions.plist').write_bytes(plistlib.dumps(options))
print(profile['UUID'])
PY
)"

# Xcode 16+ uses UserData; keep the legacy path for older compatible Xcodes.
for directory in \
  "$HOME/Library/Developer/Xcode/UserData/Provisioning Profiles" \
  "$HOME/Library/MobileDevice/Provisioning Profiles"; do
  mkdir -p "$directory"
  destination="$directory/$PROFILE_UUID.mobileprovision"
  if [[ -e "$destination" ]]; then
    if ! cmp -s "$destination" "$SIGNING_DIR/profile.mobileprovision"; then
      echo 'A different provisioning profile already occupies the target path.' >&2
      exit 1
    fi
  else
    cp "$SIGNING_DIR/profile.mobileprovision" "$destination"
    INSTALLED_PROFILES+=("$destination")
  fi
done

generate_project
xcodebuild -project MarkdownTextTool.xcodeproj -scheme MarkdownTextTool-iOS \
  -configuration Release -destination 'generic/platform=iOS' \
  -derivedDataPath "$BUILD_DIR/DerivedData-iOS-signed" \
  -archivePath "$BUILD_DIR/MarkdownTextTool-iOS-signed.xcarchive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY='Apple Distribution' \
  "DEVELOPMENT_TEAM=$APPLE_TEAM_ID" "APP_BUNDLE_IDENTIFIER=$IOS_BUNDLE_ID" \
  "PROVISIONING_PROFILE_SPECIFIER=$PROFILE_UUID" \
  "OTHER_CODE_SIGN_FLAGS=--keychain \"$KEYCHAIN_PATH\"" \
  "CURRENT_PROJECT_VERSION=${GITHUB_RUN_NUMBER:-1}" archive
xcodebuild -exportArchive \
  -archivePath "$BUILD_DIR/MarkdownTextTool-iOS-signed.xcarchive" \
  -exportOptionsPlist "$SIGNING_DIR/ExportOptions.plist" \
  -exportPath "$BUILD_DIR/ios-export"
test -f "$BUILD_DIR/ios-export/MarkdownTextTool.ipa"
cp "$BUILD_DIR/ios-export/MarkdownTextTool.ipa" "$BUILD_DIR/MarkdownTextTool-iOS-signed.ipa"
echo "Signed IPA exported using $IOS_EXPORT_METHOD."
