## Context

当前 `MPVFramework` 是一个内嵌在 AniXPlayer 工程中的 Xcode 动态 framework target，源码位于 `Share/CocoaShare/MediaPlayer/Wrapper/MPV/`。它依赖远程 SPM `https://github.com/mpvkit/MPVKit.git` (v0.41.0) 提供的 `Libmpv` 模块。

将其 Core 层（纯 Swift 封装，无 AniXPlayer 依赖）抽取为独立 SPM，其余集成层留在 AniXPlayer target。

## Goals / Non-Goals

**Goals:**
- 创建 SPM 包 `Share/MPVFramework/`，产出 `MPVFramework` 动态库
- Core 4 文件从 Xcode target 迁移到 SPM Sources
- 删除三平台 pbxproj 中的 MPVFramework target
- 集成层 4 文件移入 AniXPlayer target
- 编译通过（iOS 真机优先）

**Non-Goals:**
- 不修改 Core 4 文件的 API 接口
- 不修改集成层 4 文件的代码逻辑
- 不改变 MPVKit 上游依赖版本

## Decisions

### 1. SPM 包命名

| 级别 | 名称 | 理由 |
|------|------|------|
| 目录 | `Share/MPVFramework/` | 和现有 framework 名一致 |
| Package | `MPVFramework` | 默认和目录同名 |
| Product | `MPVFramework` (dynamic) | import 名不变 |
| Target | `MPVFramework` | 和 product 同名 |

### 2. 库类型：`.dynamic`

**选择**：动态库

**理由**：mpv 底层是 C 库（libmpv），和 VLCKit 链接到同一进程时可能产生符号冲突。动态库提供符号隔离，两者互不干扰。保持和现有 MPVFramework.framework 相同的隔离效果。

### 3. 功能边界：仅 Core 4 文件

| 进 SPM | 留 AniXPlayer | 理由 |
|--------|---------------|------|
| `MPV.swift` | — | 零 AniXPlayer 依赖 |
| `MPV+APIs.swift` | — | 零 AniXPlayer 依赖 |
| `MPVProperty+Values.swift` | — | 零 AniXPlayer 依赖 |
| `MPVColor+Hex.swift` | — | 零 AniXPlayer 依赖 |
| — | `MPVPlayerWrapper.swift` | 依赖 `MediaPlayerProtocol`、`ANXLog` 等 |
| — | `MPVPiPProvider.swift` | 依赖 `PiPPlayerProtocol`、`Preferences` |
| — | `MPVFrameRenderer.swift` | 依赖 `AVFoundation`、`ANXLog` |
| — | `MPVRenderContext.swift` | 依赖 `ANXLog` |

### 4. 上游依赖方式

**选择**：`.product(name: "MPVKit", package: "mpvkit")`

MPVKit SPM 提供 `MPVKit` product（内部含 `Libmpv` module）。代码中 `import Libmpv` 通过 product 的传递依赖获得。

### 5. 文件位置策略

**选择**：复制而非移动

- 新 SPM 的 Sources 目录复制 Core 4 文件
- 原 `MPV/Core/` 路径保留，但从 pbxproj 移除引用
- Git 历史保持连续（复制后删除原路径的 git 跟踪）

## Package.swift 结构

```swift
// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "MPVFramework",
    platforms: [
        .iOS(.v14),
        .macOS(.v12),
        .tvOS(.v17)
    ],
    products: [
        .library(name: "MPVFramework", type: .dynamic, targets: ["MPVFramework"])
    ],
    dependencies: [
        .package(url: "https://github.com/mpvkit/MPVKit.git", from: "0.41.0")
    ],
    targets: [
        .target(
            name: "MPVFramework",
            dependencies: [
                .product(name: "MPVKit", package: "MPVKit")
            ],
            path: "Sources"
        )
    ]
)
```

## Source File Layout

```
Share/MPVFramework/
├── Package.swift
└── Sources/
    ├── MPV.swift                  # 核心类 + 嵌套类型 + 核心方法
    ├── MPV+APIs.swift             # API 外观类 + Track 类型
    ├── MPVProperty+Values.swift   # 属性静态定义
    └── MPVColor+Hex.swift         # 颜色 hex 转换
```

这 4 个文件从 `Share/CocoaShare/MediaPlayer/Wrapper/MPV/Core/` 复制，需要做的调整：
- 移除文件头部的 target membership 注释（如 `⚠️ 此文件必须包含在 target membership 中`）
- `import Libmpv` 保持不变（通过 MPVKit product 传递依赖获得）

## 架构变更

```
Before:
  MPVFoundation.framework (Xcode target, dynamic)
  ├── Core 4 文件
  ├── 集成层 4 文件
  └── 依赖 ▶ MPVKit SPM (Libmpv)

After:
  SPM: MPVFramework (dynamic)
  └── Core 4 文件
       └── 依赖 ▶ MPVKit SPM (MPVKit → Libmpv)

  AniXPlayer.app
  ├── 集成层 4 文件
  └── 依赖 ▶ SPM MPVFramework (dynamic)
```

## Risks / Trade-offs

| 风险 | 缓解 |
|------|------|
| pbxproj 删除 target 操作可能引入 breakage | 操作前 `git stash`，出问题即回退 |
| 集成层 4 文件 `import MPVFramework` 可能找不到模块 | SPM product 名和原来 framework 名一致，理论上无影响 |
| SPM 动态库可能和 Xcode 原生的不一致 | 通过 linker flags + `otool -L` 验证产物 |
| MPVColor typealias 需要 UIKit/AppKit | 文件已用 `#if os()` 条件编译处理，无需改动 |
