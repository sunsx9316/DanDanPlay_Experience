# macOS 主窗口一体化外壳（Zune 风格顶部导航）

日期：2026-11-16
范围：macOS 客户端主窗口；iOS / tvOS 不受影响。

## 目标

主窗口不再只是欢迎页，而是把搜索、本地媒体库、下载、播放历史和账号相关入口收进一个统一的
应用外壳。保留原有的独立窗口与菜单入口，作为备用路径；顶部导航成为默认主路径。

## 布局

```
┌──────────────────────────────────────────────────────────────┐
│ 74pt  #1B1B1E   app icon / 弹弹play / 一级导航 / 搜索 / 用户 / 齿轮 │
├──────────────────────────────────────────────────────────────┤
│ 38pt  #26262A   概览 公告 未看番剧 新番时间表 排行榜 继续播放 在线观看 │  ← 仅「首页」
├──────────────────────────────────────────────────────────────┤
│ content host: NSColor.windowBackgroundColor                   │
│                                                              │
└──────────────────────────────────────────────────────────────┘
```

- 一级导航：首页 / 搜索 / 媒体库 / 下载 / 历史 / 我的。
- 顶部栏品牌从 x=86 开始，避开交通灯；应用图标 32×32，标题 16pt bold，版本 9.5pt。
- 一级按钮 74pt 高，13pt semibold；默认 `#B9B9BF`，悬停/选中白色，选中下方 3px 品牌色。
- 二级 pivot 38pt 高，11.5pt medium；默认 `#9A9AA1`，悬停/选中白色，选中下方 2px 品牌色。
- 非首页分区隐藏 pivot，内容区向上填满；不保留空行，也不生成占位项。
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

顶部栏空白区域支持拖动窗口；双击执行 zoom。按钮、搜索框和用户区不参与拖动。

## 分区与嵌入

| 分区 | 内容 | 关键接线 |
| --- | --- | --- |
| 首页 | `WelcomeShellViewController`（无侧栏） | 原有打开文件 / 网络文件 / 播放回调 |
| 搜索 | `SearchUpgradedViewController` | `onOpenDetail` → `WelcomeDetailPresenter` |
| 媒体库 | `LocalLibraryViewController` + 真实 `LocalLibraryStore` | `onPlayFiles` → 主窗口播放器 |
| 下载 | `DownloadViewController(manager: .shared)` | `onPlayFiles` → 主窗口播放器 |
| 历史 | `PlayHistoryViewController` | `onOpenDetail` → `WelcomeDetailPresenter` |
| 我的 | `MainAccountHubViewController` | 追番窗口、历史分区、会员/设置/翻译/总结 |

各分区视图控制器首次进入时创建，之后缓存并只切换可见性，保留滚动位置、搜索结果和选择状态。
分区切换不会重建页面。

### 首页 pivot

- 仅首页显示，7 项：概览 / 公告 / 未看番剧 / 新番时间表 / 排行榜 / 继续播放 / 在线观看。
- 选择 pivot 调用 `WelcomeShellViewController.selectPage(_:)`。
- 首页内部路由（例如概览跳转时间表）通过 `onPageChange` 同步 pivot 高亮。
- 当已经处于「首页」时再次点击一级「首页」，若当前不是概览则回到概览；
  从其他一级分区切走再切回时，保留最后停留的首页子页面。

### 全局搜索

- Enter 后切换到「搜索」分区并调用 `SearchUpgradedViewController.applyExternalSearch(_:)`。
- 该方法确保视图已加载、切到「动画」模式、填入关键词并复用原有搜索动作。
- 关键词为空时只切换分区并聚焦搜索页输入框。
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

- `AccessibilityID.MainShell` 提供 root、topBar、六个一级导航、pivot 前缀、搜索框、
  用户区、登录、设置和账号卡片前缀。
- 一级导航与 pivot 复用 `WelcomeShellTapView`，支持 Space / Return 激活。
- 新增字符串已写入 `Mac/AniXPlayer/Localizable.xcstrings`，提供 English 与 zh-Hans。

## 窗口关闭

主窗口关闭时调用 `LocalLibraryViewController.cancelOperations()` 停止媒体库扫描/匹配；
不停止 `DownloadManager`，下载继续在后台运行。

## 布局修正

- 播放历史的瀑布流卡片改用 `root.alignment = .width`，海报和文字撑满列宽；
  修复低分辨率海报按 intrinsic width 缩成一小块、同一行卡片宽度不一致的问题。
- 顶部栏用户区宽度 150pt，会员信息改为「会员 N 天」，避免日期被截断。

## 刻意保留 / 未做

- 旧独立窗口（搜索、播放历史、追番、媒体库、下载、会员、设置）和菜单入口全部保留。
  顶部导航是新的主路径，不删除旧路径。
- 详情仍然打开独立窗口，而不是在主窗口内 push 页面。
- 首页 pivot 切换仍沿用 `WelcomeShellViewController` 原有的页面创建逻辑；
  一级分区缓存保证切走再切回时保留首页当前子页面，但同一首页内切换不同 pivot 会重建该子页面。
- 没有新增远程访问、投屏、数据源或占位页面。
- 本次只做编译验证，未运行网络/UI 功能测试。

## 验证

```bash
DERIVED_DATA_PATH=/tmp/anix-dd-main-shell bash scripts/build-mac.sh Debug
```

结果：`BUILD SUCCEEDED`。

合并后主工作区验证：

- macOS / iOS / tvOS Debug 全部 `BUILD SUCCEEDED`。
- macOS 全量单测 224 个通过。
- 手动截图检查：首页 1100×720、搜索、媒体库、下载、历史、我的；历史海报列宽已修正。
