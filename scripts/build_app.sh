#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

APP_NAME="Local Overthinker"
BUNDLE_NAME="$APP_NAME.app"
BUNDLE_DIR="$ROOT_DIR/Build/$BUNDLE_NAME"
CONTENTS_DIR="$BUNDLE_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_SOURCE="$ROOT_DIR/Assets/AppIconSource.jpg"
ICONSET_DIR="$ROOT_DIR/Build/AppIcon.iconset"
ICON_NAME="AppIcon"
ICON_MASTER_PNG="$ROOT_DIR/Build/AppIcon-master.png"

if [[ ! -f "$ICON_SOURCE" ]]; then
  echo "Missing app icon source: $ICON_SOURCE" >&2
  exit 1
fi

swift build -c release

rm -rf "$BUNDLE_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"

rm -rf "$ICONSET_DIR"
mkdir -p "$ICONSET_DIR"

cp ".build/release/LocalOverthinkerMac" "$MACOS_DIR/LocalOverthinkerMac"
chmod +x "$MACOS_DIR/LocalOverthinkerMac"

cp "Systemprompt.md" "$RESOURCES_DIR/Systemprompt.md"

sips -s format png "$ICON_SOURCE" --out "$ICON_MASTER_PNG" >/dev/null
sips -z 16 16 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_16x16.png" >/dev/null
sips -z 32 32 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_16x16@2x.png" >/dev/null
sips -z 32 32 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_32x32.png" >/dev/null
sips -z 64 64 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_32x32@2x.png" >/dev/null
sips -z 128 128 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_128x128.png" >/dev/null
sips -z 256 256 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_128x128@2x.png" >/dev/null
sips -z 256 256 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_256x256.png" >/dev/null
sips -z 512 512 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_256x256@2x.png" >/dev/null
sips -z 512 512 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_512x512.png" >/dev/null
sips -z 1024 1024 "$ICON_MASTER_PNG" --out "$ICONSET_DIR/icon_512x512@2x.png" >/dev/null
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/$ICON_NAME.icns"
rm -f "$ICON_MASTER_PNG"
rm -rf "$ICONSET_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleDevelopmentRegion</key>
  <string>en</string>
  <key>CFBundleDisplayName</key>
  <string>Local Overthinker</string>
  <key>CFBundleExecutable</key>
  <string>LocalOverthinkerMac</string>
  <key>CFBundleIdentifier</key>
  <string>com.jakobendemann.local-overthinker</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleInfoDictionaryVersion</key>
  <string>6.0</string>
  <key>CFBundleName</key>
  <string>Local Overthinker</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>0.1.0</string>
  <key>CFBundleVersion</key>
  <string>1</string>
  <key>LSMinimumSystemVersion</key>
  <string>13.0</string>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

cat > "$CONTENTS_DIR/PkgInfo" <<'PKG'
APPL???? 
PKG

if [[ "${AUTO_SIGN_APP:-1}" == "1" ]]; then
  "$ROOT_DIR/scripts/sign_app.sh" "$BUNDLE_DIR"
fi

echo "Built app bundle:"
echo "$BUNDLE_DIR"
