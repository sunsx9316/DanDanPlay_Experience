# macOS 第二批并行改进（详情播放 / Kazumi / 弹幕列表 / 播放器控制 / 播放列表 / Now Playing / 会员中心）

> 状态：已批准，按 worktree 并行执行（2026-11-16）
> 范围：仅 macOS；iOS/tvOS 行为保持不变。
> 参考：Windows `MembershipWindow.xaml`、`CommentListApplet.xaml`、`OnlineMediaResolver.cs`、`KazumiSourceProvider.cs`。
> 原则：先补用户可见闭环，不做无关重构；不伪造本地文件、在线源或支付结果。

## 1. 总目标

本轮同时处理 7 个互不依赖的功能点：

1. 详情页增加「搜索资源」「在线观看」，并支持从详情剧集列表播放媒体库已匹配文件。
2. 完善 Kazumi 源解析，覆盖 API/POST、JSONPath、嵌套/分隔剧集等边界情况。
3. 实现播放器「弹幕列表」。
4. 修复播放器右下角文字按钮不可见的问题。
5. 首页「播放列表」直接打开播放器窗口并显示播放列表。
6. 右上角用 Now Playing 替代全局搜索框。
7. 按 Windows 版重做会员中心排版与操作状态。

所有任务必须：

- 保持 macOS 12+ 可编译；
- 不改变 iOS/tvOS 行为；改到共享代码时必须加默认不生效的扩展点或 `#if os(macOS)`；
- 每个 worktree 独立提交，不 push、不自行合并；
- 联网/支付/真实源功能由用户手工验收，agent 只做编译、单元测试和必要的 UI 截图检查；
- 新增字符串写入 `Localizable.xcstrings`，关键控件加 `AccessibilityID`。

## 2. 并行分支与文件边界

| # | 分支 | worktree 名称 | 主要文件 | 避免改动 |
|---|---|---|---|---|
| 1 | `feat/detail-play` | `batch2-detail-play` | `BangumiDetail*`、`LocalLibraryStore.swift`、新增本地文件解析器、`WelcomeDetailPresenter.swift`、`MainShellViewController.swift` 的详情路由 | `OnlineMediaResolver.swift`、会员页 |
| 2 | `feat/kazumi-api` | `batch2-kazumi-api` | `Features/Online/*`、`OnlineSourceStore.swift`、新增 Kazumi API JSONPath/请求模型、`AniXPlayerTests` | `MainShell*`、详情页、播放器 UI |
| 3 | `feat/danmaku-list` | `batch2-danmaku-list` | 新增 `DanmakuListViewController`、`PlayerViewController.swift` 的弹幕列表回调、`DanmakuSettingViewController.swift`、`AccessibilityID.swift` | `PlayerUIBottomView.swift`、主窗口 |
| 4 | `feat/player-controls` | `batch2-player-controls` | `PlayerUIBottomView.swift`、`PlayerUIView.swift`、`Button.swift` | `PlayerViewController.swift`、主窗口 |
| 5 | `feat/playlist-entry` | `batch2-playlist-entry` | `WelcomeOverviewViewController.swift`、`MainViewController.swift`、`PlayerWindowController.swift`、`PlayerViewController.swift` 的播放列表展示、`MainShellViewController.swift` 的播放入口 | `PlayerUIBottomView.swift`、详情页 |
| 6 | `feat/now-playing` | `batch2-now-playing` | `MainTopBarView.swift`、新增 Now Playing 视图/状态中心、`MainShellViewController.swift` 顶栏回调、`PlayerViewController.swift` 状态上报、`AppDelegate.swift` 菜单搜索保留 | `WelcomeOverview*`、详情页 |
| 7 | `feat/membership-redesign` | `batch2-membership` | `MembershipViewController.swift`、`MembershipWindowController.swift`、`MembershipViewModel.swift`、会员资源图片、`AccessibilityID.swift` | 主窗口、播放器 |

共享文件（`MainShellViewController`、`PlayerViewController`、`MainViewController`、`AccessibilityID`、`project.pbxproj`）会由多个分支触碰。各 agent 只做本任务必需的最小改动，不重命名/重排既有方法；合并阶段统一解决冲突。

## 3. 任务 1：详情页操作与媒体库剧集播放

### 3.1 详情页操作

在 `BangumiDetailHeroView` 的操作区增加两个按钮，顺序为：

1. 关注/取消关注（现有）
2. **搜索资源**
3. **在线观看**
4. 作品资料（现有）
5. 查看剧集（现有）

行为：

