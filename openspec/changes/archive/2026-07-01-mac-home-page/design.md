## Context

Mac App 目前是"播放器即主页"模式，`AppDelegate` 创建的 `mainWindow` 直接以 `PlayerViewController` 为 content。iOS 版有完整的番剧浏览链路：HomePage → Timeline/Favorite → BangumiDetail → Episodes/Metadata。

共享层（`Share/CocoaShare/Networking/`）已包含全部所需的 API Handle 和数据模型，Mac 只需实现 UI 层。

Mac 已有 `MediaLibraryWindowController` 实现了基于 contentViewController 替换的 push/pop 导航栈，可以作为统一导航框架的基础。

## Goals / Non-Goals

**Goals:**
- 新建独立主页窗口，通过菜单栏打开，尺寸 600×800
- 提取统一的 Toolbar 导航框架（后退/前进），可复用于主页窗口及其他场景
- 实现 Banner 轮播、功能入口、新番时间表、我的关注、番剧详情、分集信息、作品详情 全部页面
- 登录状态变化时自动刷新功能入口（显示/隐藏"我的关注"）和相关数据
- 零修改 Share 层，全部复用现有 API 和数据模型

**Non-Goals:**
- 不修改 iOS/tvOS 代码
- 不修改现有播放器窗口行为
- 不实现 BangumiQueue（追番队列，iOS 也是空壳）
- 不实现播放功能（详情页不直接跳转播放，后续版本再加）

## Decisions

### 1. 窗口策略：独立窗口 vs 替换主窗口

**选择：独立窗口**

- 主窗口（PlayerViewController）保持现状，关闭即退出 App
- 主页窗口独立存在，关闭不影响 App 运行
- 通过 `AppDelegate` 菜单项 `showHomePage:` 打开

理由：用户可能同时浏览番剧和观看视频，两个窗口并存更符合 Mac 使用习惯。

### 2. 导航框架：提取 HomePageNavigationWindowController

**选择：新建 `HomePageNavigationWindowController` 类**

基于 `MediaLibraryWindowController` 的 push/pop 模式，提取为通用设计：
- `navigationStack: [NSViewController]` 数组管理历史
- `pushViewController(_:)` / `popViewController()` 通过 `window?.contentViewController = vc` 交换
- NSToolbar 包含后退/前进按钮，根据栈状态自动更新 enabled
- 标题随当前 content view controller 的 title 变化

```
┌──────────────────────────────────────────┐
│  ← →   [ 番剧详情 ]              Toolbar │
├──────────────────────────────────────────┤
│                                          │
│  contentViewController.view              │
│  (当前页面的 View)                        │
│                                          │
└──────────────────────────────────────────┘
```

替代方案：使用 `NSSplitViewController` 侧边栏 — 但需要重新设计 layout，与 iOS 差异过大，且对于纯浏览场景侧边栏过度设计。

### 3. UI 容器选择：NSCollectionView vs NSTableView/NSScrollView

**选择：NSCollectionView（主页、Timeline、Favorite、BangumiDetail）**

| 页面 | 布局 | 理由 |
|------|------|------|
| Banner | 水平 paging | NSCollectionViewFlowLayout 天然支持分页滚动 |
| 功能入口 | 水平 grid（2 列） | 简单 grid 布局 |
| Timeline/Favorite | 垂直列表 | 每项封面+标题+评分，CollectionView 支持灵活 item size |
| BangumiDetail | 垂直布局 + supplementary header | header 通过 supplementary view 实现，可跟随滚动或固定 |
| 关联/相似作品 | 水平滚动 section | 嵌入在 BangumiDetail 的 NSCollectionView 中 |

Episodes 和 Metadata 用 NSTableView，因为它们就是简单的文本列表，不需要 CollectionView 的灵活性。

### 4. Timeline 交互：Tab 式 vs Page 式

**选择：Tab 式 SegmentBar + NSCollectionView 数据过滤**

- SegmentBar 显示"周日"~"周六"
- 点击切换时更新 NSCollectionView 的数据源（过滤 `airDay`），reloadData
- 不创建 UIPageViewController 的多页结构

理由：Mac 上缺少 `UIPageViewController` 等价物（`NSPageController` 主要用于 wizard 模式），Tab 式更符合 Mac 交互惯例。

### 5. BangumiDetail Header 方案

**选择：NSCollectionView supplementary view（header）**

iOS 把封面信息放在 table 第一行，Mac 用 supplementary header 更合适：
- `NSCollectionView.elementKindSectionHeader` 定义 header
- Header 包含：封面图（100×120）、标题、评分、追番按钮、状态标签、类型标签
- Header 随内容滚动（不固定）

理由：NSCollectionView 原生支持 supplementary views，可以 express 更丰富的 header 布局。

### 6. 数据刷新与登录态联动

**选择：监听 `Notification.Name.AnixUserLoginStateDidChange`**

- HomePageViewController 监听该通知，收到后：
  - 重新调用 `HomePageNetworkHandle.homePage()` 刷新 banner/番剧数据
  - 功能入口 Cell 重建数据源（显示/隐藏"我的关注"）
- FavoriteViewController 在 `viewWillAppear` 时检查 `Preferences.shared.loginInfo`，未登录提示登录

与 iOS 行为一致。

### 7. NSCollectionView 数据驱动模式

**选择：NSCollectionViewDiffableDataSource**

- 每个 Section 定义一个 `Section` enum case
- 每个 Item 定义一个 `Item` enum（associated value 携带数据模型）
- DiffableDataSource 自动处理增删动画

替代方案：传统 `NSCollectionViewDataSource` 委托 — 代码更多，动画需要手动处理。DiffableDataSource 是现代 AppKit 推荐方式，且 10.12+ 可用（Mac 部署目标 12.0 完全覆盖）。

## Risks / Trade-offs

- **NSCollectionView 学习曲线**：团队此前 Mac 端只用了 NSTableView/NSOutlineView，NSCollectionView 的 supplementary view 注册和布局配置相对复杂 → 先做 HomePage（Banner + 功能入口），验证模式后再做 Timeline/BangumiDetail
- **导航框架与 MediaLibrary 重复**：两者都是 push/pop 栈 → 可后续统一重构为共享基类，但本次不强行统一，先各自实现
- **NSCollectionViewDiffableDataSource 需 macOS 10.13+** → macOS 部署目标 12.0，无兼容性问题
- **登录态刷新频率**：首页和关注页都会在登录/登出时刷新，避免重复请求 → 用 flag 标记 dirty，`viewWillAppear` 时检查是否需要刷新

## Open Questions

- 后续是否需要从番剧详情直接跳转播放？（本次不实现，但 `BangumiIntro.animeId` 已保留，后续可通过 `searchKeyword` 发起匹配搜索再播放）
