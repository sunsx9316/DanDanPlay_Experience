# macOS 功能差距与补齐计划

> 状态：现状盘点（2026-11-16）
> 范围：macOS；iOS/tvOS 不变。远程访问、投屏明确暂不做。
> 口径：以「用户可用」而非「代码存在」判断；P0–P7 已完成，本文件记录 P8 起的缺口。

## 1. 现状总览

| 领域 | 状态 | 说明 |
|---|---|---|
| 登录 / 会员 / 支付 | ✅ 基本完成 | OAuth、强制登录、Bearer、会员中心、微信二维码/支付宝、礼品码、订单 |
| 欢迎页 / 内容发现 | ✅ 基本完成 | 首页、公告、未看、时间表、排行榜、继续播放 |
| 搜索 / 番剧详情 | 🟡 详情布局待重做 | 高级搜索、标签、剧集、收藏/评分/短评已有；详情页视觉与信息层级乱 |
| 播放 / 弹幕 | 🟡 基础完成 | 本地/网络文件、VLC/MPV、弹幕拉取/发送/过滤、静态截图；缺 GIF、命名播放列表、串流封装 |
| 本地媒体库 | 🟡 MVP（骨架真实） | SQLite、扫描、增量、哈希匹配、海报墙、搜索/筛选、播放都是真的；缺匹配修正、缺失文件管理、剧集分组、缩略图/时长 |
| 下载中心 | 🟡 MVP（引擎真实） | HTTP 下载、Transmission RPC、任务持久化、暂停/继续/删除都是真的；BT 依赖外部 daemon，缺后台/通知/文件选择/自动下载 |
| 截图 / GIF | 🟡 截图免费；GIF MVP | 静态截图已有；GIF 已加“导出 3 秒动图”（3s/10fps/480px，会员门禁，本地文件） |
| 在线观看 | ❌ 仅搜索占位 | 当前只能搜索并打开浏览器；无 animeko/kazumi 源、无解析、无嗅探、无流播放 |
| 用户中心 | 🟡 部分 | 有会员状态/订单/兑换；缺资料编辑、昵称、邮箱/密码入口 |
| 弹幕生态 | 🟡 部分 | 有发送/过滤/补充弹幕；缺举报、云端过滤、第三方源 |
| 系统集成 | 🟡 部分 | 文件关联、单实例；缺菜单栏、Now Playing、全局快捷键 |
| 远程访问 / 投屏 | ➖ 暂不做 | 按当前决策跳过 |

## 2. 在线观看

### 2.1 现状

- `WelcomeOnlineViewController` 只做关键词搜索、结果列表、剧集列表、浏览器打开/复制链接。
- 播放器底层（VLC/MPV）本身能打开 http(s) 流，但没有通用「远程 URL File」封装，也没有把 headers/cookies 传给它。
- 没有 animeko/kazumi 配置读取、缓存、规则解析、网页嗅探。
- `MembershipFeature.onlinePlayback` 与 `.mediaSniffer` 门禁枚举已存在，但没有业务接线。

### 2.2 审计结论（2026-11-16）

- 当前页面是「弹弹play 剧集搜索 + 浏览器搜索页跳转」，不是在线播放；剧集行只打开作品级网页，不解析流。
- 播放器内核（VLC/MPV）可以接收 http/https/m3u8；现有 Emby/PC/SMB 已经用远程 URL 播放。但缺少通用 `OnlineEpisodeFile`、请求头注入、虚拟文件名/弹幕匹配、在线播放列表重解析。
- Mac 没有 animeko/kazumi 的模型、缓存、解析、嗅探；WKWebView 仅用于 OAuth。
- Windows 参考链路：源配置（Animeko `css1.json`；Kazumi `index.json` + rules）→ 多源并行搜索 → 作品/线路/剧集解析（CSS→XPath / XPath）→ WebView2 嗅探 + HTTP 正则回退 → `LoadEvent`（URL + headers + 虚拟文件名）→ VLC/MPV 本地代理注入请求头 → 用「作品名 + 剧集名」空哈希虚拟文件匹配弹幕。
- Windows 在线观看/嗅探是 **15 次/月试用 + 会员无限**；Mac 目前只有登录检查，没有试用计数；若直接接 `EntitlementGate` 就是纯会员制。
- 最大风险：WKWebView 没有 WebView2 的全量网络请求拦截能力，`URLProtocol` 也拦不到 WKWebView/VLC/MPV；动态页面嗅探必须用 JS hook + DOM/Performance 扫描重写，成功率低于 Windows。
- 请求头/ Cookie 不能只塞进 `MPVMedia.options`（当前 wrapper 不读取）；需要给 `File` 增加 header 能力，或在 VLC `addOptions` / MPV `http-header-fields` 中注入，必要时用 GCDWebServer 做本地代理。
- 弹幕匹配不能用空 MD5 当全局缓存键；要用稳定 `fileId`（源 + 剧集页 URL）/虚拟文件名，并让 `MatchNetworkHandle` 支持无扩展名、空哈希模式。

