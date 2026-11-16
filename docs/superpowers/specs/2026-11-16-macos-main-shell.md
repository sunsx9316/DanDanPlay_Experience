# macOS 主窗口一体化外壳（Zune 风格顶部导航）

日期：2026-11-16
范围：macOS 客户端主窗口；iOS / tvOS 不受影响。

## 目标

主窗口不再只是欢迎页，而是把搜索、本地媒体库、下载、播放历史和账号相关入口收进一个统一的
应用外壳。保留原有的独立窗口与菜单入口，作为备用路径；顶部导航成为默认主路径。

## 布局

```
┌──────────────────────────────────────────────────────────────┐
│ 60pt  #1B1B1E  [AniXPlayer=首页] 搜索 媒体库 下载 我的 ... 用户/齿轮 │
├──────────────────────────────────────────────────────────────┤
│ 32pt  #26262A   首页 公告 未看番剧 新番时间表 排行榜 继续播放 在线观看 │  ← 首页
│              或 资源搜索 / 番剧搜索                              │  ← 搜索
│              或 概览 / 播放历史                                  │  ← 我的
├──────────────────────────────────────────────────────────────┤
│ content host: NSColor.windowBackgroundColor                   │
└──────────────────────────────────────────────────────────────┘
```

- 品牌区「AniXPlayer」同时是一级「首页」入口，不再单独显示「首页」按钮；登录、公告、资源等联机服务仍使用「弹弹play」。
- 一级导航：搜索 / 媒体库 / 下载 / 我的。
- 顶部栏品牌从 x=86 开始，避开交通灯；应用图标 28×28，标题 15.5pt bold，版本 9pt。
- 一级按钮 60pt 高，12.5pt semibold；默认 `#B9B9BF`，悬停/选中白色，选中下方 3px 品牌色。
- 品牌区在首页时显示同样的 3px 品牌色下划线，点击文字或图标都回到首页。
- 二级 pivot 32pt 高，11.5pt medium；默认 `#9A9AA1`，悬停/选中白色，选中下方 2px 品牌色。
- 带 pivot 的顶部栏总高度为 92pt；无 pivot 时为 60pt。右上角 Now Playing 卡片高 30pt，用户区高 30pt。
- 右上角不再显示全局搜索框；已改为 Now Playing（正在播放）卡片，接入系统媒体键；
  搜索保留在「功能 → 搜索…」菜单和「搜索」一级导航，详见 `2026-11-16-macos-batch-2.md` §8。
- 首页、搜索、我的显示 pivot；媒体库、下载隐藏 pivot，内容区向上填满。
- 内容背景使用 `NSColor.windowBackgroundColor`，随系统外观切换更新。

## 窗口 chrome

`MainShellViewController.viewDidAppear` 中一次性设置：

- `.fullSizeContentView`
- `titlebarAppearsTransparent = true`
- `titleVisibility = .hidden`
- `window.backgroundColor = #1B1B1E`
- `contentMinSize = 1000×680`；首次打开或旧版保存的窗口小于 1100×720 时扩到 1100×720，不缩小已经更大的窗口。

嵌入的 `WelcomeShellViewController` 使用
`WelcomeShellViewController(showsSidebar: false, managesWindowSize: false)`，
因此不会添加左侧栏，也不会改写窗口最小尺寸或主动调整窗口大小。

顶部栏空白区域支持拖动窗口；双击执行 zoom。按钮、Now Playing 卡片和用户区不参与拖动。

## 分区与嵌入

| 分区 | 内容 | 关键接线 |
| --- | --- | --- |
| 首页（品牌区） | `WelcomeShellViewController`（无侧栏） | 原有打开文件 / 网络文件 / 播放回调 |
| 搜索 | `MainSearchSectionViewController`：资源搜索 / 番剧搜索 | 资源下载 → 下载中心；番剧详情 → `WelcomeDetailPresenter` |
| 媒体库 | `LocalLibraryViewController` + 真实 `LocalLibraryStore` | `onPlayFiles` → 主窗口播放器 |
| 下载 | `DownloadViewController(manager: .shared)` | `onPlayFiles` → 主窗口播放器 |
| 我的 | `MainAccountSectionViewController`：概览 / 播放历史 | 追番窗口、会员/设置/翻译/总结、历史详情 |

