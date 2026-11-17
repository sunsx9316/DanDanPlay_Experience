# macOS 第三批并行改进（搜索 / 历史 / 在线弹幕 / 解析 / 账号 / 动图 / Markdown / 菜单 / 视频设置）

> 状态：已批准，按 worktree 并行执行（2026-11-17）
> 范围：仅 macOS；iOS/tvOS 行为保持不变。
> 原则：先补用户可见闭环，不做无关重构；不伪造本地文件、在线源、账号资料或搜索结果。
> 参考：Windows `Pages/User/UserPlayHistoryControl.xaml`、`PlayHistoryEpisodeDisplayItem.cs`、`Pages/Welcome/OnlinePlayerPage.xaml.cs`、`Pages/User/UserCenterPage.xaml`、`Pages/Resources`、`Pages/Applets`。

## 1. 总目标

本轮处理 9 个互不依赖（或只共享少量文件）的问题：

1. 番剧搜索、在线观看的搜索框只在回车/点击搜索按钮时触发，不在输入过程中自动搜索。
2. 播放历史页改成 Windows 式列表：小海报 + 剧集状态（已看 / 未看 / 未上映），不再用大图瀑布流。
3. 在线观看播放前先按虚拟文件名搜索弹幕库，显示选择窗口；用户选定后才开始播放，保证首帧有弹幕。
4. 补齐 Animeko / Kazumi 解析缺口（Animeko JSONPath、Kazumi JSONPath 常用语法、规则字段与错误隔离）。
5. 补齐用户资料设置：昵称、邮箱、密码、资料编辑、bangumi.tv 关联/同步、退出登录。
6. 截图成功后的预览卡增加「保存动图」按钮，点击进入现有 GIF 导出流程。
7. 会员权益说明和 AI 视频总结结果改用 Markdown 渲染。
8. 菜单栏里的页面入口改为切换主窗口对应 tab，不再打开新的独立窗口。
9. 播放器「视频设置」面板重新排版，修复字幕相关项被压缩/裁切。

所有任务必须：

- macOS 12+ 可编译；共享代码改动加 `#if os(macOS)` 或默认不生效的扩展点；
- 每个 worktree 独立提交，不 push、不自行合并；
- 联网、支付、真实账号、真实源由用户手工验收；agent 只做编译、单测和必要的静态/截图检查；
- 新增 Swift 文件用 `ruby scripts/xcode_project.rb mac add <path>` 登记；
- 新增测试源码用 `ruby scripts/xcode_test_source.rb <path>` 登记；
- 新增字符串写入 `Localizable.xcstrings`（中英），新增关键控件加 `AccessibilityID`。

## 2. 并行分支与文件边界

| # | 任务 | 分支 | worktree | 主要文件 | 避免改动 |
|---|---|---|---|---|---|
| 1 | 搜索框回车触发 | `feat/search-enter` | `batch3-search-enter` | `Features/WelcomeShell/WelcomeOnlineViewController.swift`、`Search/SearchUpgradedViewController.swift` | 播放/历史/会员 |
| 2 | 播放历史列表与剧集状态 | `feat/history-status` | `batch3-history-status` | `Features/History/PlayHistoryWindow.swift`、`Share/CocoaShare/Networking/PlayHistory/PlayHistoryModels.swift`、新列表行视图、测试 | 主窗口菜单 |
| 3 | 在线播放前弹幕选择 | `feat/online-danmaku` | `batch3-online-danmaku` | `Features/WelcomeShell/WelcomeOnlineViewController.swift` 的播放函数、`Features/Online/OnlineEpisodeFile.swift`、`Share/CocoaShare/DanmakuManager.swift`、新弹幕选择窗口 | 解析器（任务 4） |
| 4 | Animeko/Kazumi 解析缺口 | `feat/online-parser` | `batch3-online-parser` | `Features/Online/OnlineSourceModels.swift`、`OnlineSourceStore.swift`、`OnlineMediaResolver.swift`、`KazumiJSONPath.swift`、测试/fixture | 播放流程（任务 3） |
| 5 | 用户资料与退出登录 | `feat/user-profile` | `batch3-user-profile` | 新 `Features/Account/*`、`Share/CocoaShare/Networking/User/*`、`OAuthModels.swift`、`MainAccountHubViewController.swift`、`APIEnvironment.swift` | 菜单栏、在线源 |
| 6 | 截图后保存动图 | `feat/snapshot-gif` | `batch3-snapshot-gif` | `Player/PlayerUI/SnapshotPreviewView.swift`、`Player/PlayerViewController.swift` 的截图保存回调、`AccessibilityID.swift` | 视频设置面板 |
| 7 | Markdown 渲染 | `feat/markdown` | `batch3-markdown` | 新 `Base/View/MarkdownTextView.swift`、`MembershipViewController.swift`、`SummaryViewController.swift`、测试 | 账号/在线 |
| 8 | 菜单切换主界面 tab | `feat/menu-routing` | `batch3-menu-routing` | `AppDelegate.swift`、`MainViewController.swift`、`MainShellViewController.swift`、`MainAccountSectionViewController.swift` 的公开切换方法 | 用户资料 UI |
| 9 | 视频设置面板排版 | `feat/media-settings-layout` | `batch3-media-settings-layout` | `Player/Setting/MediaSettingViewController.swift`、`Base/View/TableViewCell/SheetTableViewCell.swift`、`TitleDetailTableViewCell.swift` | 播放器业务逻辑 |