### 2.3 分阶段实现

**阶段 A：源配置与搜索/解析（纯网络 + 模型）**

1. `OnlineSourceModels`：统一 animeko/kazumi 源；字段对齐 Windows `OnlineMediaSource`。
2. `OnlineSourceStore`：读取/更新/缓存：
   - animeko：单一 `css1.json`，7 天 TTL，失败回退本地缓存；
   - kazumi：`index.json` + `rules/<name>.json`，按版本增量更新；
   - 缓存目录 `Application Support/AniXPlayer/OnlineSources/`；
   - 数据源 URL 可配置；默认不内置第三方源，避免分发/合规问题。
3. `OnlineHTMLResolver`：`XMLDocument(.documentTidyHTML)` + CSS→XPath（移植 Windows 的基础转换器）＋原生 XPath（kazumi）；JSONPath 先支持常用路径。
4. 搜索、频道/剧集解析、视频地址正则、嵌套 URL、headers/cookies，按 Windows `OnlineMediaResolver` 移植。
5. 源优先级、并发搜索、请求间隔、超时与失败隔离。

**阶段 B：串流播放**

1. 新增 `RemoteURLFile: File`：URL、标题、VLC/MPV media、HTTP Range、headers/cookies；禁用文件哈希/删除。
2. `MainViewController` 增加 `openRemoteURL(...)`；播放器加载后跳过本地文件匹配，使用在线剧集信息加载弹幕。
3. 失败回退：直链失败 → 嗅探 → 仍失败则打开浏览器。

**阶段 C：WKWebView 嗅探**

1. 离屏 `WKWebView` 加载剧集页，注入脚本捕获：
   - `performance.getEntriesByType('resource')` 中的 m3u8/mp4；
   - `fetch`/XHR/`<video>` 的 URL；
   - 跳转/iframe 嵌套。
2. 过滤广告/低清/重复 URL，按扩展名与 Content-Type 排序。
3. 嗅探窗口 UI：地址栏、加载状态、候选流列表、播放/复制。
4. 动态页面、验证码/反爬给出明确错误，不伪造结果。

**阶段 D：UI 与运营**

- 在线页改造：源筛选、并发搜索、结果/剧集、播放、搜索历史、上次观看。
- 源管理 sheet：animeko URL、kazumi URL、更新、清缓存、启用/禁用、优先级。
- 门禁：搜索可登录后开放，播放走 `onlinePlayback` 会员门禁；嗅探走 `mediaSniffer`。
- 合规提示：第三方源由用户提供/导入，不随 App 分发。

## 3. 下载中心

### 3.1 现状

不是纯壳，引擎/数据库/主流程都是真的：

- HTTP：真实 `URLSessionDownloadTask`，进度/速度/ETA、2xx 校验、文件名冲突、暂停/续传/停止/删除。
- BT：真实 Transmission JSON-RPC（session/torrent-add/get/start/stop/remove、409 重试、magnet/metainfo），未检测到 daemon 时明确提示且不落库。
- SQLite 持久化、启动恢复、添加/设置 sheet、完成文件播放、窗口中关闭继续下载。

### 3.2 关键缺口（审计补充）

1. **BT 开箱不可用**：依赖外部 `transmission-daemon`；没有内置引擎，也没有一键安装/启动/连接测试。发布前必须决策：外部 daemon 第一等公民，或捆绑 libtorrent/Transmission。
2. **HTTP 退出 App 即停止**：普通 URLSession，不是 background session；重启后从头下载。UI 必须明确说明，或做 background session/helper。
3. **无系统入口**：未注册 `magnet:`/`ddplay:`/`.torrent`，浏览器磁力链接、Finder 种子文件无法直接进 App。
4. **无完成/失败通知**：窗口关闭后用户不知道结果；无 Dock badge/声音。
5. **BT 文件选择缺失**：RPC 解析了 `isWanted` 但未使用；不能选文件、看单文件进度、设优先级。
6. **队列不公平**：最大并发只约束 HTTP；所有 BT 任务同时 start；无优先级/全局暂停。
7. **边下边播是 best-effort**：只打开已存在且 >20MB 的文件，没有本地 Range 代理/piece 感知；多文件只播最大文件，不按剧集顺序。
8. **状态/竞态**：BT 的暂停/停止都是 `torrent-stop`；`sequentialDownload` 被旧版拒绝后仍可能显示 streaming；completed 任务可再次开始；启动/暂停/删除存在短竞态。
9. **无自动下载/RSS/资源规则**；无任务重命名/复制源/历史。
10. **默认保存目录在隐藏的 Application Support**，不适合普通用户。