- **搜索资源**：打开主窗口「搜索 → 资源搜索」，将番剧标题填入关键词并发起搜索。
- **在线观看**：打开主窗口「首页 → 在线观看」，将番剧标题填入关键词并发起搜索。
- 详情页仍可能从旧搜索窗口打开；主窗口不存在时，先激活/创建主窗口，再执行路由。
- 不允许在详情页内嵌在线播放器；本任务只做路由与预填搜索。
- 两个按钮使用现有 `WelcomeShellClosureButton` 风格，图标分别为 `magnifyingglass` / `play.rectangle.on.rectangle`，提供 tooltip 和 accessibility label。
- 1000pt 详情窗口下 5 个按钮必须一行显示；更窄时允许压缩文字或换行，不允许按钮被裁切到不可点击。

### 3.2 剧集播放（媒体库已匹配文件）

- 详情页剧集预览卡和「查看全部剧集」列表，都要在**该剧集存在媒体库匹配文件**时显示播放按钮/本地标记。
- 匹配规则：`LocalLibraryFile.animeId == detail.animeId && LocalLibraryFile.episodeId == episode.episodeId && !isMissing`。
- 新增一个轻量查询接口（例如 `LocalLibraryStore.matchedFiles(animeId:episodeId:)`），只读、不触发扫描，不修改匹配数据。
- 多个文件匹配同一集时，点击播放弹出选择菜单（文件名 + 路径），选择后播放；只有一个时直接播放。
- 播放前必须经过 `LocalLibraryFolderAccess.shared.ensureAccess(folder:)` 和文件存在检查；缺失文件禁用播放并显示原因。
- 播放调用现有主播放器路径（`MainViewController.openLocalFiles` 或等价 presenter），不要新建第二套播放器。
- 没有匹配文件的剧集只显示现有信息，不显示灰色假按钮。

### 3.3 验收

- 详情操作区两个按钮能跳转并自动搜索。
- 有匹配文件的剧集出现播放入口，点击后在播放器打开正确文件；无匹配文件不出现入口。
- 多文件匹配可选择；缺失文件不可播放。
- `bash scripts/build-mac.sh Debug` 通过；新增查询逻辑有单元测试（内存/SQLite 临时库）。
- 不联网跑真实详情接口；用现有模型/快照做 UI 检查。

## 4. 任务 2：Kazumi 源边界情况

### 4.1 当前问题

`OnlineSourceStore.parseKazumiRule` 目前直接跳过：

- `usePost == true`
- `searchMode == "api"`
- `chapterMode == "api"`

本地 19 个 Kazumi 规则中约一半是 API 模式，表现为「源存在但完全不出现在搜索里」，不是解析失败。另有 XPath 相对路径、绝对 `/self::*`、union、`following-sibling`、`@keyword` 查询参数、`baseURL` 空值等边界。

### 4.2 本轮范围

支持 Kazumi 规则中常见的 API/POST 解析，而不是只跳过：

1. **搜索 API**
   - `searchMode = "api"` 时读取 `searchApiConfig`。
   - `request.method` 支持 GET/POST。
   - GET 使用 `query`；POST 使用 `bodyType = json` 的 JSON body；保留 `headers`。
   - `@keyword` 在 query/body 中做正确编码（不要直接拼接未编码字符串）。
   - `listPath` / `namePath` / `sourcePath` / `sourceTemplate` 使用最小 JSONPath 子集：`$`、`.`、`[*]`、数组下标、对象字段。
   - `sourceTemplate` 为空时，source 是站点内部 ID/令牌，不是 URL；`OnlineSubject` 必须保留 source token 和 API 上下文，禁止伪造无效 URL。
2. **剧集 API**
   - `chapterMode = "api"` 时读取 `chapterApiConfig`。
   - `format = "delimited"`：`roadNamesPath`、`roadEpisodesPath`、`roadSeparator`（常见 `$$$`）、`episodeSeparator`（`#`）、`fieldSeparator`（`$`）。
   - `format = "nested"`：`roadsPath`、`roadNamePath`、`episodesPath`、`episodeNamePath`、`episodeUrlPath`。
   - `episodePage`：用 `@source`、`@episodeUrl` 替换 URL/query，生成最终剧集页地址。
   - 同一剧集多个线路时保留备用线路（`alternateURLs`），主线路失败仍可切换。
3. **XPath 兼容**
   - 以 `/` 开头的规则在容器内求值时转换为相对路径（`.//` / `./`）。
   - 支持 `|` union、`following-sibling`、`contains(@class, ...)`、`starts-with(@id, ...)`。
   - `searchResult` 可能不是 `<a>`，要向上/向下找最近的 href；支持协议相对 URL、查询参数相对 URL、绝对 URL。
