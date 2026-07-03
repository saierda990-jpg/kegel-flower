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

cat > "$EXTRA_DIR/安装失败解决方式.txt" <<'TXT'
提肛小助手安装失败解决方法

这份说明适用于新版 macOS，包括 Ventura、Sonoma、Sequoia 以及后续版本。

提肛小助手目前不是 App Store 应用，也没有经过 Apple 官方公证。因此第一次打开时，macOS 可能会拦截，这是系统的安全机制。

一、先确认安装方式

1. 打开“提肛小助手-mac.dmg”。
2. 把“提肛小助手.app”拖进 Applications 文件夹。
3. 不要直接在 dmg 窗口里长期运行 App。

二、方法一：右键打开

这是最推荐的方式。

1. 打开 Applications 文件夹。
2. 找到“提肛小助手.app”。
3. 右键点击它，选择“打开”。
4. 系统再次弹窗时，继续选择“打开”。

成功后，macOS 会记住这次允许，以后通常可以直接双击打开。

三、方法二：从隐私与安全性里允许

如果双击后看到类似提示：

- “无法验证开发者”
- “Apple 无法检查其是否包含恶意软件”
- “不是从 App Store 下载的”

可以这样处理：

1. 先尝试双击打开一次 App，让系统产生拦截记录。
2. 打开“系统设置”。
3. 进入“隐私与安全性”。
4. 向下滚动到“安全性”区域。
5. 找到关于“提肛小助手”被拦截的提示。
6. 点击“仍要打开”或“Open Anyway”。
7. 再次确认打开。

注意：这个按钮通常只会在你尝试打开 App 后短时间内出现。

四、方法三：清除下载隔离属性

如果仍然提示“已损坏”“无法打开”“Finder 没有权限打开”，可以使用这个方法。

1. 确认 App 已经放在 Applications 文件夹。
2. 打开“终端”。
3. 复制并执行：

xattr -cr /Applications/提肛小助手.app

4. 执行完成后，再右键点击“提肛小助手.app”，选择“打开”。

这条命令的作用是清除 macOS 给下载文件添加的隔离属性，不会修改你的系统安全设置。

五、不推荐的方法

不建议使用下面这类命令：

sudo spctl --master-disable

它会把系统的全局安全策略调低，对普通用户来说太重，也没有必要。

六、仍然打不开怎么办

可以检查：

- 是否已经把 App 拖进 Applications。
- 是否正在从 dmg 窗口里直接运行。
- 是否下载不完整，可以重新下载一次。
- 公司或学校电脑可能被管理员限制打开未公证 App，这种情况需要联系管理员。

七、隐私说明

提肛小助手的打卡、状态和提醒数据保存在本机。检查更新时只访问 GitHub，不上传你的健康数据。
TXT

cp "$ROOT_DIR/提肛小助手使用说明.md" "$EXTRA_DIR/提肛小助手使用说明.md"
cp "$ROOT_DIR/安装失败解决方法.md" "$EXTRA_DIR/安装失败解决方法.md"
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