各分区视图控制器首次进入时创建，之后缓存并只切换可见性，保留滚动位置、搜索结果和选择状态。
分区切换不会重建页面。

### 首页 pivot

- 7 项：首页 / 公告 / 未看番剧 / 新番时间表 / 排行榜 / 继续播放 / 在线观看。
- 第一项对应原来的「概览」，按 Windows 版命名改为「首页」。
- 选择 pivot 调用 `WelcomeShellViewController.selectPage(_:)`。
- 首页内部路由（例如首页跳转时间表）通过 `onPageChange` 同步 pivot 高亮。
- 当已经处于首页时再次点击品牌区，若当前不是首页页则回到首页页；
  从其他一级分区切走再切回时，保留最后停留的首页子页面。

### 首页内容视觉

- 首页概览不再使用外层卡片或分区边框，采用连续内容页：快捷操作是 30pt 图标文字行，
  继续播放为 62pt 轻量行，未看番剧为 76pt 海报文字行；仅保留播放图标、海报和评分等必要的小元素。
- 分区间距 26pt，分区标题与内容间距 10pt；标题禁止换行，避免窄宽度下出现竖排文字。
- `WelcomeOverviewSectionView` 将标题和内容封装为整体；可见分区按固定顺序插入/移除，
  禁止 `NSStackView` 自动分离隐藏视图。可见状态未变化时不重排，避免异步刷新造成重叠、异常空白或搜索框失焦。
- 未看番剧固定五列并显式等宽；今日新番最小海报宽度 144pt，海报按 1.4 比例 `.aspectFill` 裁切。
- 海报网格的最后一行补齐透明占位，所有列显式等宽，避免不足一排时海报被拉宽。

### 搜索 pivot

- 2 项：资源搜索 / 番剧搜索。
- 资源搜索：`ResourceSearchViewController`，按关键词搜索 `res.dandanplay.net`，
  支持分类/字幕组筛选，下载按钮把磁力或种子地址预填到下载中心。
- 番剧搜索：原有 `SearchUpgradedViewController`，模式为动画/剧集/标签/高级。
- 再次点击一级「搜索」回到资源搜索；从其他分区切回时保留最后停留的搜索子页面。

### 我的 pivot

- 2 项：概览 / 播放历史。
- 概览：`MainAccountHubViewController`，账号/会员信息与快捷卡片。
- 播放历史：`PlayHistoryViewController`，每次切回时刷新。
- 「播放历史」不再是顶部一级入口；账号概览中的「播放历史」卡片也切换到该 pivot。
- 再次点击一级「我的」回到概览。

### 全局搜索（保留路径）

- 顶部栏搜索框已由 Now Playing 替代；搜索入口保留在「功能 → 搜索…」菜单和「搜索」一级导航。
- 菜单搜索切换到「搜索」分区、选中「番剧搜索」，并调用
  `SearchUpgradedViewController.applyExternalSearch(_:)`；该方法确保视图已加载、切到「动画」模式、
  填入关键词并复用原有搜索动作。
- 关键词为空时只切换分区并聚焦番剧搜索输入框。
- 搜索只搜弹弹play 作品库；资源搜索使用搜索分区自己的输入框。
- 从主窗口打开详情使用独立详情窗口，不依赖导航控制器。

## 账号与用户状态

- 顶部栏与「我的」页监听 `.AnixUserLoginStateDidChange`。
- 登录状态来自 `SessionStore.shared.isLoggedIn()` / `currentProfile()`。
- 未登录：顶部显示紧凑「登录」按钮，点击走 `LoginGate.shared.ensureLoggedIn`。
- 已登录：显示头像、昵称、会员剩余天数（完整到期日放在 tooltip）；点击用户区打开会员中心。
- 「我的」页用户卡支持登录、会员中心，并在登录状态变化后刷新。
- 快捷卡片：我的追番、播放历史、会员中心、全局设置、翻译字幕、AI 视频总结。
  两列布局，窄宽度自动回退单列。

