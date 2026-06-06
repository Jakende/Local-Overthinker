#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_PATH="${1:-$ROOT_DIR/Build/Local Overthinker.app}"
ZIP_PATH="$ROOT_DIR/Build/Local Overthinker-notarization.zip"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

SIGN_INFO="$(codesign -dvv "$APP_PATH" 2>&1 || true)"

if ! echo "$SIGN_INFO" | grep -q 'Authority=Developer ID Application:'; then
  echo "Notarization requires a Developer ID Application signature." >&2
  echo "Current signature info:" >&2
  echo "$SIGN_INFO" >&2
  exit 1
fi

if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]; then
  NOTARY_ARGS=(--keychain-profile "$NOTARYTOOL_PROFILE")
elif [[ -n "${APPLE_ID:-}" && -n "${APPLE_TEAM_ID:-}" && -n "${APPLE_APP_PASSWORD:-}" ]]; then
  NOTARY_ARGS=(
    --apple-id "$APPLE_ID"
    --team-id "$APPLE_TEAM_ID"
    --password "$APPLE_APP_PASSWORD"
  )
else
  echo "Provide NOTARYTOOL_PROFILE or APPLE_ID + APPLE_TEAM_ID + APPLE_APP_PASSWORD." >&2
  exit 1
fi

rm -f "$ZIP_PATH"
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

xcrun notarytool submit "$ZIP_PATH" "${NOTARY_ARGS[@]}" --wait
xcrun stapler staple "$APP_PATH"
xcrun stapler validate "$APP_PATH"

echo
echo "Notarized app bundle:"
echo "$APP_PATH"
