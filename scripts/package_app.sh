#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_SOURCE="$ROOT_DIR/build/KikuKegel.app"
DIST_DIR="$ROOT_DIR/dist"
PACKAGE_DIR="$DIST_DIR/提肛小助手"
SHARE_APP="$PACKAGE_DIR/提肛小助手.app"
EXTRA_DIR="$PACKAGE_DIR/.其他相关"
ZIP_PATH="$DIST_DIR/提肛小助手-mac.zip"
DMG_PATH="$DIST_DIR/提肛小助手-mac.dmg"
RW_DMG_PATH="$DIST_DIR/提肛小助手-mac-rw.dmg"
ICON_PATH="$ROOT_DIR/build/AppIcon.icns"
ICON_PNG_PATH="$ROOT_DIR/build/AppIconForResource.png"
ICON_RSRC_PATH="$ROOT_DIR/build/AppIcon.rsrc"
DMG_BACKGROUND_PATH="$ROOT_DIR/build/dmg-background.tiff"
DMG_BACKGROUND_SOURCE="$ROOT_DIR/Packaging/DMGBackground.tiff"
APPLICATIONS_ICON_SOURCE="$ROOT_DIR/Packaging/HotspotIcon.png"
APPLICATIONS_ICON_RSRC="$ROOT_DIR/build/ApplicationsBlackIcon.rsrc"
APPLICATIONS_ICON_WORK="$ROOT_DIR/build/ApplicationsBlackIconWithResource.png"
DMG_APP_ICON_SOURCE="$ROOT_DIR/Packaging/DMGAppIcon74In92.png"
DMG_APP_ICONSET="$ROOT_DIR/build/DMGAppIcon74In92.iconset"
DMG_APP_ICNS="$ROOT_DIR/build/DMGAppIcon74In92.icns"

"$ROOT_DIR/scripts/build_app.sh" >/dev/null

rm -rf "$DIST_DIR"
mkdir -p "$PACKAGE_DIR" "$EXTRA_DIR"
cp -R "$APP_SOURCE" "$SHARE_APP"
chmod +x "$SHARE_APP/Contents/MacOS/KikuKegel"
xattr -cr "$SHARE_APP" >/dev/null 2>&1 || true

if [ -f "$DMG_APP_ICON_SOURCE" ]; then
    rm -rf "$DMG_APP_ICONSET"
    mkdir -p "$DMG_APP_ICONSET"
    sips -z 16 16 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_16x16.png" >/dev/null
    sips -z 32 32 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_16x16@2x.png" >/dev/null
    sips -z 32 32 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_32x32.png" >/dev/null
    sips -z 64 64 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_32x32@2x.png" >/dev/null
    sips -z 128 128 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_128x128.png" >/dev/null
    sips -z 256 256 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_128x128@2x.png" >/dev/null
    sips -z 256 256 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_256x256.png" >/dev/null
    sips -z 512 512 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_256x256@2x.png" >/dev/null
    sips -z 512 512 "$DMG_APP_ICON_SOURCE" --out "$DMG_APP_ICONSET/icon_512x512.png" >/dev/null
    cp "$DMG_APP_ICON_SOURCE" "$DMG_APP_ICONSET/icon_512x512@2x.png"
    iconutil -c icns "$DMG_APP_ICONSET" -o "$DMG_APP_ICNS"
    cp "$DMG_APP_ICNS" "$SHARE_APP/Contents/Resources/AppIcon.icns"
fi

codesign --force --deep --sign - "$SHARE_APP" >/dev/null 2>&1 || true

cat > "$EXTRA_DIR/使用说明.txt" <<'TXT'
提肛小助手

打开方式：
1. 双击“提肛小助手-mac.dmg”。
2. 把“提肛小助手.app”拖到 Applications 文件夹，或直接双击 App 试用。
3. 如果 macOS 提示无法验证，请右键点击 App，选择“打开”，再确认打开。
4. 启动后它会出现在屏幕右上角菜单栏。

使用：
- 启动时会出现“提肛小助手已启动”的提示，可以选择“立即运行一次”或“稍后”。
- 单击菜单栏小花可以打开或关闭详细界面。
- 到提醒时间会弹出“时间到”的提示，点击提示可以开始练习。
- 练习时，小花会按“收 / 放”的节奏缩放并切换表情。
- 右键小花可以现在开始一次、稍后 10 分钟提醒、设置、今天不再提醒、重启插件或退出。
- 设置里可以调整提醒间隔、提醒时段、弹窗提醒和彩蛋提醒。
- “今天不再提醒”只影响当天，第二天会自动恢复。

