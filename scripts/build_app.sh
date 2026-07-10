#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_NAME="KikuKegel"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"
ICON_PATH="$ROOT_DIR/build/AppIcon.icns"
TEMP_BUILD_DIR="$ROOT_DIR/build/universal"
SDKROOT="$(xcrun --show-sdk-path)"

cd "$ROOT_DIR"

rm -rf "$APP_DIR"
rm -rf "$TEMP_BUILD_DIR"
mkdir -p "$MACOS_DIR" "$RESOURCES_DIR"
mkdir -p "$TEMP_BUILD_DIR"
swiftc -target arm64-apple-macosx13.0 -sdk "$SDKROOT" Sources/KikuKegel/*.swift -O -o "$TEMP_BUILD_DIR/$APP_NAME-arm64"
swiftc -target x86_64-apple-macosx13.0 -sdk "$SDKROOT" Sources/KikuKegel/*.swift -O -o "$TEMP_BUILD_DIR/$APP_NAME-x86_64"
lipo -create "$TEMP_BUILD_DIR/$APP_NAME-arm64" "$TEMP_BUILD_DIR/$APP_NAME-x86_64" -output "$MACOS_DIR/$APP_NAME"
swift scripts/generate_icon.swift "$ICON_PATH"
cp "$ICON_PATH" "$RESOURCES_DIR/AppIcon.icns"
if [ -d "$ROOT_DIR/Resources" ]; then
    cp -R "$ROOT_DIR/Resources/." "$RESOURCES_DIR/"
fi
chmod -R u+rwX,go+rX "$RESOURCES_DIR"

cat > "$CONTENTS_DIR/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>local.kikukegel.menubar</string>
    <key>CFBundleName</key>
    <string>提肛小花</string>
    <key>CFBundleDisplayName</key>
    <string>提肛小花</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>0.2.8</string>
    <key>CFBundleVersion</key>
    <string>2</string>
    <key>LSMinimumSystemVersion</key>
    <string>13.0</string>
    <key>LSUIElement</key>
    <true/>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
PLIST

echo "$APP_DIR"
