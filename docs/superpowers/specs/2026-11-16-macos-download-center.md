# macOS 下载中心 MVP 设计（P7）

> 状态：MVP + 基础能力完善已合并 win-porting；深度完善（后台下载/RSS/优先级/限速/路径映射）已实现（2026-11-16）
> 范围：macOS；iOS/tvOS 不变。
> 背景：Windows 使用 MonoTorrent + DLBT.dll；macOS 没有可直接复用的 BT 内核。

## 1. 目标与边界

目标：

- 统一的下载任务列表：磁力、`.torrent`、HTTP/HTTPS 直链。
- 添加/暂停/继续/停止/删除任务，显示进度、速度、剩余时间、保存路径。
- 任务持久化，重启后恢复。
- 对已下载完成的文件提供“打开/播放/在 Finder 中显示”。
- 对进行中的任务提供有限度的“播放已下载部分”（best effort）。

首期不做：

- 内置 BT 内核、DHT/PT 私人种子优化、做种策略、RSS 自动下载。
- 网页嗅探、云盘离线下载、远程下载服务器管理。
- 边下边播/本地 Range 代理（2026-11-16 明确延后）。

> 2026-11-16 深度完善已补 RSS/自动下载（MVP）、BT 单文件优先级、限速/分享率与远程路径映射；边下边播仍不做。

## 2. 引擎策略

macOS 首期采用 **可插拔下载引擎**：

```text
DownloadEngine (protocol)
├── HTTPDownloadEngine      // URLSession，内置
└── TransmissionRPCEngine   // 连接本机 transmission-daemon，可选
```

- **HTTP/HTTPS**：内置 `URLSessionDownloadTask`，支持取消、断点续传（resumeData）、速度/进度。
- **BT/磁力/.torrent**：通过 Transmission RPC（`127.0.0.1:9091`，可配置）：
  - 用户自行安装 `transmission-daemon`（`brew install transmission`）。
  - App 不捆绑 GPL 二进制；未检测到内核时明确提示安装方式，不伪造任务。
  - RPC 需要处理 `409 Conflict` + `X-Transmission-Session-Id`。
  - `torrent-add` 支持 magnet 与 metainfo(base64)；`torrent-start/stop/remove`；`torrent-get` 轮询状态。
  - 请求 `sequentialDownload`（Transmission 支持时）为边下边播做准备。
- 引擎选择按任务 URL 自动判断；用户可在设置中关闭 BT 集成。

> 发布前需要产品/法务确认：是否随包分发 BT 内核（libtorrent/Transmission/aria2）及其许可证；当前方案不捆绑。

## 3. 数据模型

```text
DownloadTask
  id: UUID
  kind: http | torrent | magnet
  source: String              // URL / magnet / torrent path
  title: String
  savePath: String
  status: queued | downloading | paused | stopped | completed | failed
  progress: 0...1
  downloadedBytes / totalBytes
  downloadSpeed / uploadSpeed
  etaSeconds?
  errorMessage?
  createdAt / updatedAt
  engineTaskID?               // Transmission hash 等
  downloadFilePaths: [String] // 完成后的本地文件
```

持久化：`~/Library/Application Support/AniXPlayer/Downloads.sqlite`（Mac only）。

## 4. UI

窗口约 1000x640：

- 顶部：添加磁力/种子/URL、开始、暂停、停止、删除、排序/筛选。
- 列表：标题、类型、状态、进度条、速度、剩余时间、保存路径。
- 右侧/底部：选中任务详情、文件列表、错误信息。
- 菜单：功能 → 下载中心。
- 空态：没有任务；BT 内核未配置时显示“安装 Transmission/配置 RPC”说明。
- 设置：默认下载目录、最大并发、是否启用 BT、RPC 地址/端口/用户名/密码（密码进 Keychain）。

## 5. 基础能力完善（2026-11-16）

已补：

- **系统入口**：`magnet:` / `ddplay:` URL scheme、`.torrent` 文档类型；
  - AppDelegate 打开/复用下载中心并预填添加 sheet；
  - 本地 `.torrent` 复制到 App Support，避免原文件移动后失效；
  - 下载窗口拖拽 magnet/HTTP/.torrent；
  - 工具栏/菜单“从剪贴板添加”。
- **BT 首次引导**：
  - checking / unavailable / available / error 状态；
  - 检测、重试、复制 `brew install transmission`、Transmission 官网、RPC 设置；
  - 设置内“测试连接”显示 daemon 版本或具体错误；
  - 未检测到 daemon 时添加磁力会引导到设置，不落库。