4. **规则加载**
   - `searchURL`/`searchList` 为空但 `searchMode = api` 的规则不再直接丢弃。
   - `baseURL` 为空时用搜索请求的 origin；`baseURL` 末尾斜杠不重复。
   - 单条规则缺字段/JSON 错误/网络失败只隔离该规则，不影响其他源。
   - `antiCrawlerConfig.enabled = true` 仍可尝试，只在源详情提示「可能有反爬验证」，不静默禁用。
   - `useLegacyParser`、`muliSources`、`useWebview` 等未知字段不导致规则失败。

### 4.3 实现建议

- 新增 `KazumiRuleModels`（Codable 或 `[String: Any]` 解析）与 `JSONPath` 轻量求值器，避免引入第三方依赖。
- `OnlineHTTPClient` 增加 `postJSON` / 通用 `request(method:url:headers:body:)`，复用超时、大小限制、编码逻辑。
- `OnlineSubject` 增加可选的 source token / API 页面地址；`OnlineEpisode` 已有 `alternateURLs`。
- 解析器按 engine + mode 分支，保持 `OnlineMediaResolver` 对外 API 不变。
- 日志记录「规则已加载/已跳过原因」，源管理页显示支持状态，便于用户判断。

### 4.4 测试与验收

- 用本地规则 fixture 覆盖：LMM（GET API + XPath 剧集）、TvTFun（GET API + XPath）、sorani（GET + nested）、xfdmnext（POST JSON + nested）、giriGiriLove（empty sourceTemplate + delimited）。
- 单元测试覆盖 JSONPath、分隔符解析、sourceTemplate、相对 XPath、union、URL join、单源失败隔离。
- 不跑真实站点；用户手工用真实源搜索/播放。
- 源管理页至少能显示新增支持的源数量；不支持的规则给出明确原因，不静默消失。

## 5. 任务 3：弹幕列表

### 5.1 入口

`弹幕设置 → 弹幕列表` 不再空实现；打开一个独立的非模态窗口（建议 560×520），播放器关闭时自动关闭。

### 5.2 UI

- 顶部：当前匹配弹幕库名称/集数；弹幕总数、已过滤数。
- 搜索框：按文本过滤；清空恢复全部。
- 表格：时间（mm:ss）、弹幕文本；被过滤/屏蔽的条目使用删除线或次要色。
- 底部：当前显示条数 / 总条数。
- 双击条目跳转到对应播放时间；右键菜单至少包含：
  - 复制弹幕文本
  - 跳转到这个时间
  - 屏蔽该弹幕文本（复用现有 `FilterDanmaku` 文本过滤）
- 若模型不支持单条删除/按用户屏蔽，不要伪造；可在后续任务补模型能力。

### 5.3 实现

- `PlayerDanmakuModel.danmakuList` 已提供数据；按 `originAppearTime ?? rawComment.time` 排序。
- 通过 delegate/closure 把「跳转时间」回传给 `PlayerViewController`，调用现有 `playerModel.changePosition`。
- 列表窗口复用 `TableView`/`ScrollView` 基础组件；保留播放器焦点，不阻塞播放。
- 空态显示「当前没有弹幕」；未匹配时显示「尚未关联弹幕库」。
- 增加 `AccessibilityID.Player.danmakuList*`。

### 5.4 验收

- 菜单能打开窗口，列表按时间排序，搜索有效，双击跳转，右键复制/屏蔽有效。
- 未匹配、空列表、加载中都有明确状态。
- 播放器关闭后列表窗口关闭，无循环引用。
- macOS Debug 编译通过；弹幕排序/过滤逻辑可抽纯函数并加单测。

## 6. 任务 4：播放器右下角按钮可见性

### 6.1 问题

播放器底部右侧的「选集」「弹幕配置」「视频设置」「弹幕设置」等文字按钮，在深色半透明控制条上使用默认 `NSButton` 外观，文字/边框与背景对比不足，实际看起来像透明按钮。

### 6.2 修复

- 统一为播放器控制条的紧凑文字按钮：
  - 白色/高对比文字，12pt，`.semibold` 或 `.medium`；
  - `isBordered = false`，透明背景；
  - 悬停时显示半透明白色胶囊背景；
  - 统一的水平 padding（8–10pt）和最小宽度，避免文字被压缩消失。
- 图标按钮（截图）保持白色 tint，悬停高亮。
- 在 960pt 和 1280pt 播放器宽度下检查：所有按钮可见、不重叠、不越界。
- 如宽度不足，最后两个次要按钮折叠到「更多」菜单，不允许直接消失。
- 保留现有 accessibility identifier/label，并补 tooltip。