共享文件冲突按合并阶段逐段解决；不要为了避开冲突而复制整套逻辑。

## 3. 任务 1：搜索框回车触发

### 3.1 行为

- 番剧搜索、在线观看两个页面的 `NSSearchField`：
  - 仅在按下 Return 或点击「搜索」按钮时发起搜索；
  - 输入、删除、粘贴文字时不自动请求；
  - 清空输入不自动清空当前结果，下一次回车/点击再更新；
  - 外部入口（详情页「搜索资源」「在线观看」）仍然预填并自动搜索。
- 搜索框保留最近搜索记录；搜索按钮和键盘 Return 行为一致。

### 3.2 实现

- 设置 `sendsWholeSearchString = true`、`sendsSearchStringImmediately = false`；
- 如仍有 `controlTextDidChange` / `textDidChange` 触发，移除或改为只更新 UI 状态；
- 两个页面抽一个小的搜索框配置方法，避免下次又漏。

### 3.3 验收

- 输入「葬送的芙莉莲」时只在回车后出现“正在搜索”；
- 连续输入多个字符不会发起多次请求；
- 点击搜索按钮、按 Return、外部预填自动搜索都正常；
- macOS Debug 编译通过。

## 4. 任务 2：播放历史列表与剧集状态

### 4.1 参考

Windows `Pages/User/UserPlayHistoryControl.xaml`：

- 每个作品一行：左侧 100×150 海报，右侧标题、上次播放时间、剧集 chip 列表；
- 剧集 chip 状态：
  - `WatchedAlready`：有 `lastWatched`，浅蓝底；
  - `NotWatchedYet`：无 `lastWatched`，且已上映/无上映时间，灰色底；
  - `NotOnAir`：无 `lastWatched`，上映时间在未来，浅粉底；
- chip 显示集数（`episodeNumber`；特殊集用标题第一个空格前的部分），tooltip 显示完整剧集标题和状态。

### 4.2 macOS 改造

- `PlayHistoryViewController` 从 4 列瀑布流改为垂直列表：
  - 行高约 174pt，海报 100×150，圆角 6；
  - 标题 16pt semibold，上次播放时间 11pt 次要色；
  - chip 使用 `NSStackView` 自动换行（可包一层 flow layout 或按行分组），chip 高度 24pt、圆角 4、水平 padding 8；
  - 整行可点击打开详情；chip 不单独触发播放，避免误操作。
- 扩展 `PlayHistoryEpisode`：
  - 增加 `airDate: Date?`，解析服务端可选字段；
  - 保留 `episodeNumber`；
  - 新增纯函数 `PlayHistoryEpisodeStatus`，输入 `lastWatched` / `airDate` / `now`，输出 `.watched` / `.notWatched` / `.notOnAir`；
  - 新增纯函数生成 chip 标题，优先 `episodeNumber`，否则按 Windows 规则从 `episodeId % 10000` 或标题推导。
- 保持刷新、登录门禁、空态、错误态；主窗口「我的 → 播放历史」仍复用同一个 VC。
- 独立窗口 900×640 与主窗口内嵌都要正常滚动；海报不再随列宽放大。

### 4.3 验收