- **通知**：
  - 完成/失败 UserNotifications，每个状态只通知一次；
  - 点击通知打开下载中心并选中任务；
  - Dock badge 显示活动任务数；
  - 设置可关闭通知。
- **队列/状态**：
  - HTTP + BT 统一最大并发门控；
  - 全部暂停/全部继续；
  - BT waiting/queued 状态稳定轮询，不再重复 `torrent-start`；
  - 按 magnet infohash / torrent hash / URL 去重，重复添加聚焦已有任务；
  - 关闭 BT 集成时暂停活动 BT 任务；
  - 完成任务不能直接再次开始；完成文件丢失显示缺失并禁用播放；
  - HTTP 标题从 Content-Disposition/最终 URL 更新；
  - 无实质变化的轮询不再强制 `updatedAt`/整表刷新；
  - 无扩展名完成文件按 UTType/大小兜底播放；
  - 多文件种子“播放”按自然顺序打开全部视频；
  - 启动/暂停/删除竞态用 token 防护；
  - SQLite 不可用时禁止添加，避免内存任务；
  - BT 详情文件 wanted/unwanted 勾选 + 单文件进度。
- **UI/设置**：
  - 默认目录改为 `~/Downloads/AniXPlayer`（不迁移旧任务）；
  - “打开下载文件夹”；
  - 空态/错误态/任务错误详情；
  - 新增 `download.*` AX 标识。

仍未做：

- 边下边播/本地 Range 代理（继续显式延后）；
- 内置 BT 内核（仍依赖外部 transmission-daemon）；
- App 被系统/用户结束后由 macOS 自动重新拉起并继续 HTTP 下载（当前需用户再次启动 App 才会接管后台任务）；
- RSS 资源站点规则/网页嗅探、任务重命名/历史、做种状态专属 UI；
- 远程 `.torrent` URL 的 hash 预取失败时仍回退到 URL 去重（见第 10 节）。

## 6. 边下边播

- BT：任务开始时请求 sequential download；当第一个视频文件已有可读数据且播放器能打开时，允许“边下边播”。失败时提示“下载完成后播放”。
- HTTP：直接播放本地临时文件只有在容器格式支持增长写入时才可用；首期标记为实验性。
- 不在任务未开始时声称支持边下边播。

## 7. 测试

- URL 解析：magnet（btih/sha1/DN/TR）、`.torrent` URL、HTTP 直链、非法输入。
- 任务状态机：queued → downloading → paused/stopped/completed/failed 的合法迁移。
- Transmission RPC：409 session id、torrent-add/get/start/stop/remove 的请求与响应解码。
- SQLite CRUD / 重启恢复。
- HTTP 下载：URLProtocol stub 的进度/取消/resumeData（纯逻辑层）。
- UI/AX：窗口、添加、任务行、空态；BT 未配置提示。

## 8. 风险

1. **没有内置 BT 内核**：开箱即用性不足；需要产品决策（捆绑 libtorrent/aria2 或依赖外部 Transmission）。
2. **边下边播**：不同容器/播放器对增长文件支持不一致，首期只能 best effort。
3. **RPC 凭据安全**：密码必须进 Keychain，不能写 UserDefaults/日志。
4. **许可证**：若后续捆绑 GPL 下载器，需要重新评估分发方式。

## 9. 实现结果（2026-11-16）

- 新增 `Mac/AniXPlayer/Features/Download/`：任务模型、SQLite 持久化、HTTP 引擎、Transmission RPC 引擎、管理器、窗口、添加/设置 sheet。
- HTTP：URLSessionDownloadTask，暂停保留 resumeData、停止删除、2xx 校验、文件名冲突处理；macOS 12/13 无 resumeData API 时从头下载。
- BT：默认 `127.0.0.1:9091`，409 session id 自动重试，magnet/metainfo add、get、start/stop/remove；`sequentialDownload` 不支持时自动回退。
- 未检测到 Transmission 时不落库、不伪造任务，显示安装/重试提示。
- RPC 密码优先 Keychain；Debug 回退 0600 文件，避免未签名构建弹钥匙串。
- 菜单：功能 → 下载中心…；AX 标识 `download.*`。
- 2026-11-16 基础完善：系统入口、BT 引导、通知、队列/去重、缺失文件、文件选择、多文件顺序播放、默认目录与 UI 状态。
- 验证：DownloadTests 30 个通过；macOS/iOS/tvOS Debug 构建通过；应用内 HTTP 512KB 下载完成、任务详情/删除正常；`open magnet:...` 可打开并预填添加 sheet；BT 未安装时提示与引导正常。
- 限制：真实 Transmission/BT 未联调；App 退出后 HTTP 任务不后台继续；未实现边下边播；发布前仍需决定是否捆绑 BT 内核。