### 3.3 建议顺序

1. BT 策略与首次使用引导（检测/安装/启动/连接测试/登录启动）。
2. 系统入口 + 队列/状态正确性 + 完成通知。
3. 文件选择、播放顺序、真实边下边播（或移除该承诺）。
4. 后台下载、错误恢复/重试、默认目录迁移。
5. RSS/自动下载/资源节点。

## 4. 本地媒体库

### 4.1 现状

不是壳，数据库/扫描/匹配/播放都是真的：

- SQLite + 文件夹 security-scoped bookmark、递归扫描、增量扫描、取消/进度、前 16MB MD5 + `/match`、海报墙、搜索/筛选、独立播放器播放、移除文件夹（只删索引）。
- 缺的是「媒体库体验」和「匹配控制」，不是数据骨架。

### 4.2 关键缺口（审计补充）

1. **匹配修正缺失**：重新匹配只处理未匹配文件；多候选/失败都丢弃；不能手动选番剧/剧集、不能改错配、不能取消匹配。
2. **重扫会清空匹配**：`makeScanned` 总是写 `isMatched=false`，文件大小/mtime 变化或缺失恢复后必须重新匹配。
3. **缺失文件不可见**：DB 有 `isMissing`，UI 没有过滤器/计数/清理/定位。
4. **重复/嵌套文件夹**：路径唯一但 folderId 会被最后一次扫描覆盖；父子文件夹同时添加会导致计数/筛选不稳定。
5. **无剧集分组**：一个文件一张卡；12 集会显示 12 张海报，播放顺序是 DB 顺序而不是剧集顺序。
6. **扫描取消不彻底**：递归枚举和 16MB hash 读取期间不检查取消；大目录/网络卷可能长时间无响应。
7. **无缩略图/时长/分辨率/元数据**；只有远程海报或扩展名占位。
8. **无排序 UI**（模型支持 title/fileName/fileSize/path，但 UI 固定 title）。
9. **无批量/多选**：点击卡片直接播放，不能批量匹配/移出/定位/重命名。
10. **性能/并发风险**：全量查询与全量 reload；播放前在主线程对全部文件做 `fileExists`；扫描/匹配状态可能互相覆盖；hash 等待信号量有潜在数据竞争。
11. **权限失效无重选引导**；文件夹菜单在扫描中仍可操作，存在 FK/竞态风险。

### 4.3 建议顺序

1. 匹配修正 UI + 重扫保留元数据 + 缺失文件管理 + 重复/嵌套处理。
2. 剧集分组/播放顺序 + 彻底取消 + 排序/多选/批量。
3. 缩略图/时长/分辨率 + 性能（分页/快照/后台 stat）。
4. 文件夹重扫/定位/权限重选/FSEvents。
5. 远程源暂不做，保留现有 SMB/WebDAV/FTP/Emby/Jellyfin。

## 5. 番剧详情页布局

### 5.1 现状问题

- 顶部 header 固定 100×120 封面 + 文本块，宽窗口下留白大、窄窗口下标题/标签被挤压。
- 收藏按钮与元数据箭头用绝对 trailing 约束，标题过长时冲突。
- 详情用 `NSCollectionView` 分 section，各 section 高度依赖手动计算；容易出现空白、裁切、滚动跳动。
- 缺简介、播出信息、操作区（播放/追番/评分）、加载/空/错误态。

### 5.2 重做方向

- Header：160×224 封面 + 标题/原名/评分/标签/状态 + 简介 + 操作按钮（收藏、追番、播放）。
- 元数据：年份/季度/类型/集数/时长等 key-value 网格。
- 剧集：季度选择 + 网格/列表切换，支持已看/未看状态。
- 评论/相关：分段或 Tab，避免所有内容堆在一个滚动流。
- 用 `NSScrollView + NSStackView` 替代手动 section 高度计算；每个 section 自撑高。
- 统一 20pt 边距、12pt 区块间距、卡片圆角与分隔线；暗色模式验证。

### 5.3 本轮已做（2026-11-16，b4d62e3）

- Header 高度 170 → 250，封面 136×190，标题 25pt 两行，补原名/类型/集数/标签/简介/评分。
- 关注按钮与「详细信息 ›」拆开；点击 header 不再误跳元数据页。
- 追番卡片改为 `controlBackgroundColor` + 边框，去掉灰色块；高度 170。
- 分集/短评入口行高度 60 → 72，补 subtitle trailing 约束。
- 关联/相似从固定 2 列改为按宽度 4/3/2 列，修正高度估算（+34 而非 +26）。
- 详情窗口标题实时更新；关闭横向滚动条、补布局刷新；section 间距 8。
- 1000pt 与 500pt 宽度截图检查通过。