- 播放历史页不再出现大尺寸海报；一屏能看到多个作品；
- 已看/未看/未上映三种 chip 颜色和文字明确；
- chip 过多时自动换行，不横向溢出；
- 空历史、未登录、加载失败状态正常；
- 新增状态/标题纯函数单测通过；macOS Debug 编译通过。

## 5. 任务 3：在线播放前弹幕选择

### 5.1 背景

Windows `OnlinePlayerPage` 在启动播放时把 `SubjectName + EpisodeTitle` 作为虚拟文件名传给 `LoadEvent`（`TempTitle` / `TempFullPathForUri`），由加载流程先匹配弹幕；0 个或多于 1 个结果时弹 `ChooseMatchWindow`，1 个结果时快速匹配。macOS 已有 `OnlineEpisodeFile` 虚拟文件名，但播放前没有稳定的选择步骤。

### 5.2 行为

在线观看点击剧集后：

1. 解析视频直链（现有流程不变）；
2. 用虚拟文件名 `"\(subject.title) \(episode.title)"`（去掉扩展名）调用弹幕匹配；
3. 显示「选择弹幕库」窗口：
   - 列出匹配结果：作品名、剧集名、类型/来源；
   - 顶部关键词搜索框，默认填入虚拟文件名，可修改后重新搜索；
   - 双击结果或选中后点「开始播放」；
   - 提供「直接播放（不加载弹幕）」；
   - 取消则中止本次播放；
4. 用户选定后，把 `UserMatchInfo` 写入该虚拟文件的匹配缓存，再启动播放；
5. 播放器开始播放时直接加载已选弹幕，不再二次弹出匹配窗口；
6. 「直接播放」需要显式跳过自动匹配；后续连续播放的剧集仍按现有逻辑自动匹配，失败时跳过，不阻塞当前集。

### 5.3 实现建议

- 新增 `OnlineDanmakuMatchWindowController` / `OnlineDanmakuMatchViewController`：
  - 复用 `MatchNetworkHandle.match(with:matchMode:.fileNameOnly)` 获取 `MatchCollection`；
  - 复用 `MatchsViewController` 的表格样式/搜索交互，但不要依赖 `PlayerViewController` 的 delegate；
  - 结果为空时仍可搜索更多；搜索关键词默认虚拟文件名。
- 在 `WelcomeOnlineViewController.play(_:)` 解析成功后、`MacFeatureLauncher.playOnlineFile` 之前插入选择步骤；
- 选择结果用 `CacheManager.shared.setUserMatchInfo(with: file.fileId, info: ...)` 写入缓存；
- 直接播放用 `OnlineEpisodeFile.skipDanmakuAutoMatch = true`（或等价协议扩展）并在 `DanmakuManager.loadDanmaku` 开头检查，跳过网络匹配、直接 `startPlay(media, matchInfo: nil, danmakus: [:])`；
- 选择窗口关闭/取消要取消正在进行的匹配请求，不留下悬浮窗口；
- 不修改视频直链解析、Range 验证、连续播放预取的既有行为。

### 5.4 验收

- 首次播放在线剧集会先出现弹幕选择窗口；选择后视频开始播放时已有弹幕；
- 搜索更多、直接播放、取消三条路径都正常；
- 取消不会偷偷开始播放；直接播放不会再次弹匹配窗口；
- 连续播放后续集不阻塞当前集；
- macOS Debug 编译通过；真实源由用户手工验收。

## 6. 任务 4：Animeko / Kazumi 解析缺口

### 6.1 Animeko JSONPath

- `subjectFormatId == "jsonpath"` 时解析：
  - `selectorSubjectFormatJsonPathIndexed.selectNames`
  - `selectorSubjectFormatJsonPathIndexed.selectLinks`
- 使用现有 JSON 解析 + 最小 JSONPath 求值器（可复用/扩展 `KazumiJSONPath`，或抽出通用 `JSONPath`）；
- 结果按 URL 去重，保留 `preferShorterName` 行为；
- 失败只隔离该源，不能影响其他源。

### 6.2 Kazumi JSONPath

在现有 `$` / `.field` / `['field']` / `[index]` / `[*]` 基础上补：

- 过滤表达式：`[?(@.field == 'value')]`、`[?(@.field)]`、`[?(@.field != 'value')]`；
- 递归下降：`..field`；
- 数组切片：`[start:end]`（至少支持正向切片）；
- 逗号 union：`[0,1]` / `['a','b']`（若规则实际出现）。
- 不支持的语法继续抛出明确错误，不能静默返回空数组。

