#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_PATH="${1:-$ROOT_DIR/Build/Local Overthinker.app}"
ENTITLEMENTS_PATH="$ROOT_DIR/Config/LocalOverthinker.entitlements"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

if [[ ! -f "$ENTITLEMENTS_PATH" ]]; then
  echo "Entitlements file not found: $ENTITLEMENTS_PATH" >&2
  exit 1
fi

if [[ -n "${SIGNING_IDENTITY:-}" ]]; then
  IDENTITY="$SIGNING_IDENTITY"
else
  IDENTITY="$(security find-identity -v -p codesigning | awk -F '\"' '/Developer ID Application:/{print $2; exit}')"

  if [[ -z "$IDENTITY" ]]; then
    IDENTITY="$(security find-identity -v -p codesigning | awk -F '\"' '/Apple Development:/{print $2; exit}')"
  fi
fi

if [[ -z "${IDENTITY:-}" ]]; then
  echo "No code signing identity found. Set SIGNING_IDENTITY or install a signing certificate." >&2
  exit 1
fi

echo "Signing with identity:"
echo "$IDENTITY"

SIGN_ARGS=(
  --force
  --deep
  --sign "$IDENTITY"
  --entitlements "$ENTITLEMENTS_PATH"
)

if [[ "${ENABLE_HARDENED_RUNTIME:-1}" == "1" ]]; then
  SIGN_ARGS+=(--options runtime)
fi

if [[ "$IDENTITY" == Developer\ ID\ Application:* ]]; then
  SIGN_ARGS+=(--timestamp)
fi

codesign "${SIGN_ARGS[@]}" "$APP_PATH"
codesign --verify --deep --strict --verbose=2 "$APP_PATH"

echo
echo "Signed app bundle:"
echo "$APP_PATH"
