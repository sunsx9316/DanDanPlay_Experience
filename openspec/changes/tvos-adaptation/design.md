## Context

AniXPlayer 当前支持 iOS 和 Mac 两个平台，通过 `Share/CocoaShare/` 共享核心逻辑。Share 层已通过 `#if os(tvOS)` 条件编译为 tvOS 做了大量准备（30+ 处条件编译覆盖 VLCKit 导入、播放器核心选择、类型别名、路径工具等）。TVVLCKit.xcframework 已就位但尚未 tracked。

iOS 和 Mac 已采用独立工程模式（各自有自己的 `.xcodeproj` + `Podfile`），tvOS 按照相同模式扩展。

**关键约束：**
- tvOS 不支持 MPV（仅 VLC 可用）
- tvOS 不支持 UIGestureRecognizer（必须用 Siri Remote + UIPress）
- tvOS 不支持 UISlider、UISearchController、UIActivityViewController、UIPinchGestureRecognizer
- tvOS 无摄像头（无 QR 扫描）
- tvOS 无系统音量/亮度控制
- tvOS 交互完全依赖 Focus Engine

## Goals / Non-Goals

**Goals:**
- 创建 `tvOS/` 独立工程，能编译运行
- 实现 tvOS 全部页面：首页、播放器、文件浏览、番剧详情、搜索、设置、匹配
- 实现完整的 Focus Engine 交互系统
- 播放器适配 Siri Remote 物理按钮和触控板
- Share 层代码零修改（已有条件编译已满足需求）

**Non-Goals:**
- 不修改 iOS 或 Mac 工程
- 不在 tvOS 上支持 MPV
- 不实现 Top Shelf 扩展（第一个版本）
- 不实现 Siri Intents / Handoff（第一个版本）
- 不实现 QR 码扫描、PC 登录（tvOS 无摄像头）
- 不实现应用内音量/亮度调节

## Decisions

### 1. 独立工程而非同工程加 Target

**选择**：`tvOS/` 独立目录，独立 `.xcodeproj` + `Podfile`

**理由**：
- CocoaPods 不支持一个 Podfile 同时声明 `platform :ios` 和 `platform :tvos`
- MobileVLCKit 和 TVVLCKit 不能共存于同一 workspace
- 与现有 `Mac/` / `iOS/` 分离模式一致
- pbxproj 改动互不影响，便于 review 和合并

**替代方案**：同一 `.xcworkspace` 多 project → 引入额外复杂度，Pod 管理仍需分离

### 2. tvOS UI 层从零构建而非复用 iOS UI 加条件编译

**选择**：tvOS 目录下全新 UI 代码，不修改 iOS 文件

**理由**：
- iOS 和 tvOS 交互模型完全不同（触摸 vs 焦点），强行 `#if os(tvOS)` 会导致文件膨胀且难以维护
- iOS 播放器依赖大量手势代码，tvOS 完全无用
- 独立文件允许针对 tvOS 优化布局（大屏、远距离、焦点导航）
- 文件级隔离避免 git merge 冲突

**替代方案**：在 iOS 文件中加 `#if os(tvOS)` → 可读性差、维护成本高

### 3. ANXLog 通过 SPM 集成，TVVLCKit 直接嵌入 xcframework

**选择**：
- ANXLog：更新 Package.swift 添加 tvOS 平台，tvOS 工程通过 CocoaPods 的 `:path` 引用
- TVVLCKit：直接将 `Share/TVVLCKit/` 作为本地 SPM 包或直接拖入工程

**理由**：
- ANXLog 已有 SPM + CocoaPods 双支持，只需加平台声明
- TVVLCKit xcframework 约 100MB+，不适合 pod 分发，本地引用最高效
- TVVLCKit 已有 `Package.swift`，可当 SPM 本地包用

### 4. Deployment Target: tvOS 13.0

**理由**：
- tvOS 13 引入 UICollectionViewCompositionalLayout（首页灵活布局）
- tvOS 13 引入 SF Symbols（图标系统）
- 覆盖 Apple TV HD (2015) 及所有后续机型
- 与 iOS 12.0 相似策略：覆盖绝大多数活跃设备

### 5. Focus Engine 架构

**选择**：在基类中统一处理焦点样式，各页面只配置焦点顺序

```
ViewController (基类)
├── 默认实现 preferredFocusEnvironments
├── 统一的焦点动画 (缩放 1.05 + 阴影 + 视差)
└── 子类重写焦点顺序即可

TableViewCell (基类)
├── didUpdateFocus(in:) → 背景色切换 + 文字颜色变化
└── 子类自定义高亮样式

CollectionViewCell (基类)
├── didUpdateFocus(in:) → 缩放变换 + 阴影
└── 子类自定义内容
```

**替代方案**：每个页面单独实现 → 重复代码太多

### 6. 播放器 Siri Remote 交互模型

**选择**：Siri Remote 触控板用于 seek 和控制导航，物理按钮用于播放控制

| 输入 | 行为 |
|------|------|
| Click (Select) | 播放/暂停 |
| Play/Pause 按钮 | 播放/暂停 |
| 触控板左右滑动 | Seek ±10s |
| 触控板上下滑动 | 切换音轨/字幕 |
| 长按 Click | 倍速菜单 |
| Menu 按钮 | 退出播放器 |
| 方向键 | 焦点在控制栏按钮间移动 |

seek 使用 `UIPanGestureRecognizer` 的 tvOS 替代方案：使用 `UIPressesEvent` 监听方向键或使用 `GCMicroGamepad`（Siri Remote 触控板映射为 game controller）。

### 7. CocoaPods 依赖选择

| Pod | 保留？ | 理由 |
|-----|--------|------|
| MMKV | ✅ | 纯 C++ 底层，tvOS 可用 |
| AMSMB2 | ✅ | 纯 Swift 网络库，tvOS 可用 |
| GCDWebServer | ✅ | tvOS 可用（后台受限但前台可用） |
| ANXLog | ✅ | 需加 tvOS 平台声明 |
| MobileVLCKit | ❌ | iOS only，tvOS 用 TVVLCKit SPM |
| FirebaseCrashlytics | ❌ | tvOS 支持有限，用 os_log |
| FSPagerView | ❌ | UI 库，无 tvOS 版 |
| JXCategoryView | ❌ | UI 库，无 tvOS 版 |

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| GCDWebServer 在 tvOS 后台可能被挂起 | 仅在前台使用，提示用户保持应用在前台 |
| mars.framework 无 tvOS 版本 | ANXLog 在 tvOS 上降级为 os_log 输出 |
| TVVLCKit 某些格式兼容性差于 iOS | 以 VLC 官方 tvOS 支持矩阵为准 |
| Siri Remote 触控板 seek 精度不够 | 提供 10s/30s/60s 多档 seek 步长 |
| 弹幕渲染在 tvOS GPU 上性能未知 | 控制同屏弹幕数量上限，真机压测 |
| App Store 审核（视频播放器上 tvOS） | 参考 VLC/Infuse 等已上架案例 |

## Open Questions

1. tvOS 上的弹幕输入如何实现？（Siri Remote 无键盘，需依赖 iOS 远程键盘或语音输入）
2. 是否需要支持 tvOS Top Shelf？（展示继续观看的番剧）
3. Bundle ID 是否用 `com.dandanplay.anixplayer.tv` 还是复用 iOS 的？
