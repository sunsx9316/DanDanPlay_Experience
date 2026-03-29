# CLAUDE.md

## 项目概述

AniXPlayer（弹弹Play）是一个跨平台的视频播放器项目，包含 iOS 和 Mac 两个版本，使用 Swift 编写，基于 CocoaPods 管理依赖，主要使用 VLCKit 进行视频播放。

## 语言要求

**从此以后，请始终使用中文与我交流。**

## 项目结构

```
DanDanPlay_Experience/
├── Mac/                    # Mac 版本
│   ├── AniXPlayer/        # 源代码
│   ├── AniXPlayer.xcodeproj
│   ├── AniXPlayer.xcworkspace   # 使用此文件打开项目
│   ├── Podfile
│   ├── Pods/               # CocoaPods 依赖
│   ├── LocalPods/          # 本地 Pod（ProgressHUD）
│   └── create-dmg.sh      # DMG 打包脚本
├── iOS/                    # iOS 版本
│   ├── AniXPlayer/        # 源代码
│   ├── AniXPlayer.xcodeproj
│   ├── AniXPlayer.xcworkspace   # 使用此文件打开项目
│   ├── Podfile
│   ├── Pods/               # CocoaPods 依赖
│   └── LocalPods/          # 本地 Pod（空目录）
└── Share/                  # 共享依赖
    ├── ANXLog/             # 日志库（被两个平台共用）
    ├── CocoaShare/
    └── VLCKit/
```

## 构建指令

### 安装依赖

```bash
# Mac 版本
cd Mac && pod install

# iOS 版本
cd iOS && pod install
```

### 配置 AppKey

在 `Mac/AniXPlayer/` 或 `iOS/AniXPlayer/` 目录下创建 `AppKey.swift` 文件：

```swift
struct AppKey {
    static var appId = "your_app_id"
    static var appSec = "your_app_secret"
}
```

AppKey 申请方式：https://doc.dandanplay.com/open/

### 编译项目

使用 Xcode 打开 `.xcworkspace` 文件（**不是** `.xcodeproj`）：

```bash
# Mac 版本
open Mac/AniXPlayer.xcworkspace

# iOS 版本
open iOS/AniXPlayer.xcworkspace
```

在 Xcode 中选择对应的 Target（AniXPlayer）和模拟器/设备，然后点击运行。

### 打包 DMG（Mac 版本）

```bash
cd Mac
./create-dmg.sh <app_path>
```

### 编译命令

```bash
# iOS 真机
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build

# iOS 模拟器
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 16' build
```

## 主要依赖

| Pod | 用途 | 平台 |
|-----|------|------|
| VLCKit / MobileVLCKit | 视频播放核心 | Mac / iOS |
| MMKV | 键值存储 | 通用 |
| AMSMB2 | SMB 协议支持 | 通用 |
| FirebaseCrashlytics | 崩溃日志 | 通用 |
| ProgressHUD | 加载指示器 | Mac（本地） |
| ANXLog | 日志框架 | 共享 |
| FSPagerView | 分页视图 | iOS |
| JXCategoryView | 分类视图 | iOS |

## 部署目标

- **iOS**: 12.0+
- **macOS**: 12.0+

## 分支说明

- `develop` - 主开发分支
- `develop_vlc3_6_0` - VLC 3.6.0 版本适配分支

## 编码规范

编码规范已拆分到 `.claude/rules/` 目录：

| 规则文件 | 内容 |
|---------|------|
| `swift-style.md` | Swift 编码风格、闭包捕获、guard 优先 |
| `objc-interop.md` | Swift/Obj-C 混编规范 |
| `apple-ui-ux.md` | UI 框架选择、视图拆分 |
| `memory-decisions.md` | ARC 规则、循环引用检测 |
| `git-conventions.md` | Git 提交规范 (Conventional Commits) |

## 注意事项

1. 每次更新 Podfile 后需要重新运行 `pod install`
2. 第三方库更新后建议删除 Pods 目录和 Podfile.lock 后重新安装
3. Mac 和 iOS 共用 `Share/ANXLog` 目录，修改时需注意兼容性
4. **编译 iOS 工程时，优先使用真机调试**，使用 `generic/platform=iOS` 目标编译
