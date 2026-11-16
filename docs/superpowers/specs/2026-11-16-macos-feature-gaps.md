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
| 本地媒体库 | 🟡 MVP | SQLite、扫描、增量、哈希匹配、海报墙、搜索/筛选、播放；缺缩略图/时长/元数据/文件夹管理/匹配修正 |
| 下载中心 | 🟡 MVP | HTTP 下载、Transmission RPC、任务持久化、暂停/继续/删除；缺内置 BT、自动下载/RSS、后台、通知、文件选择 |
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

### 2.2 分阶段实现

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

- HTTP：真实 `URLSessionDownloadTask`，暂停/续传/删除、2xx 校验、文件名冲突。
- BT：真实 Transmission JSON-RPC；未检测到 daemon 时明确提示。
- 任务 SQLite 持久化、启动恢复、进度/速度/ETA、添加/设置 sheet、完成后播放。
- 不是纯壳，但离 Windows 全量差距大。

### 3.2 待补

1. 任务文件选择（BT 多文件）、优先级、限速、做种/分享率。
2. 自动下载/RSS/资源节点规则。
3. HTTP 退出后后台继续（需要 helper/daemon 或限制说明）。
4. 系统通知、完成/失败提示、失败重试与错误分类。
5. 边下边播：Transmission RPC 不做内容服务；需要本地 Range 代理 + 文件可读，或内置引擎。
6. **BT 内核决策**：外部 Transmission（现状）vs 捆绑 libtorrent/Transmission（GPL/体积/签名/公证）。未决策前不伪装「内置 BT」。

## 4. 本地媒体库

### 4.1 现状

- 真实 SQLite、文件夹 bookmark、扫描/增量/取消/进度、前 16MB MD5 + `/match`、海报墙、搜索/筛选、独立播放器播放。
- 缺的是「媒体库体验」而不是数据库骨架。

### 4.2 待补

1. 缩略图/时长/分辨率：AVFoundation 抽帧，缓存到磁盘；失败回退占位图。
2. 文件夹管理：移除文件夹（只删索引）、重新扫描、缺失文件清理、权限失效重选。
3. 匹配修正：手动选番剧/剧集、批量匹配、取消匹配、匹配来源标记。
4. 元数据：番剧分组、季/集、文件名解析、排序、重复文件提示。
5. 批量操作：批量匹配/重命名/移出库；重命名需模板与预览。
6. 远程源扩展（SFTP/Plex/OneDrive 等）暂不做，保留现有 SMB/WebDAV/FTP/Emby/Jellyfin。

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

## 6. 截图 / GIF 动图（会员）

### 6.1 现状

- 静态截图已完成：播放器截图按钮、预览、保存目录 bookmark、权限失败引导。
- `MembershipFeature.gifExport` 已存在，但没有 UI/实现。

### 6.2 实现建议

1. 播放器新增「导出动图」入口（截图按钮长按菜单或独立按钮）。
2. 参数：时长 1/2/3/5 秒、帧率 5/10/15、最大宽度 480/640。
3. 本地文件优先用 `AVAssetImageGenerator` 抽帧；流媒体/不支持格式回退播放器缩略图接口或明确提示。
4. `CGImageDestination` 写 GIF（循环、帧延迟）；后续可加 WebP/APNG。
5. 保存到截图目录，复用 `SnapshotLocation` 的 security-scoped 逻辑；完成提示/打开 Finder。
6. 门禁：`EntitlementGate.require(.member, feature: .gifExport)`；静态截图保持免费。
7. 失败/取消/无权限状态完整；导出期间不阻塞播放。

## 7. 优先级建议

| 顺序 | 工作 | 理由 |
|---|---|---|
| 1 | 番剧详情页重做 | 纯 UI、见效快、无外部依赖 |
| 2 | 截图/GIF（会员） | 自包含、付费卖点、可独立验收 |
| 3 | 媒体库体验补齐 | 已有骨架，补缩略图/管理/匹配修正 |
| 4 | 下载中心补齐 | 先补 UX/文件选择/通知；BT 内核单独立项 |
| 5 | 在线观看阶段 A/B | 源配置→解析→串流，先直链后嗅探 |
| 6 | 在线观看阶段 C/D | WKWebView 嗅探、源管理、合规 |
| ➖ | 远程访问 / 投屏 | 暂不做 |

## 8. 验收边界

- 每阶段必须 macOS Debug 编译通过；共享代码改动再跑 iOS/tvOS。
- 在线源不内置第三方站点；用户导入/配置，失败不伪造结果。
- BT 未配置/未安装时继续明确提示，不创建假任务。
- 会员门禁以服务端权益为准；GIF/在线观看/嗅探均走统一 `EntitlementGate`。
