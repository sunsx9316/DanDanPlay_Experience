# AniXPlayer

<img src="AppKey.jpeg" align="right" width="120" />

弹弹Play 是一款跨平台多功能视频播放器，支持 iOS、tvOS 和 macOS，基于 VLCKit 提供强大的媒体播放能力。

> 你问我为啥叫这个名？当然是群友选的

## 功能特性

- **多格式视频播放** — 基于 VLCKit 3.6.0，支持 MKV、MP4、AVI 等主流格式
- **媒体服务器接入** — 支持 Emby、Jellyfin 媒体库浏览与播放
- **远程文件访问** — 支持 SMB、WebDAV、FTP、PC 文件共享
- **弹幕支持** — 接入弹弹Play 弹幕库，支持在线匹配与本地加载
- **多轨字幕/音轨** — 支持内挂/外挂字幕、多音轨切换
- **画中画 (PiP)** — iOS 15+ 支持画中画播放（headless mpv 软件渲染）
- **跨平台** — iOS / tvOS / macOS 共享核心代码

## 平台支持

| 平台 | 目录 | 最低版本 | 播放内核 |
|------|------|----------|----------|
| iOS | [`iOS/`](iOS/) | 12.0 | VLCKit / MPV |
| tvOS | [`tvOS/`](tvOS/) | 17.6 | VLCKit / MPV |
| macOS | [`Mac/`](Mac/) | 12.0 | VLCKit |

## 项目结构

```
DanDanPlay_Experience/
├── iOS/                         # iOS 工程
│   ├── AniXPlayer/              # iOS 源代码
│   ├── AniXPlayer.xcworkspace   # 使用此文件打开项目
│   ├── Podfile                  # CocoaPods 依赖声明
│   └── LocalPods/               # 本地 Pod
├── tvOS/                        # tvOS 工程
│   ├── AniXPlayer/              # tvOS 源代码
│   ├── AniXPlayer.xcworkspace   # 使用此文件打开项目
│   └── Podfile                  # CocoaPods 依赖声明
├── Mac/                         # macOS 工程
│   ├── AniXPlayer/
│   ├── AniXPlayer.xcworkspace
│   ├── Podfile
│   ├── LocalPods/
│   └── create-dmg.sh            # DMG 打包脚本
└── Share/                       # 跨平台共享代码
    ├── CocoaShare/              # 核心业务逻辑（播放、网络、文件管理）
    ├── ANXLog/                  # 日志库（iOS/macOS 使用 mars xlog）
    └── VLCKit/                  # 自定义编译的 VLCKit xcframework
```

## 环境要求

- **Xcode** 16.0+
- **CocoaPods** 1.15+
- **Swift** 5.0+
- [AppKey](https://doc.dandanplay.com/open/)（接入弹弹Play API 必需）

## 快速开始

### 1. Clone 项目

```bash
git clone <repo-url>
cd DanDanPlay_Experience
```

### 2. 安装依赖

```bash
# iOS
cd iOS && pod install

# tvOS
cd tvOS && pod install

# macOS
cd Mac && pod install
```

### 3. 配置 AppKey

在对应平台的 `AniXPlayer/` 目录下创建 `AppKey.swift`：

```swift
struct AppKey {
    static var appId = "your_app_id"
    static var appSec = "your_app_secret"
}
```

> AppKey 申请：https://doc.dandanplay.com/open/

### 4. 打开工程

```bash
# iOS
open iOS/AniXPlayer.xcworkspace

# tvOS
open tvOS/AniXPlayer.xcworkspace

# macOS
open Mac/AniXPlayer.xcworkspace
```

> **注意**：必须打开 `.xcworkspace`，**不是** `.xcodeproj`

### 5. 编译运行

在 Xcode 中选择 `AniXPlayer` scheme，选择目标设备/模拟器，`Cmd + R` 运行。

#### 命令行编译

```bash
# iOS 真机
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer \
  -configuration Debug -destination 'generic/platform=iOS' build

# tvOS 模拟器
xcodebuild -workspace tvOS/AniXPlayer.xcworkspace -scheme AniXPlayer \
  -configuration Debug -destination 'platform=tvOS Simulator,name=Apple TV 4K (3rd generation)' build

# macOS 打包 DMG
cd Mac && ./create-dmg.sh <app_path>
```

## 主要依赖

| 依赖 | 用途 | 平台 |
|------|------|------|
| [VLCKit](https://code.videolan.org/videolan/VLCKit) | 视频播放核心（本地自定义编译，含 libass 字体补丁） | 全平台 |
| [MPV](https://github.com/mpv-player/mpv) | 备用播放内核（iOS PiP） | iOS |
| [YYCategories](https://github.com/ibireme/YYCategories) | Foundation/UIKit 扩展工具集 | 全平台 |
| [MMKV](https://github.com/Tencent/MMKV) | 高性能键值存储 | 全平台 |
| [Alamofire](https://github.com/Alamofire/Alamofire) | HTTP 网络请求 | 全平台 |
| [Kingfisher](https://github.com/onevcat/Kingfisher) | 图片加载与缓存 | 全平台 |
| [SnapKit](https://github.com/SnapKit/SnapKit) | Auto Layout DSL | iOS / tvOS |
| [RxSwift](https://github.com/ReactiveX/RxSwift) | 响应式编程 | 全平台 |
| [AMSMB2](https://github.com/amosavian/AMSMB2) | SMB 协议客户端 | 全平台 |
| [GCDWebServer](https://github.com/swisspol/GCDWebServer) | 嵌入式 HTTP 服务器（流媒体代理） | 全平台 |
| [DanmakuRender](https://github.com/sunsx9316/DanmakuRender) | 弹幕渲染引擎 | iOS / tvOS |
| FirebaseCrashlytics | 崩溃收集 | iOS / macOS |
| ANXLog (mars xlog) | 高性能日志 | iOS / macOS |
| ProgressHUD | 加载提示 | macOS |

## 开发指南

### 分支策略

| 分支 | 说明 |
|------|------|
| `develop` | 主开发分支 |
| `develop_vlc3_6_0` | VLCKit 3.6.0 适配 |

### 提交规范

遵循 [Conventional Commits](https://www.conventionalcommits.org/)：

```
<type>(<scope>): <subject>

类型：feat / fix / refactor / perf / style / docs / chore / opt
范围：player / media / subtitle / ui / build / memory 等
```

### 编码规范

详见 `.claude/rules/` 目录：

| 规则 | 内容 |
|------|------|
| `swift-style.md` | Swift 编码风格、闭包捕获、guard 优先 |
| `objc-interop.md` | Swift / Obj-C 混编规范 |
| `apple-ui-ux.md` | UI 框架选择、视图拆分 |
| `memory-decisions.md` | ARC 规则、循环引用检测 |
| `git-conventions.md` | Git 提交规范 |
| `base-class.md` | 基类派生规范 |
| `build-ios.md` | iOS 编译规范 |

### 关键设计决策

- **UIViewController / UIView 子类**必须从项目基类（`ViewController`、`Button`、`Label` 等）派生
- 跨平台共享代码放在 `Share/CocoaShare/`，平台专属代码放在各自 `AniXPlayer/` 目录
- Auto Layout 统一使用 **SnapKit**，禁止原生 NSLayoutConstraint 写法
- 日志使用 `ANX.logInfo/logDebug/logError` 系列 API，tvOS 底层适配 `os_log`
- 枚举遵循 `CaseIterable + displayName` 模式，避免 UI 中硬编码选项

## License

本项目基于 LGPLv2.1 协议开源（因 VLCKit 依赖要求）。详见各子模块的 LICENSE 文件。
