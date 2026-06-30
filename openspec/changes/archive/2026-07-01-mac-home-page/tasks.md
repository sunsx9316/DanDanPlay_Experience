## 1. 导航框架（基础设施）

- [x] 1.1 新建 `HomePageNavigationWindowController`（NSWindowController 子类），实现 push/pop 导航栈 + NSToolbar 后退/前进按钮
- [x] 1.2 新建 `HomePageNavigation` 协议，定义 `pushViewController(_:)` / `popViewController()`
- [x] 1.3 在 `AppDelegate` 中添加 `homePageWindowController` 属性和菜单 "浏览" → "主页"，`showHomePage:` 方法创建/复用窗口

## 2. 主页视图

- [x] 2.1 新建 `HomePageViewController`（ViewController 子类），垂直 NSCollectionView 布局，初始大小 600×800
- [x] 2.2 新建 `HomePageBannerItemCell`（NSCollectionViewItem 子类），封面+标题+描述，水平 paging 布局 + PageControl
- [x] 2.3 实现 Banner 自动轮播（Timer 8s）+ 无限循环 + 点击打开 URL
- [x] 2.4 新建 `HomePageFunctionItemCell`（NSCollectionViewItem 子类），功能入口 grid（icon + label）
- [x] 2.5 实现功能入口数据源（未登录只显示"新番时间表"，登录后增加"我的关注"）
- [x] 2.6 集成 `HomePageNetworkHandle.homePage()` 数据获取 + 错误处理
- [x] 2.7 添加追番队列 section 占位（空壳，同 iOS）

## 3. 新番时间表

- [x] 3.1 新建 `TimelineViewController`（ViewController 子类），接收 `[BangumiIntro]` 数据
- [x] 3.2 新建 `TimelineSegmentBar`（移植自 iOS，AppKit 版），显示"周日"~"周六"，点击切换
- [x] 3.3 新建 `TimelineItemCell`（NSCollectionViewItem 子类），封面+标题+评分+追番按钮+状态
- [x] 3.4 实现按 `airDay` 分组过滤 + NSCollectionView 垂直列表展示
- [x] 3.5 实现点击 item 跳转 BangumiDetail + 追番按钮调用 API + 数据刷新回调

## 4. 我的关注

- [x] 4.1 新建 `FavoriteViewController`（ViewController 子类），NSCollectionView 垂直列表
- [x] 4.2 新建 `FavoriteItemCell`（NSCollectionViewItem 子类），封面+标题+评分+追番按钮+状态+最后观看时间
- [x] 4.3 集成 `FavoriteNetworkHandle.getFavoriteList()` + `changeFavorite()`
- [x] 4.4 实现未登录态提示（viewWillAppear 检查 loginInfo）

## 5. 番剧详情页

- [x] 5.1 新建 `BangumiDetailViewController`（ViewController 子类），NSCollectionView + supplementary header
- [x] 5.2 新建 `BangumiDetailHeaderView`（NSView 子类，用作 supplementary header），封面+标题+评分+追番按钮+状态+标签
- [x] 5.3 新建 `BangumiDetailEpisodesRowCell`（NSCollectionViewItem 子类），"分集详情" tappable row
- [x] 5.4 新建 `BangumiDetailRelatedSection`（NSCollectionView 水平滚动 section），显示关联/相似作品
- [x] 5.5 复用 `TimelineItemCell` 或新建通用 anime item cell，用于关联/相似作品展示
- [x] 5.6 集成 `BangumiNetworkHandle.detail(animateId:)` 数据获取
- [x] 5.7 实现递归导航（关联/相似作品点击推到新的 BangumiDetail）
- [x] 5.8 实现空数据处理（relateds/similars 为空时隐藏对应 section）

## 6. 分集信息页

- [x] 6.1 新建 `BangumiDetailEpisodeViewController`（ViewController 子类），NSTableView 显示分集列表
- [x] 6.2 显示每集标题、集数、上次观看时间、播出日期

## 7. 作品详情页

- [x] 7.1 新建 `BangumiDetailMetadataViewController`（ViewController 子类），NSTableView 分组列表
- [x] 7.2 实现三个 section：标题（点击复制）、制作信息（点击复制）、站外链接（点击打开浏览器）
- [x] 7.3 实现 `update(metaData:titles:onlineDatabases:)` 配置方法

## 8. 登录态刷新

- [x] 8.1 HomePageViewController 监听 `Notification.Name.AnixUserLoginStateDidChange`，收到后刷新主页数据 + 功能入口
- [x] 8.2 FavoriteViewController 在 viewWillAppear 时检查登录态，未登录提示用户

## 9. 工程集成

- [x] 9.1 使用 `add-to-project` skill 将所有新建文件加入 Mac Xcode 工程
- [x] 9.2 验证编译通过（`xcodebuild` 真机编译）