说明：
这是朋友分享的未上架小工具，不是 App Store 应用，所以第一次打开时 macOS 可能会多问一次。
TXT

cp "$ROOT_DIR/安装失败解决方法.txt" "$EXTRA_DIR/安装失败解决方式.txt"
cp "$ROOT_DIR/提肛小助手使用说明.md" "$EXTRA_DIR/提肛小助手使用说明.md"
cp "$ROOT_DIR/安装失败解决方法.md" "$EXTRA_DIR/安装失败解决方法.md"
cp "$ROOT_DIR/安装失败解决方法.txt" "$EXTRA_DIR/安装失败解决方法.txt"
osascript <<APPLESCRIPT
tell application "Finder"
    make new alias file to POSIX file "/Applications" at POSIX file "$PACKAGE_DIR" with properties {name:"Applications"}
end tell
APPLESCRIPT
if [ -f "$APPLICATIONS_ICON_SOURCE" ]; then
    cp "$APPLICATIONS_ICON_SOURCE" "$APPLICATIONS_ICON_WORK"
    sips -i "$APPLICATIONS_ICON_WORK" >/dev/null
    DeRez -only icns "$APPLICATIONS_ICON_WORK" > "$APPLICATIONS_ICON_RSRC"
    Rez -append "$APPLICATIONS_ICON_RSRC" -o "$PACKAGE_DIR/Applications" >/dev/null
    SetFile -a C "$PACKAGE_DIR/Applications" >/dev/null 2>&1 || true
fi
cp "$ICON_PATH" "$PACKAGE_DIR/.VolumeIcon.icns"
cp "$DMG_BACKGROUND_SOURCE" "$DMG_BACKGROUND_PATH"
mkdir -p "$PACKAGE_DIR/.background"
cp "$DMG_BACKGROUND_PATH" "$PACKAGE_DIR/.background/background.tiff"
SetFile -a C "$PACKAGE_DIR" >/dev/null 2>&1 || true
SetFile -a V "$PACKAGE_DIR/.VolumeIcon.icns" >/dev/null 2>&1 || true

cd "$DIST_DIR"
ditto -c -k --sequesterRsrc --keepParent "提肛小助手" "$ZIP_PATH"
hdiutil create -volname "提肛小助手" -srcfolder "$PACKAGE_DIR" -ov -format UDRW "$RW_DMG_PATH" >/dev/null

ATTACH_OUTPUT="$(hdiutil attach "$RW_DMG_PATH" -nobrowse)"
MOUNT_DEVICE="$(printf '%s\n' "$ATTACH_OUTPUT" | awk '/\/Volumes\// {print $1; exit}')"
MOUNT_DIR="$(printf '%s\n' "$ATTACH_OUTPUT" | sed -n 's#^/dev/[^[:space:]]*[[:space:]]*[^[:space:]]*[[:space:]]*\(/Volumes/.*\)$#\1#p' | head -1)"
[ -n "$MOUNT_DEVICE" ] && [ -n "$MOUNT_DIR" ] || { printf '%s\n' "$ATTACH_OUTPUT" >&2; exit 1; }
VOLUME_NAME="${MOUNT_DIR##*/}"

osascript <<APPLESCRIPT
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {120, 120, 720, 492}
        set theOptions to icon view options of container window
        set arrangement of theOptions to not arranged
        set icon size of theOptions to 94
        set text size of theOptions to 10
        set background picture of theOptions to file ".background:background.tiff"
        set position of item "提肛小助手.app" of container window to {479, 82}
        set position of item "Applications" of container window to {479, 230}
        close
        open
        update without registering applications
        delay 1
    end tell
end tell
APPLESCRIPT
sync
hdiutil detach "$MOUNT_DEVICE" -quiet >/dev/null 2>&1 || hdiutil detach "$MOUNT_DEVICE" -force -quiet
for _ in {1..20}; do
    [ ! -d "$MOUNT_DIR" ] && break
    sleep 0.2
done

hdiutil convert "$RW_DMG_PATH" -format UDZO -imagekey zlib-level=9 -ov -o "$DMG_PATH" >/dev/null
rm -f "$RW_DMG_PATH"
sips -s format png "$ICON_PATH" --out "$ICON_PNG_PATH" >/dev/null
sips -i "$ICON_PNG_PATH" >/dev/null
DeRez -only icns "$ICON_PNG_PATH" > "$ICON_RSRC_PATH"
Rez -append "$ICON_RSRC_PATH" -o "$DMG_PATH"
SetFile -a C "$DMG_PATH" >/dev/null 2>&1 || true

echo "$DMG_PATH"
echo "$ZIP_PATH"
