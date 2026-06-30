# 提肛小花 Windows 版

这是 Windows 托盘版 MVP，和 macOS 版共用同一套产品节奏，但用 Windows 原生 WinForms 实现。

## 当前包含

- 系统托盘小花图标
- 左键打开/关闭面板
- 右键打开菜单
- 启动提示
- 每 45 分钟提醒一次
- “立即开始 / 稍后 10 分钟”
- 12 组提肛练习，每组 5 秒收缩、5 秒放松
- 今日打卡记录
- 状态页：饱腹、水分、精神、运动、等级和经验
- 状态页快捷操作：喂一下、喝一下、休息、开始
- 本地记忆：提醒时间、打卡记录、状态和等级会保存在用户 AppData

## 构建环境

需要在 Windows 电脑安装 .NET 8 SDK。

下载地址：

```text
https://dotnet.microsoft.com/download/dotnet/8.0
```

## 开发运行

在项目根目录运行：

```powershell
dotnet run --project .\windows\KikuKegel.Windows\KikuKegel.Windows.csproj
```

## 打包成 exe

在项目根目录运行：

```powershell
.\scripts\package_windows.ps1
```

输出位置：

```text
dist\windows\KikuKegel.Windows.exe
```

这个 exe 是 `win-x64` 自包含单文件，理论上可以直接发给 Windows 用户试用。

## 和 macOS 版的差异

- Windows 版先做稳定托盘体验，不追求 macOS 毛玻璃视觉。
- 宠物吃饭、喝水、睡觉彩蛋先简化成状态页按钮和图标表情，后续可以继续补浮层和飞行动画。
- Windows 系统托盘不适合像 macOS 菜单栏那样长期显示文字倒计时，所以倒计时主要放在面板和悬停提示里。