### 6.3 验收

- 截图确认四个文字按钮清晰可见，深浅色背景都可读。
- 点击行为不变；无 Auto Layout 冲突日志。
- macOS Debug 编译通过。

## 7. 任务 5：首页播放列表入口

### 7.1 行为

首页快捷操作「播放列表」不再只弹 toast，而是：

1. 已有播放器窗口：激活播放器窗口并直接弹出播放列表 popover。
2. 没有播放器窗口：创建一个空播放器窗口（黑色画面 + 「打开文件」提示），然后弹出播放列表 popover。
3. 播放列表为空时显示「播放列表为空」和「打开文件」按钮；打开文件后列表自动更新。

### 7.2 实现

- `WelcomeOverviewViewController` 的 playlist tile 改为调用 `router?.openPlayerPlaylist()`。
- `MainViewController` 增加 `openPlaylist()`：复用已有 `playerWindowController`，没有则创建空播放器。
- `PlayerViewController` 需要支持无媒体状态；`PlayerWindowController` 负责窗口复用和聚焦。
- 播放列表 popover 复用 `PlayerListViewController`；增加「打开文件」入口；选择/删除逻辑不变。
- 不允许每次点击创建第二个播放器窗口。

### 7.3 验收

- 无播放器点击「播放列表」：播放器窗口 + 空列表 popover 出现。
- 有播放器：同一窗口聚焦并弹出列表，不新建窗口。
- 空列表打开文件后条目出现；选择/删除正常。
- 播放器关闭再点，行为一致。
- macOS Debug 编译通过；窗口生命周期无循环引用。

## 8. 任务 6：Now Playing 替代右上角搜索框

### 8.1 目标

主窗口右上角不再显示全局搜索框，改为「正在播放」卡片。搜索仍可通过「功能 → 搜索…」菜单和「搜索」一级导航使用。

### 8.2 UI

- 位置：顶栏右侧，用户区左侧，宽度约 200pt（最小 160pt）。
- 内容：
  - 22×22 圆角封面（无封面时用音符/播放占位）；
  - 标题一行，11.5pt semibold 白色；
  - 副标题一行，10pt 次要色（剧集名/文件名）；
  - 右侧播放/暂停按钮；
  - 底部 1.5pt 进度线。
- 无播放器时保持占位「未在播放」，不可点击，避免导航宽度跳动。
- 点击卡片激活播放器窗口；点击播放/暂停只切换播放状态，不抢焦点。
- 悬停高亮；tooltip 显示完整标题。

### 8.3 状态与 macOS 集成

- 新增 `PlayerNowPlayingCenter`（或等价）单例，由 `PlayerViewController` 在媒体变化、播放状态变化、时间变化时更新；时间更新节流到 1 秒，禁止轮询。
- 顶栏通过 Notification 或轻量观察者更新，不直接持有播放器。
- 同步 `MPNowPlayingInfoCenter`：标题、副标题、时长、当前时间、播放状态、封面（若可得）。
- 注册 `MPRemoteCommandCenter` 的 play/pause/next/previous/seek；播放器关闭时清空 nowPlayingInfo。
- 移除 `MainShellSearchView` 及顶栏搜索回调；保留 `功能 → 搜索…` 菜单、`AccessibilityID.MainShell.searchField` 常量可删除或标记废弃，避免旧脚本引用时崩溃。

### 8.4 验收

- 顶栏无搜索框；启动时显示「未在播放」。
- 打开视频后卡片出现标题/副标题/进度/播放状态；暂停、继续、切换下一集、关闭播放器同步更新。
- 点击卡片聚焦播放器；播放/暂停按钮可用。
- Control Center / 媒体键能看到并控制当前播放（至少 play/pause）。
- 960pt 和 1100pt 窗口下顶栏不重叠。
- macOS Debug 编译通过；截图检查。

## 9. 任务 7：会员中心参考 Windows 重做

### 9.1 参考

Windows `MembershipWindow.xaml`：

- 900×680，固定大小，居中；
- 左侧会员介绍 Markdown + 当前功能说明；
- 右侧 350pt：头像/昵称/会员状态 + Tab（在线支付 / 使用礼品码）；
- 支付方式为微信/支付宝卡片，会员时长为列表，去支付按钮；
- 支付激活后整个表单替换为二维码面板（渠道、标题、金额、212×212 二维码、有效期、状态、取消/网页支付）；
- 礼品码：输入框 + 粘贴 + 兑换，底部购买礼品码/兑换记录链接；
- 右下角关闭按钮。

### 9.2 macOS 布局

