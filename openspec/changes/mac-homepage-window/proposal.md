## Why

Mac 端缺少主页功能入口，用户无法在 Mac 上浏览新番时间表、查看追番队列和管理关注列表。需要参考 iOS HomePageViewController 的设计，为 Mac 创建独立的主页窗口及完整的导航链路。

## What Changes

- **新增** 主页窗口通过菜单栏"功能 → 主页"打开，独立于播放器主窗口
- **新增** `HomePageViewController` 作为主页根视图，包含 Banner 轮播、功能入口区、追番队列区
- **新增** `TimelineViewController` 使用 `NSCollectionView` + `TimelineSegmentBar`（Tab 式星期选择器）展示新番时间表
- **新增** `FavoriteViewController` 使用 `NSCollectionView` 展示用户关注列表
- **新增** `BangumiDetailViewController` 使用 `NSCollectionView` 展示番剧详情（信息头、剧集列表、相关/相似番剧）
- **新增** `HomePageNavigationWindowController` 继承 `NavigationWindowController`，提供 Toolbar 后退/前进统一导航
- **修改** 登录状态变化时通过 `AnixUserLoginStateDidChange` 通知刷新功能入口（显示/隐藏"我的关注"）和关注数据
- **新增** `HomePageNetworkHandle` / `FavoriteNetworkHandle` / `BangumiNetworkHandle` 网络请求层（共享代码）

## Capabilities

### New Capabilities
- `mac-homepage-navigation`: 主页窗口，600x800 独立窗口，Toolbar 后退/前进导航栈，通过菜单"功能 → 主页"打开
- `mac-homepage-banner`: Banner 轮播区，自动滚动 + 悬停暂停 + 页码指示器
- `mac-timeline-view`: 新番时间表，Tab 式星期 SegmentBar + NSCollectionView 展示当日番剧列表，支持关注/取关
- `mac-favorite-view`: 我的关注列表，NSCollectionView 展示，支持取消关注，未登录时提示登录
- `mac-bangumi-detail`: 番剧详情页，NSCollectionView 多 section（信息头、剧集、相关/相似番剧），支持子页面导航
- `mac-login-state-refresh`: 登录状态变化时自动刷新主页功能入口和关注数据

## Impact

- **新增文件**: `Mac/AniXPlayer/HomePage/` 目录（~10 个文件）
- **新增文件**: `Mac/AniXPlayer/BangumiDetail/` 目录（~4 个文件）
- **修改文件**: `Mac/AniXPlayer/AppDelegate.swift` — 添加 `showHomePage` 菜单动作
- **依赖**: 共享代码中的 `HomePageNetworkHandle`、`FavoriteNetworkHandle`、`BangumiNetworkHandle` 已在 Share 目录中定义
- **依赖**: `NavigationWindowController` 统一导航框架（已存在于 `Base/ViewController/`）
- **依赖**: `NSCollectionView+Helper` 注册/复用扩展（已存在于 `Helper/`）
