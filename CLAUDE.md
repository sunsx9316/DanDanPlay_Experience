# CLAUDE.md

## 项目

AniXPlayer（弹弹Play）— 跨平台视频播放器，iOS / tvOS / macOS，Swift + SPM，VLCKit + MPV 双内核。

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
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build

# tvOS 真机
xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build

# macOS
bash scripts/build-mac.sh Debug
bash scripts/build-mac.sh Release

# 三平台回归编译（改共享代码后必须跑）
bash scripts/build-all-platforms.sh
```

- 打开/构建用 `.xcodeproj`（依赖由 SPM 随工程解析）
- 新增/删除文件用 `ruby scripts/xcode_project.rb <platform> add|remove <路径>`，**禁止手动编辑 pbxproj**
- 首次 clone 后运行 `bash scripts/bootstrap.sh` 安装 Git hooks

## 关键约束

- **部署目标**: iOS 15.0+ / tvOS 17.6+ / macOS 12.0+
- **分支**: `develop`（主）、`develop_vlc3_6_0`（VLC 3.6.0 适配）
- **当前改动范围（2026-11-15 起）**: **只改 macOS，iOS/tvOS 的代码与行为保持不变**，登录/注册相关尤其如此。
- **共享代码**: `Share/` 下代码被三平台共用，修改需验证跨平台兼容性。
  - 新增 macOS 代码放 `Share/CocoaShare/...` 时，**只登记到 `Mac/AniXPlayer.xcodeproj`**，文件头注明 `// macOS only`；
  - 共享文件只允许加「默认不生效」的扩展点（默认 nil/关闭）或 `#if os(macOS)`，禁止改 iOS/tvOS 的代码路径与 DTO 解码语义；
  - 改过共享文件后必须跑 `bash scripts/build-all-platforms.sh`。
- **AppKey**: 三平台共用同一路径 `Share/CocoaShare/Networking/AppKey.swift`（不是各平台 `AniXPlayer/` 目录）。模板为同目录 `AppKey.swift.example`；`AppKey.swift` 已被 `.gitignore` 忽略，勿提交真实凭证。
- **MPV 代码**: 核心封装在 `Share/CocoaShare/MediaPlayer/Wrapper/MPV/Core/`，属于 `MPVFramework` target（非 `AniXPlayer`），操作 pbxproj 时注意 target 归属
