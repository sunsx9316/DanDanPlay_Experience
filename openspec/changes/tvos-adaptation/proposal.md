## Why

AniXPlayer 作为视频播放器，Apple TV 是一个天然的使用场景。当前 Share 层代码已经通过 `#if os(tvOS)` 条件编译为 tvOS 做了大量准备，TVVLCKit xcframework 也已就位。现在需要创建独立的 tvOS 工程、实现 tvOS 专用 UI 层，完成全平台覆盖。

## What Changes

- 新增 `tvOS/` 独立工程（与 `iOS/`、`Mac/` 同级），包含 tvOS App Target + Podfile
- 新增 tvOS 专用 UI 层：所有页面基于 Focus Engine + Siri Remote 交互重新设计
- 播放器交互从触摸手势体系迁移到 Siri Remote + UIPress 体系
- 移除 tvOS 不可用的功能：QR 码扫描、音量/亮度滑条、外部 URL Scheme、UIActivityViewController 等
- ANXLog Package.swift 添加 tvOS 平台声明
- CocoaPods 依赖调整：移除 MobileVLCKit（用 TVVLCKit SPM 替代）、FSPagerView、JXCategoryView
- 移除 FirebaseCrashlytics（tvOS 支持有限，用 os_log 替代）

## Capabilities

### New Capabilities

- `tvos-app`: tvOS App Target 工程搭建，包括 Podfile、构建配置、Info.plist、图标等基础设置
- `tvos-homepage`: 首页（焦点驱动的功能入口网格），替代 iOS 的 HomePageViewController
- `tvos-player`: 播放器页面，基于 Siri Remote 和 UIPress 事件的交互系统，替代 iOS 的手势交互
- `tvos-file-browser`: 文件浏览页面，支持 SMB/FTP/WebDAV/Local 文件源的焦点导航列表
- `tvos-bangumi`: 番剧详情页，适配焦点导航
- `tvos-search`: 搜索页面，使用 UISearchContainerViewController 替代 iOS 的 UISearchController
- `tvos-settings`: 设置页面，基于 TableView 焦点导航，移除分享等不可用功能
- `tvos-focus-engine`: 全局 Focus Engine 架构，包括基类焦点样式、焦点导航策略、自定义焦点动画
- `tvos-dependencies`: 依赖管理，TVVLCKit 集成、CocoaPods 配置、ANXLog tvOS 适配

### Modified Capabilities

无——现有 iOS/Mac 代码不变，Share 层已有的 `#if os(tvOS)` 条件编译已满足需求。

## Impact

- **新增 `tvOS/` 目录**：独立 Xcode 工程 + Podfile
- **Share/ANXLog**：Package.swift 添加 `.tvOS(.v13)` 平台声明
- **Share/TVVLCKit**：已有，从 untracked 变为 tracked
- **iOS 工程**：不受影响
- **Mac 工程**：不受影响
- **依赖变化**：tvOS 不需要 MobileVLCKit、FSPagerView、JXCategoryView、FirebaseCrashlytics、MPVPlayerWrapper