### 6.3 规则字段与边界

- Animeko：
  - 解析 `searchConfig["showAllEpisodes"]`（默认 false），并让 `parseAnimekoEpisodes` 使用该值；`matchEpisodeSortFromName` 不匹配时按规则决定是否保留；
  - 若规则提供 `matchChannelName`，在频道/剧集解析时过滤无效频道名（没有则保持现状）；
  - 确保 `searchUseOnlyFirstWord`、`searchRemoveSpecial`、`preferShorterName` 在 JSONPath 搜索路径也生效。
- Kazumi：
  - `searchMode=api` + `chapterMode=xpath` + `sourceTemplate` 为空时，先尝试搜索结果中的 URL 字段；没有可安全构造的详情地址时继续明确报错，不猜测站点 URL；
  - 检查 `sourceTemplate` 中的 `@source`、`@episodeUrl` 编码与相对/绝对 URL 处理；
  - 单条规则 JSON/字段/网络失败只隔离该规则；
  - 源管理页显示跳过原因，不静默消失。
- 不引入第三方 JSONPath 依赖；新增 fixture 只放小段 JSON/HTML，不提交真实站点大页面。

### 6.4 验收

- Animeko `jsonpath` fixture 能解析出名称/链接；
- Kazumi 过滤、递归下降、切片 fixture 通过；
- `showAllEpisodes` 不匹配正则时的行为有测试；
- 现有 18 条本地 Kazumi 规则仍可加载；`mgnacg` 若仍无法安全构造详情页，保持明确错误并记录原因；
- `KazumiRuleTests` / 新 JSONPath 测试通过；macOS Debug 编译通过。

## 7. 任务 5：用户资料与退出登录

### 7.1 入口

主窗口「我的」账号卡/快捷入口增加「账号资料」，打开独立 sheet 或窗口（建议 520×560，可滚动）。未登录时不显示可编辑项。

### 7.2 内容

- 用户卡：头像、昵称（screenName）、@用户名、用户 ID、邮箱 + 验证状态、会员状态。
- 操作：
  - **修改昵称**：原生 sheet，`POST /api/v2/user/profile`，1–50 字符；成功后刷新 `/user/me` 和主界面账号卡。
  - **修改邮箱**：原生 sheet，旧邮箱 + 新邮箱，`POST /api/v2/user/email`；提示可能需要重新验证/重新登录；成功后刷新资料。
  - **修改密码**：原生 sheet，旧密码 + 新密码（5–20 位）+ 确认；`POST /api/v2/user/password`；成功后服务端可能撤销当前会话，提示重新登录并刷新会话。
  - **验证邮箱**（未验证时）：调用 `GET /api/v2/oauth/webToken?business=email_verify` 获取临时 webToken，打开服务端账号验证页；返回后刷新 `/user/me`。
  - **bangumi.tv 关联**：
    - 已关联：显示头像、显示名、@用户名、授权到期时间；
    - 未关联/过期：调用 `GET /api/v2/oauthprovider/bangumi/login` 获取授权 URL，用浏览器打开；返回后提供「刷新状态」；
    - 管理关联：调用 `GET /api/v2/oauth/webToken?business=oauth_bangumi`，打开 `https://api.dandanplay.net/api/v2/oauthprovider/bangumi/manage?webToken=...`。
  - **退出登录**：二次确认；`SessionStore.shared.logout()`；关闭资料窗口，主界面账号卡恢复未登录。
- 所有网络失败保留输入并显示内联错误，不用阻塞式 alert 打断；密码字段使用 `NSSecureTextField`。
- 扩展 `OAuthUserProfile` 解析 `linkedAccounts.bangumi`（可选，旧响应不报错）。
- 增加 `AccessibilityID.Account.*` 与中英文字符串。
- 不修改 OAuth 登录流程本身；不在客户端保存密码/邮箱明文。

### 7.3 验收

- 昵称修改成功后主界面账号卡立即更新；
- 邮箱/密码表单校验、服务端错误、会话失效提示正常；
- bangumi 未关联/已关联/过期三种状态显示正确；授权 URL 能打开浏览器；
- 退出登录后回到未登录状态；
- 新增请求模型/状态纯逻辑单测通过；macOS Debug 编译通过；真实账号联调由用户完成。

## 8. 任务 6：截图后保存动图

