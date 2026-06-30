## Context

Mac 端已有统一的 `NavigationWindowController` 导航框架（Toolbar 后退/前进）、`NSCollectionView+Helper` 注册复用扩展、`Label`/`Button` 等基类。iOS 端已有完整的 HomePage 体系（`HomePageViewController` → `TimelineViewController` / `FavoriteViewController` → `BangumiDetailViewController`）。

需要将 iOS 的 HomePage 架构适配到 Mac，使用 `NSCollectionView` 替代 `UITableView`/`UICollectionView`，使用 `NavigationWindowController` 替代 `UINavigationController`。

## Goals / Non-Goals

**Goals:**
- 创建独立的主页窗口，通过菜单"功能 → 主页"打开
- 主页包含 Banner 轮播区、功能入口区（新番时间表、我的关注）
- Timeline 使用 Tab 式 SegmentBar + NSCollectionView，按星期切换
- BangumiDetail 使用 NSCollectionView 多 section 布局
- 登录状态变化时自动刷新 UI
- 复用现有 `NavigationWindowController` 导航框架

**Non-Goals:**
- 不修改 iOS 端代码
- 不实现 macOS 不支持的 UIKit 特有功能（如 MJRefresh、UIPageViewController）
- 追番队列区为占位状态，不实现完整功能

## Decisions

### 1. 窗口方案：NavigationWindowController 子类

**选择**: 创建 `HomePageNavigationWindowController: NavigationWindowController` 子类，配置固定参数。

**备选**: 直接在 `AppDelegate` 中配置 `NavigationWindowController`。

**理由**: 子类封装窗口配置（大小 600x800、样式等），调用方只需传 root VC。符合开闭原则。

### 2. 主页布局：NSScrollView 包裹 contentView vs NSCollectionView

**选择**: 使用 `NSScrollView` + 手动布局的 `contentView`（`NSView`）。

**备选**: `NSCollectionView` 作为主页根视图。

**理由**: 主页结构固定（Banner + Function + Queue），不适合用 NSCollectionView。iOS 端也使用 `UITableView` 仅作为容器（3 种 Cell 类型）。手动布局更灵活，减少注册/复用样板代码。

### 3. Timeline 星期切换：自定义 SegmentBar + reloadData vs NSPageController

**选择**: 自定义 `TimelineSegmentBar`（`NSStackView` + `NSButton`）+ 点击时切换 `dataSource` filter 并 `reloadData()`。

**备选**: `NSPageController` 分页切换。

**理由**:
- `NSPageController` 在 Mac 上体验不佳，有复杂的快照/缓存机制
- 所有数据已在内存中（`[BangumiIntro]`），filter 操作是 O(n)，无需分页
- iOS 端因性能考虑使用 `UIPageViewController`（内存占用大），但 Mac 端数据量相同，直接 filter + reload 更简洁

### 4. BangumiDetail 多 section：enum 驱动的 NSCollectionView

**选择**: 单一 `NSCollectionView`，用 `enum SectionType` 决定 item 类型和数量。

**备选**: 多个 `NSTableView` 垂直堆叠。

**理由**:
- iOS 端已验证此模式，直接迁移
- `NSCollectionView` 支持 supplementary header，适合 section 标题
- 代码集中在一个 VC，导航和数据流清晰

### 5. 登录状态刷新：NotificationCenter + 手动刷新

**选择**: 监听 `.AnixUserLoginStateDidChange` 通知，收到后调用 `startRefresh()` 重新拉取数据并重建功能按钮。

**理由**:
- 已有通知机制，无需新增
- 刷新时同时更新数据源和功能入口（显示/隐藏"我的关注"）
- 简单可靠，与 iOS 端一致

## Risks / Trade-offs

- **NSCollectionView 手动 frame 管理**: `NSCollectionViewFlowLayout` 不自动计算 contentSize。需要在 `viewDidLayout()` 中手动更新 `collectionView.frame` height → 已通过 `updateCollectionViewFrame()` 处理
- **Banner 轮播 Timer 循环引用**: `Timer` 持有 target → 已在 `deinit` 中 `invalidate()`，闭包使用 `[weak self]`
- **SegmentBar 无分页手势**: 与 iOS 的 `UIPageViewController` 滑动体验不同 → 可接受，Mac 用户习惯点击切换