- 窗口固定 900×680（`titled, closable`，不 resizable），居中；保留现有登录门禁和 `present(feature:)` 异步关闭语义。
- 外层 24pt 边距；左侧约 500pt，右侧 350pt，中间 1pt 分隔线。
- 左侧：
  - 标题「弹弹play 会员」22pt；
  - 若有 `MembershipFeature`，顶部显示「会员功能：「XXX」」+ 简短说明；无 feature 时隐藏；
  - 会员介绍 Markdown 滚动区；使用现有 markdown 渲染能力，不新增依赖。
- 右侧：
  - 用户卡：60pt 头像、昵称 16pt semibold、@用户名 12pt 次要色、会员状态 12pt semibold（生效至日期 / 未开通提示）；
  - `NSSegmentedControl` 两个 tab：在线支付 / 礼品码；
  - 支付 tab：支付渠道卡片（微信/支付宝 logo，选中用主色边框/浅色背景）；会员时长列表（名称 + 价格，单选）；「去支付」主按钮；「查询会员购买记录」链接；
  - 礼品码 tab：居中输入框（等宽字体、最多 20 字符）、粘贴图标按钮、兑换按钮；底部「购买礼品码」「查询会员兑换记录」链接；
  - 底部右侧「关闭」。
- 支付面板激活时隐藏支付表单，显示二维码面板；请求中显示遮罩 + spinner，避免重复点击。
- 会员介绍和记录列表使用滚动区；窗口固定大小下不能裁切主操作。

### 9.3 操作逻辑

- 未选择渠道/时长时禁用「去支付」。
- 下单/轮询期间禁用渠道、时长和支付按钮；显示「正在创建订单…」「等待支付…」。
- 关闭支付面板只停止轮询，不取消服务端订单；提示「如已付款请勿重复支付」。
- 支付成功：刷新 `/user/me`，更新会员状态，显示成功文案；不重复创建订单。
- 支付失败/超时：回到表单，保留已选渠道/时长，显示内联错误；不要用阻塞式 alert 打断。
- 切换渠道/时长时，如果已有二维码，先停止本地轮询并清空当前订单展示，再回到表单。
- 礼品码兑换成功：刷新会员状态、清空输入、刷新兑换记录；失败保留输入并显示原因。
- 购买记录/兑换记录改为 sheet 或独立小窗口，不在主窗口里堆两个表格。
- 关闭窗口时保持现有「是否完成购买」返回值逻辑，支付/兑换成功后仍能正确解除付费墙。

### 9.4 资源与本地化

- 微信/支付宝 logo 从 Windows `Resources/wechat.png`、`Resources/alipay.png` 复制到 Mac Assets（或使用等价的本地资源），不引用外部 URL。
- 保留所有现有 `AccessibilityID.Membership.*`；新增 tab/渠道卡/时长列表/记录链接的标识。
- 新增字符串写入 `Localizable.xcstrings`，中英双语。

### 9.5 验收

- 900×680 窗口截图：左右分栏、用户卡、两个 tab、支付表单、二维码面板、礼品码页都无裁切/重叠。
- 支付表单 → 二维码 → 取消 → 表单；支付成功刷新状态；重复点击不会重复下单。
- 礼品码兑换/记录链接可用；关闭按钮位置正确。
- macOS Debug 编译通过；不跑真实支付，支付状态用现有 view model 的模拟/既有路径做 UI 检查。
- 不改变 `MembershipWindowController.present` 的对外语义。

## 10. 验证、提交与合并

每个 worktree 完成标准：

1. `bash scripts/build-mac.sh Debug` 成功；
2. 涉及共享文件时追加 `bash scripts/build-all-platforms.sh`；
3. 有纯逻辑改动的加/改 `Mac/AniXPlayerTests`，`bash scripts/test-mac.sh Debug` 通过；
4. 新增/删除 Swift 文件只用 `ruby scripts/xcode_project.rb mac add|remove <path>`，不手改 pbxproj；
5. 截图/尺寸检查只针对本任务页面，不跑真实联网/支付；
6. 提交信息：`feat(mac): ...` / `fix(mac): ...`，提交后报告分支、commit、验证结果、已知限制。

合并顺序（减少冲突）：

1. 任务 7（会员，独立）
2. 任务 4（播放器按钮，独立）
3. 任务 3（弹幕列表）
4. 任务 5（播放列表）
5. 任务 6（Now Playing）
6. 任务 1（详情路由）
7. 任务 2（Kazumi，独立）

合并时 `project.pbxproj` 冲突统一以当前主分支为底，缺失文件用 `xcode_project.rb add` 重新登记；共享文件冲突逐段保留两边新增逻辑，不整体覆盖。
