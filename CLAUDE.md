# CLAUDE.md

## 项目概述

AniXPlayer（弹弹Play）是一个跨平台的视频播放器项目，包含 iOS、tvOS 和 Mac 三个版本，使用 Swift 编写，基于 CocoaPods 管理依赖，视频播放支持 VLCKit 和 MPV 双内核。

## 语言要求

**从此以后，请始终使用中文与我交流。**

## 项目 Skills

会话启动时会列出 `.claude/skills/` 下的项目 skill。**当任务匹配某个 skill 的 description 时，必须 Read 该 skill 文件并按其指令执行。** 不要只依赖 `Skill` 工具——项目 skill 需要用 Read 直接加载。

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
├── tvOS/                    # tvOS 版本
│   ├── AniXPlayer/        # 源代码
│   ├── AniXPlayer.xcodeproj
│   ├── AniXPlayer.xcworkspace   # 使用此文件打开项目
│   ├── Podfile
│   ├── Pods/               # CocoaPods 依赖
│   └── LocalPods/          # 本地 Pod
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

# tvOS 版本
cd tvOS && pod install
```

### 配置 AppKey

在 `Mac/AniXPlayer/`、`iOS/AniXPlayer/` 或 `tvOS/AniXPlayer/` 目录下创建 `AppKey.swift` 文件：

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

# tvOS 版本
open tvOS/AniXPlayer.xcworkspace
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

# tvOS 真机
xcodebuild -workspace tvOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build
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
- **tvOS**: 17.6+
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

## 脚本工具

| 脚本 | 用途 |
|------|------|
| `scripts/add_to_project.rb` | 将文件加入 Xcode 工程（禁止手动编辑 pbxproj） |
| `scripts/list-skills.sh` | 扫描 `.claude/skills/`（SessionStart hook 调用） |

```bash
# 添加文件到工程
ruby scripts/add_to_project.rb ios iOS/AniXPlayer/Helper/NewFile.swift
ruby scripts/add_to_project.rb tvos tvOS/AniXPlayer/Helper/NewFile.swift
```

## 注意事项

1. 每次更新 Podfile 后需要重新运行 `pod install`
2. 第三方库更新后建议删除 Pods 目录和 Podfile.lock 后重新安装
3. Mac、iOS、tvOS 共用 `Share/` 下的代码，修改时需注意兼容性
4. **编译 iOS / tvOS 工程时，优先使用真机调试**，使用 `generic/platform=iOS` 或 `generic/platform=tvOS` 目标编译
5. **新增文件必须通过 `ruby scripts/add_to_project.rb` 加入工程**，禁止手动编辑 `project.pbxproj`
