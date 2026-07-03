# 提肛小花 / Kegel Flower

一个带桌面宠物气质的 macOS 菜单栏提肛提醒工具。它会在菜单栏显示一朵会眨眼、睡觉、晃动的小花，到时间后用轻量气泡提醒你开始练习。

A playful macOS menu bar Kegel reminder with a tiny pet-like flower. It blinks, naps, reacts, and shows lightweight popover reminders when it is time to exercise.

## 功能 / Features

- 菜单栏小花提醒：默认每 45 分钟提醒一次。
- 提肛节奏引导：`3, 2, 1, 开始` 后按收缩 / 放松节奏练习。
- 宠物互动：眨眼、睡觉、喂食、喝水、趣味 toast。
- 今日打卡：记录每天 9:00 到 20:00 的运动完成情况。
- 状态页：查看饮水、运动和宠物状态。
- 检查更新：从 GitHub Releases 检查新版本。

- Menu bar reminder: every 45 minutes by default.
- Guided Kegel session: starts after a `3, 2, 1` countdown.
- Pet interactions: blinking, sleeping, feeding, drinking, and playful toasts.
- Daily check-in: tracks exercise progress from 9:00 to 20:00.
- Status view: shows hydration, exercise, and pet status.
- Update check: checks GitHub Releases for newer versions.

## 下载 / Download

请从 GitHub Releases 下载最新版 DMG：

Download the latest DMG from GitHub Releases:

<https://github.com/saierda990-jpg/kegel-flower/releases>

## 安装 / Install

1. 打开 `kegel-flower-mac.dmg`。
2. 将 `提肛小助手.app` 拖进 `Applications`。
3. 如果 macOS 提示无法验证，请右键 App 选择“打开”。
4. 如果仍无法打开，可在终端执行：

```sh
xattr -cr /Applications/提肛小助手.app
```

1. Open `kegel-flower-mac.dmg`.
2. Drag `提肛小助手.app` into `Applications`.
3. If macOS blocks the app, right-click it and choose “Open”.
4. If it still cannot open, run:

```sh
xattr -cr /Applications/提肛小助手.app
```

## 本地构建 / Build Locally

macOS 版本不依赖完整 Xcode 工程，使用命令行 Swift 编译：

The macOS app is built with the command-line Swift compiler:

```sh
./scripts/build_app.sh
```

打包 DMG：

Package the DMG:

```sh
./scripts/package_app.sh
```

## 隐私 / Privacy

当前版本不需要账号，打卡和宠物状态数据保存在本机。

The current version does not require an account. Check-in and pet status data are stored locally on your device.