### 8.1 行为

- 截图保存成功后，右侧预览卡在「已保存：文件名」下方显示「保存动图」按钮；
- 点击按钮关闭预览卡并调用现有 `exportGIF()`，进入 GIF 选项 sheet；
- 截图保存失败/权限失败时不显示按钮；
- 点击预览图片仍然在 Finder 中定位文件；按钮点击不能触发定位；
- 预览卡自动消失时间延长到至少 8 秒；鼠标悬停/聚焦按钮时暂停自动消失，保证可点击。

### 8.2 实现

- `SnapshotPreviewView` 增加 `onSaveGIF` 回调和按钮，调整高度约束；
- `PlayerViewController.saveSnapshot` 成功回调里设置 `preview?.onSaveGIF = { [weak self] in self?.exportGIF() }`；
- 按钮加 `AccessibilityID.Player.snapshotSaveGIF`，tooltip「从当前时间导出动图」；
- 不改变 GIF 选项/进度/预览流程。

### 8.3 验收

- 本地视频截图成功后能看到「保存动图」；
- 点击后 GIF 选项 sheet 出现，取消后播放器状态正常；
- 点击图片仍定位文件，两个点击区域不冲突；
- 无视频/无 GIF 能力/会员门禁失败时提示明确；
- macOS Debug 编译通过。

## 9. 任务 7：Markdown 渲染

### 9.1 范围

- 会员中心左侧「会员权益说明」使用 Markdown 渲染（当前轻量渲染器会去掉 `**`、链接等）；
- AI 视频总结结果使用统一 Markdown 渲染（当前 `AttributedString(markdown:)` 已接入，但样式与链接行为不完整）。

### 9.2 实现

- 新增共享 `MarkdownTextView` / `MarkdownRenderer`（macOS only）：
  - 支持标题 H1–H3、粗体、斜体、行内代码、无序/有序列表、引用、链接、段落间距；
  - 字体/颜色跟随系统 `labelColor` / `secondaryLabelColor`，深色模式可读；
  - 链接可点击（`NSTextViewDelegate` + `NSWorkspace`），时间戳链接保持可点击；
  - 解析失败回退纯文本，不崩溃。
- 会员中心：
  - 保留现有「弹弹play 会员」窗口标题，跳过重复 H1；
  - 使用 `MarkdownTextView`，滚动区宽高自适应；
  - 不改变会员介绍拉取/缓存逻辑。
- AI 总结：
  - 使用同一渲染器；保留复制 Markdown 原文按钮；
  - 时间戳链接可跳转或至少在浏览器打开，不能变成不可点击的纯文本。
- 加纯逻辑测试：标题/粗体/列表/链接解析结果非空且保留 link 属性。

### 9.3 验收

- 会员介绍中的标题、粗体、列表、链接正常显示，不再出现 `**` 或 `[]()` 原文；
- AI 总结结果有标题层级、列表和可点击时间戳；
- 深色/浅色模式可读；解析失败回退纯文本；
- macOS Debug 编译通过；单测通过。

## 10. 任务 8：菜单切换主界面 tab

### 10.1 映射

| 菜单项 | 目标 |
|---|---|
| 主页 | 主窗口「首页 → 概览」 |
| 搜索… | 主窗口「搜索 → 番剧搜索」，聚焦搜索框 |
| 播放历史 | 主窗口「我的 → 播放历史」 |
| 本地媒体库… | 主窗口「媒体库」 |
| 下载中心… | 主窗口「下载」 |
| 我的追番 | 主窗口「首页 → 追番队列」 |

会员中心、翻译字幕、AI 视频总结、媒体嗅探、全局设置、关于、导出动图仍保留独立窗口/sheet，不改语义。

### 10.2 实现

- `MainShellViewController` 增加公开方法：
  - `openSearchPage(_ page: MainSearchPage, focusSearch: Bool)`
  - `openAccountPage(_ page: MainAccountPage)`
  - `openLibrary()` / `openDownload(selectingTaskID:prefillSources:)`
  - `openHomePage(_ page: WelcomeShellPage)`