## 可访问性与本地化

- `AccessibilityID.MainShell` 提供 root、topBar、品牌首页、四个一级导航、pivot 前缀、
  搜索框、用户区、登录、设置和账号卡片前缀。
- `AccessibilityID.ResourceSearch` 提供资源搜索页、输入框、筛选、表格、状态与空态标识。
- 品牌首页、一级导航与 pivot 复用 `WelcomeShellTapView`，支持 Space / Return 激活。
- 新增字符串已写入 `Mac/AniXPlayer/Localizable.xcstrings`，提供 English 与 zh-Hans。

## 窗口关闭

主窗口关闭时调用 `LocalLibraryViewController.cancelOperations()` 停止媒体库扫描/匹配；
不停止 `DownloadManager`，下载继续在后台运行。

## 布局修正

- `AnimeListCollectionViewCell` 的海报与信息区直接使用 Auto Layout 撑满格子，海报按固定 1.4 比例
  `.aspectFill` 裁切；标题与 18pt 收藏按钮使用明确左右约束，不再受嵌套 StackView 的内容 hugging 影响。
- 新番时间表与排行榜启用 `WaterfallLayout.Mode.grid`：按阅读顺序逐行排列，同一行顶部对齐，
  末行从左侧连续开始；其他收藏、播放历史等页面继续使用原有 `.waterfall` 行为。
- 新番时间表按 175pt 目标宽度计算列数，1100pt 窗口下海报宽 166pt；排行榜按 150pt 目标宽度
  自动增减列数，同一窗口下为七列、海报约 141pt，不再固定四列并随窗口放大。
- 两个页面均使用单行标题截断，完整标题放在 tooltip；卡片高度按标题、状态、类型和排行榜热度行
  的真实占用计算，避免底部多余空白以及状态行错位。
- 播放历史海报同样按固定 1.4 比例 `.aspectFill` 裁切。
- 首页未看番剧与通用海报网格使用显式等宽约束，不依赖会被长标题/占位视图影响的 `.fillEqually`。
- 顶部栏用户区宽度 150pt，会员信息改为「会员 N 天」，避免日期被截断。

## 刻意保留 / 未做

- 旧独立窗口（搜索、播放历史、追番、媒体库、下载、会员、设置）和菜单入口全部保留。
  顶部导航是新的主路径，不删除旧路径。
- 详情仍然打开独立窗口，而不是在主窗口内 push 页面。
- 首页 pivot 切换仍沿用 `WelcomeShellViewController` 原有的页面创建逻辑；
  一级分区缓存保证切走再切回时保留首页当前子页面，但同一首页内切换不同 pivot 会重建该子页面。
- 没有新增远程访问、投屏、数据源或占位页面。
- 资源搜索只做单次关键词搜索，不做分页加载、批量下载或自动下载规则入口。

## 验证

```bash
DERIVED_DATA_PATH=/tmp/anix-dd-main-shell bash scripts/build-mac.sh Debug
```

结果：`BUILD SUCCEEDED`。

合并后主工作区验证：

- macOS / iOS / tvOS Debug 全部 `BUILD SUCCEEDED`。
- macOS 全量单测 228 个通过（含资源搜索 4 个）。
- 手动截图检查：品牌区首页、首页顶部与滚动底部、今日新番第二行、新番时间表、排行榜、搜索-资源搜索、
  搜索-番剧搜索、媒体库、下载、我的-概览、我的-播放历史；首页分区无重叠/异常空白，队列和海报网格等宽；
  时间表与排行榜逐行对齐、末行从左开始，排行榜七列小海报与完整热度文字显示正常。
- 资源搜索实际请求 `res.dandanplay.net` 并成功显示 200 条资源；下载按钮成功切换到下载中心并预填磁力链接。
