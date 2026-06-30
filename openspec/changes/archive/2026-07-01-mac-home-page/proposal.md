## Why

Mac App 目前启动直接进入播放器空态（只有一个 "Open..." 按钮），缺少番剧浏览入口。iOS 版已有完整的 HomePage → Timeline → BangumiDetail 链路，Mac 端应补齐此能力，让用户可以先浏览番剧再决定播放什么。

## What Changes

- **新增** 主页窗口（`HomePageWindow`），通过菜单栏打开（600×800），独立于播放器主窗口
- **新增** 统一导航框架（Toolbar 后退/前进 + contentViewController 替换），可复用于其他导航场景
- **新增** Banner 轮播区（NSCollectionView 水平 paging + PageControl）
- **新增** 功能入口区（新番时间表 + 我的关注），登录态变化时自动刷新
- **新增** 新番时间表页（Tab 式 SegmentBar 切换星期，NSCollectionView 垂直列表）
- **新增** 我的关注页（NSCollectionView 垂直列表，需登录）
- **新增** 番剧详情页（NSCollectionView + supplementary header + 分集/关联/相似作品）
- **新增** 分集信息页（NSTableView 列表，leaf）
- **新增** 作品详情页（NSTableView 分组列表，leaf）
- **复用** Share 层 HomePageNetworkHandle、BangumiNetworkHandle、FavoriteNetworkHandle 及所有数据模型（零新增 API 代码）

## Capabilities

### New Capabilities
- `mac-home-navigation`: 统一导航框架，NSWindowController + Toolbar 后退/前进 + contentViewController 替换
- `mac-home-page`: 主页视图，Banner 轮播 + 功能入口 + 登录态刷新
- `mac-timeline`: 新番时间表，Tab 式星期切换 + 番剧列表
- `mac-favorite`: 我的关注列表（需登录）
- `mac-bangumi-detail`: 番剧详情，header 信息 + 分集入口 + 关联/相似作品
- `mac-bangumi-episodes`: 分集信息列表
- `mac-bangumi-metadata`: 作品详情（标题、制作信息、外部链接）

### Modified Capabilities
- 无（纯新增能力，不修改现有功能）

## Impact

- **新增文件**: `Mac/AniXPlayer/HomePage/`、`Mac/AniXPlayer/BangumiDetail/` 目录，约 20+ 个新文件
- **修改文件**: `AppDelegate.swift`（菜单项）、`Mac/AniXPlayer.xcodeproj`（add-to-project）
- **共享层**: 无修改，全部复用 `Share/CocoaShare/Networking/` 现有 API
- **依赖**: 无新增依赖，NSCollectionView 是 AppKit 原生组件