## 10. 深度完善（2026-11-16）

### 10.1 HTTP 后台下载

- HTTP 引擎改用 `URLSessionConfiguration.background(withIdentifier:)`（标识为 `bundleID + ".download.http"`）。关闭下载窗口后任务继续；App 运行时由后台 session 接管。
- 启动时先登记 SQLite 中的任务，再创建后台 session 并 `getAllTasks`：
  - 系统里仍在运行的任务按 `taskDescription`（任务 UUID）重新映射为下载中，不重复启动；
  - App 退出期间已完成的任务，通过 `knownTasks` 快照补建 Activity，移动临时文件并只发一次完成通知；
  - 数据库已删除的遗留任务取消并清理。
- 进度、暂停/继续/停止/删除、resumeData 持久化与清理保持原有语义；后台 session 下 resumeData 仍受 macOS 版本限制（macOS 14+ 使用 `cancel(byProducingResumeData:)`）。
- 限制：macOS 没有 iOS 式的后台启动回调；用户退出 App 后系统可继续传输，但必须手动再次启动 App 才会 reconcile 任务。强制退出/系统重启会中断；不做 helper 进程或捆绑下载器。

### 10.2 RSS / 自动下载（MVP）

- 新增 `DownloadRSS.swift`：RSS 2.0（`item/title/link/enclosure url/length/pubDate/guid`）与 Atom（`entry/title/link href/published`）解析，使用 Foundation `XMLParser`；无第三方依赖。
- 订阅字段：标题、URL、自动下载开关、可选关键词过滤；持久化到 `UserDefaults`（`download.rss.feeds`）。
- 下载中心工具栏新增“RSS 订阅…” sheet：
  - feed 列表、添加/删除、刷新、关键词编辑；
  - 条目列表显示标题/日期/大小，支持“下载所选”、双击下载；
  - 加载中/空订阅/空条目/解析或网络错误都有明确状态；
  - 自动下载默认关闭；启用后刷新时只添加“未见过 + 关键词匹配 + 有 enclosure”的条目，单次最多 20 条，避免首次订阅灌满队列。
- 手动下载优先 enclosure，没有时回退 link；自动下载只用 enclosure，不抓网页/不内置资源站规则。

### 10.3 BT 单文件优先级

- `torrent-get` 读取 `files[].priority`；`DownloadFileProgress.priority` 仅内存保存。
- `TransmissionRPCClient.setFilePriorities(ids:indices:priority:)` 发送 `torrent-set` 的 `priority-high` / `priority-normal` / `priority-low`。
- 详情文件表右键菜单设置高/普通/低优先级；wanted/unwanted 复选框保持不变。优先级修改失败会回滚并显示错误。

### 10.4 限速、做种分享率与远程路径映射

- 新增 `DownloadLimitsSheetViewController`（下载设置 → “限速与远程路径…”）：
  - 全局下载/上传限速（KB/s，0 不限）与做种分享率（0 不启用）；
  - “应用到 Transmission”通过 `session-set` 实时生效，成功/失败都有明确文案；未配置 daemon 或 BT 关闭时不会假装成功；
  - 保存只记住设置，应用按钮才修改 daemon。
- 远程路径映射：远程前缀 → 本地前缀（如 `/downloads` → `/Users/me/Downloads`），用于远程 Transmission 任务的“播放”和“在 Finder 中显示”；前缀为空时原样返回，本地 Transmission 行为不变。
- 纯逻辑 `DownloadPathMapping` 有单元测试覆盖边界（前缀相等、子路径、组件边界、空前缀、根前缀）。

### 10.5 远程 `.torrent` 去重

- 对远程 `.torrent` URL，在确认 daemon 可用后先抓取（≤20MB，15 秒超时）并计算 info hash，再与磁力/本地种子任务共享 `btih:` 去重键。
- 抓取失败或非 bencode 时回退到原有 URL 去重，不阻塞添加；代价是成功添加时 daemon 可能再次下载同一个 `.torrent` 文件。

### 10.6 验证与剩余

- DownloadTests 40 个通过（新增 RSS 解析/筛选/自动下载选择/持久化、路径映射、文件优先级与 `session-set` 参数）。
- macOS Debug 构建通过；未运行真实 RSS/Transmission 网络或 UI 功能测试。
- 仍延后：边下边播/本地 Range 代理、内置 BT 内核、RSS 资源站规则、做种状态专属 UI、App 自动重启后的后台任务接管。
