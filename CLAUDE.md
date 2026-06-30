# CLAUDE.md

## 项目

AniXPlayer（弹弹Play）— 跨平台视频播放器，iOS / tvOS / macOS，Swift + CocoaPods，VLCKit + MPV 双内核。

**语言：始终使用中文交流。**

## 知识导航

### 编码规范 → `.claude/rules/`

| 文件 | 适用场景 | 自动匹配 |
|------|----------|----------|
| `swift-style.md` | 所有 Swift 代码 | `**/*.swift` |
| `apple-ui-ux.md` | View / ViewController | `**/*View.swift` |
| `memory-decisions.md` | 内存管理、循环引用 | `**/*.{swift,m,h}` |
| `objc-interop.md` | Obj-C 混编 | `**/*.{swift,m,h}` |
| `base-class.md` | iOS UI 组件基类派生 | `**/*.swift` |
| `build-ios.md` | iOS 编译（真机优先） | `**/iOS/**` |
| `git-conventions.md` | Git 提交规范 | — |

### 参考文档 → `openspec/changes/`

| 文档 | 何时查阅 |
|------|----------|
| `mpv-player-reference/` | 修改 MPV 播放器相关代码前（`MPV.swift`、`MPVPlayerWrapper` 等） |
| `vlc-player-reference/` | 修改 VLC 播放器相关代码前（`VLCPlayerWrapper` 等） |
| `mpv-type-safe-refactor/` | 了解 MPV.swift 拆分历史、`Core/` 目录结构、pbxproj 操作教训 |

### 操作流程 → `.claude/skills/`

会话启动时列出。匹配到时用 `Read` 加载具体 skill 文件。

### 项目记忆 → `memory/`

自动积累：过往决策、bug 修复经验、用户偏好。启动时自动加载 `MEMORY.md`。

## 构建

```bash
# iOS 真机（优先用真机，mars.framework 不支持模拟器）
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build

# tvOS 真机
xcodebuild -workspace tvOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build
```

- 打开项目用 `.xcworkspace`，不是 `.xcodeproj`
- 新增/删除文件用 `ruby scripts/xcode_project.rb <platform> add|remove <路径>`，**禁止手动编辑 pbxproj**
- 更新 Podfile 后运行 `pod install`

## 关键约束

- **部署目标**: iOS 12.0+ / tvOS 17.6+ / macOS 12.0+
- **分支**: `develop`（主）、`develop_vlc3_6_0`（VLC 3.6.0 适配）
- **共享代码**: `Share/` 下代码被三平台共用，修改需验证跨平台兼容性
- **AppKey**: 需在各平台 `AniXPlayer/` 目录下手动创建 `AppKey.swift`（申请：https://doc.dandanplay.com/open/）
- **MPV 代码**: 核心封装在 `Share/CocoaShare/MediaPlayer/Wrapper/MPV/Core/`，属于 `MPVFramework` target（非 `AniXPlayer`），操作 pbxproj 时注意 target 归属
