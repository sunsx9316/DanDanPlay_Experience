## 1. 导航框架与窗口

- [ ] 1.1 创建 `HomePageNavigationWindowController` 继承 `NavigationWindowController`，窗口 600x800，含 Toolbar 后退/前进
- [ ] 1.2 在 `AppDelegate` 中添加"功能 → 主页"菜单项和 `showHomePage(_:)` 动作
- [ ] 1.3 确保主页窗口为单例（已存在则置前，不重复创建）

## 2. 主页根视图

- [ ] 2.1 创建 `HomePageViewController`，使用 `NSScrollView` + 手动布局 `contentView`
- [ ] 2.2 实现 Banner 轮播区（`BannerCarouselView`）：自动滚动 8s、悬停暂停、页码指示器
- [ ] 2.3 实现功能入口区（水平 `NSStackView`）：动态按钮（新番时间表 + 条件显示我的关注）
- [ ] 2.4 实现追番队列占位区
- [ ] 2.5 接入 `HomePageNetworkHandle.homePage()` 网络请求

## 3. 新番时间表

- [ ] 3.1 创建 `TimelineViewController`，使用 `NSCollectionView` 展示番剧列表
- [ ] 3.2 创建 `TimelineSegmentBar` 自定义星期选择栏（`NSStackView` + `NSButton` + 动画指示器）
- [ ] 3.3 创建 `TimelineItem`（`NSCollectionViewItem`）：封面、标题、评分、状态、关注按钮
- [ ] 3.4 实现星期切换：按 `airDay` filter 数据并 `reloadData()`
- [ ] 3.5 实现关注/取关 API 调用和回调刷新

## 4. 我的关注

- [ ] 4.1 创建 `FavoriteViewController`，使用 `NSCollectionView` 展示关注列表
- [ ] 4.2 创建 `FavoriteItem`（`NSCollectionViewItem`）：封面、标题、评分、状态、最后观看时间、关注按钮
- [ ] 4.3 实现未登录提示（显示"请先登录"）
- [ ] 4.4 接入 `FavoriteNetworkHandle.getFavoriteList()` 网络请求
- [ ] 4.5 实现取消关注 API 调用并从列表移除

## 5. 番剧详情

- [ ] 5.1 创建 `BangumiDetailViewController`，使用 `NSCollectionView` + enum SectionType 多 section
- [ ] 5.2 创建 `DetailHeaderItem`：封面、标题、评分、标签、关注按钮、元数据入口
- [ ] 5.3 创建 `DetailEpisodeRowItem`：剧集入口，点击 push 剧集列表
- [ ] 5.4 创建 `DetailRelatedItem`：内嵌横向 `NSCollectionView`，展示相关/相似番剧
- [ ] 5.5 创建 `RelatedAnimeItem`（`NSCollectionViewItem`）：封面缩略图
- [ ] 5.6 创建 `BangumiDetailEpisodeViewController`（`NSTableView`）：剧集列表
- [ ] 5.7 创建 `BangumiDetailMetadataViewController`（`NSTableView`）：元数据列表
- [ ] 5.8 接入 `BangumiNetworkHandle.detail(animateId:)` 网络请求
- [ ] 5.9 动态隐藏无数据的 section

## 6. 登录状态刷新

- [ ] 6.1 在 `HomePageViewController` 监听 `.AnixUserLoginStateDidChange` 通知
- [ ] 6.2 收到通知后刷新主页数据 + 重建功能按钮（显示/隐藏"我的关注"）
- [ ] 6.3 在 `FavoriteViewController.viewWillAppear()` 检查登录状态决定是否请求数据

## 7. 工程配置

- [ ] 7.1 将所有新文件加入 Xcode 工程
- [ ] 7.2 补全 `Localizable.xcstrings` 翻译