- `MainViewController` 增加对应包装方法，负责激活主窗口；
- `AppDelegate` 菜单 action 改为调用包装方法；不再创建 `PlayHistoryNavigationWindowController` / `SearchWindowController` / `BangumiQueueNavigationWindowController` / `LocalLibraryWindowController` / `DownloadWindowController` 作为菜单入口；
- 通知点击下载任务也优先切到主窗口「下载」并定位任务；如果实现成本高，保留独立窗口但菜单必须走 tab；
- 保留旧窗口类，避免其他入口/脚本失效；但菜单不再新建窗口；
- 主窗口未创建时先激活/创建。

### 10.3 验收

- 点击六个菜单项都只切换主窗口 tab，不出现新窗口；
- 搜索菜单会切到番剧搜索并聚焦输入框；
- 播放历史/下载/媒体库保留原有状态，不重复创建 VC；
- 主窗口最小化/被遮挡时能激活；
- macOS Debug 编译通过。

## 11. 任务 9：视频设置面板排版

### 11.1 问题

`MediaSettingViewController` 的 `TitleDetailTableViewCell`（字幕字体、字幕颜色等）在 40pt 行高内需要标题 + 副标题 + 上下间距，实际会被裁切；`SheetTableViewCell` 的长标题/弹出菜单在 400pt 面板内也会互相挤压。

### 11.2 修复

- 面板内容宽度从 400pt 提升到 440pt（或 460pt），保留最小宽度；
- 行高：
  - `TitleDetail` 类型（字幕字体、字幕颜色）≥ 64pt；
  - `Sheet` 类型（字幕轨道、音轨、宽高比）≥ 44pt；
  - `Switch` / `Step` 类型保持 40–44pt；
- `TitleDetailTableViewCell`：
  - 标题与副标题间距改为 6–8pt，底部至少 10pt；
  - 标题允许截断，tooltip 显示完整文本；副标题不挤压；
- `SheetTableViewCell`：
  - 标题设置高 compression resistance，弹出菜单最小宽度 160pt；
  - 标题过长时截断，不能把 popup 挤到负宽度；
  - 必要时改为两行：第一行标题，第二行 popup 全宽；
- `SliderTableViewCell` 检查标题/当前值/滑杆不重叠；
- 在 400/440pt 宽度、浅色/深色下检查字幕轨道、字幕字体、字幕颜色、字幕样式、防挡字幕、字幕时间偏移。

### 11.3 验收

- 视频设置面板所有字幕项完整显示，无裁切/重叠；
- 弹出菜单可正常展开，长标题有 tooltip；
- 无 Auto Layout 冲突日志；
- macOS Debug 编译通过；能启动时截图 400/440 宽度检查。

## 12. 验证、提交与合并

每个 worktree 完成标准：

1. `DERIVED_DATA_PATH=/tmp/anix-dd-batch3-<task> bash scripts/build-mac.sh Debug` 成功；
2. 涉及共享代码时追加 `bash scripts/build-all-platforms.sh Debug`；
3. 有纯逻辑改动的加/改 `Mac/AniXPlayerTests`，`bash scripts/test-mac.sh Debug` 通过；
4. 新增 Swift 文件只用 `ruby scripts/xcode_project.rb mac add <path>`，不手改 pbxproj；
5. 截图/尺寸检查只针对本任务页面，不跑真实联网/支付/账号；
6. 提交信息：`feat(mac): ...` / `fix(mac): ...`，提交后报告分支、commit、验证结果、已知限制。

合并顺序（减少冲突）：

1. 任务 7（Markdown，独立）
2. 任务 9（视频设置，独立）
3. 任务 6（截图动图）
4. 任务 1（搜索回车）
5. 任务 2（播放历史）
6. 任务 8（菜单路由）
7. 任务 5（用户资料）
8. 任务 3（在线弹幕选择）
9. 任务 4（在线解析）

共享文件冲突逐段保留两边新增逻辑；`Localizable.xcstrings` 按 key 并集处理；`project.pbxproj` 缺失文件用脚本重新登记。

## 13. 已知限制与手工验收

- 真实账号：昵称/邮箱/密码修改、bangumi 授权与管理、退出登录需要真实账号手工验证。
- 真实在线源：弹幕选择、Animeko JSONPath、Kazumi API/JSONPath 需要用真实源手工验证。
- 会员 Markdown 文案由服务端返回，需用真实响应检查标题/列表/链接。
- GIF 导出仍走会员门禁和现有无头 MPV/AVFoundation 流程；本任务只加入口。
- 菜单路由只改菜单入口，不删除旧独立窗口类；旧窗口可能仍被其他代码/脚本打开。