### 5.4 审计补充（仍需处理）

- 详情页会被推入 **490pt 固定不可缩放**的首页窗口，同时也会出现在 900/1000pt 窗口；建议统一给详情一个最小 860×620 的独立窗口，或至少提高首页窗口最小宽度。
- 当前是 6 个 item 的单 section `NSCollectionView`，高度手算；建议后续改为 `NSScrollView + NSStackView` 卡片，彻底去掉 `collectionViewContentSize` 手动 frame 计算。
- 缺加载/错误/空态（现在失败只显示 2 秒 HUD）；缺重试。
- 短评列表固定 80pt 会裁切长评论；分页失败会跳页；首屏不足时不会自动加载下一页。
- 元数据页是扁平固定高度列表，缺分组/换行/复制反馈。
- 无 `AccessibilityID.BangumiDetail`；分集/短评行只有 gesture，键盘/VoiceOver 不可操作。
- `.lightGray` 字幕色在浅色模式对比度不足，应统一 `.secondaryLabelColor`。
- 关联/相似仍建议改成 WelcomeShell 的海报网格/横向 rail，而不是嵌套 collection view。

## 6. 截图 / GIF 动图（会员）

### 6.1 现状

- 静态截图已完成：播放器截图按钮、预览、保存目录 bookmark、权限失败引导。
- **GIF MVP 已实现（2026-11-16）**：功能菜单「导出 3 秒动图」，从当前播放位置截取 3 秒、10fps、最大 480px，`AVAssetImageGenerator` + `CGImageDestination`，保存到截图目录并打开 Finder。
- 门禁已接：`EntitlementGate.require(.member, feature: .gifExport)`；静态截图保持免费。
- 首版只支持 AVFoundation 能解码的本地文件；远程流/不支持编码会明确提示。

### 6.2 后续增强

1. **抓帧内核**：当前 MVP 用 `AVAssetImageGenerator`，只支持本地 AVFoundation 能解码的文件；大量 MKV/HEVC/AV1 与网络源会失败。应改为复用 `MPVFrameRenderer` / `MediaThumbnailFetcher` 的无头 MPV 抓帧，AVFoundation 只做本地回退。
2. 选项 sheet：时长 1/2/3/5 秒、帧率 5/10/15、最大宽度 480/640/原尺寸；包含字幕开关。
3. 进度/取消/媒体切换取消；当前 progress 闭包为空，`Task.checkCancellation` 在 GCD 块里没有实际取消路径。
4. 预览与另存为；失败/取消/无权限状态细化（现在只有 2 秒 HUD）。
5. 输出 WebP/APNG；可加片段裁剪（起止时间）与画质档位。会员文案目前写「GIF、WebP 或 APNG」，在实现前要改成实际能力。
6. 弹幕默认不烧录；若产品要求，需离线弹幕合成器，不能依赖屏幕截图。
7. 流媒体/远程源回退或明确提示；避免大内存占用（限制帧数/尺寸/分块编码）。

## 7. 优先级建议

| 顺序 | 工作 | 理由 |
|---|---|---|
| ✅ | 截图/GIF MVP（会员） | 已完成 3 秒 GIF；后续补选项/WebP/APNG/无头 MPV |
| ✅ | 番剧详情页首轮 | header/追番卡片/间距/关联列数已改；完整 stack 重做与加载态仍待做 |
| 1 | 在线观看阶段 A/B | 源配置→解析→串流，先直链后嗅探；最大缺口 |
| 2 | 媒体库体验补齐 | 已有骨架，补匹配修正/缺失/分组/缩略图 |
| 3 | 下载中心补齐 | 先补 BT 引导/系统入口/通知/队列；BT 内核单独立项 |
| 4 | 在线观看阶段 C/D | WKWebView 嗅探、源管理、合规 |
| 5 | 详情页完整重做 | stack 卡片、加载/错误态、490pt 窗口、AX |
| ➖ | 远程访问 / 投屏 | 暂不做 |

## 8. 验收边界

- 每阶段必须 macOS Debug 编译通过；共享代码改动再跑 iOS/tvOS。
- 在线源不内置第三方站点；用户导入/配置，失败不伪造结果。
- BT 未配置/未安装时继续明确提示，不创建假任务。
- 会员门禁以服务端权益为准；GIF/在线观看/嗅探均走统一 `EntitlementGate`。
