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
- 右键小花可以退出、更换图形或稍后提醒。

说明：
这是朋友分享的未上架小工具，不是 App Store 应用，所以第一次打开时 macOS 可能会多问一次。
TXT

cat > "$EXTRA_DIR/安装失败解决方式.txt" <<'TXT'
安装失败解决方式

如果遇到这些提示：
- “无法验证开发者”
- “App 已损坏，无法打开”
- “Finder 没有权限打开”
- 双击后没有反应

请按下面顺序处理：

1. 先把“提肛小助手.app”拖到 Applications 文件夹。

2. 在 Applications 文件夹里，右键点击“提肛小助手.app”，选择“打开”，再确认打开。

3. 如果还是打不开，打开“终端”，复制并执行下面这行命令：

xattr -cr /Applications/提肛小助手.app

4. 执行完成后，再次右键点击“提肛小助手.app”，选择“打开”。

说明：
这是未上架 App Store 的小工具，不是病毒。macOS 第一次打开这类 App 时可能会拦截，上面的命令是清除下载隔离属性。
TXT

cp "$ROOT_DIR/提肛小助手使用说明.md" "$EXTRA_DIR/提肛小助手使用说明.md"
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

MOUNT_DIR="/Volumes/提肛小助手"
if [ -d "$MOUNT_DIR" ]; then
    hdiutil detach "$MOUNT_DIR" >/dev/null 2>&1 || true
fi

hdiutil attach "$RW_DMG_PATH" -nobrowse -quiet
osascript <<'APPLESCRIPT'
tell application "Finder"
    tell disk "提肛小助手"
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
hdiutil detach "$MOUNT_DIR" -quiet >/dev/null 2>&1 || hdiutil detach "$MOUNT_DIR" -force -quiet
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
