# macOS 下载中心 MVP 设计（P7）

> 状态：MVP + 基础能力完善已合并 win-porting（2026-11-16）
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

- 边下边播/本地 Range 代理；
- RSS/自动下载、内置 BT 内核、退出 App 后 HTTP 后台下载；
- BT 单文件优先级、做种/分享率策略；
- 远程 Transmission 的播放/Finder 路径映射；
- 远程 `.torrent` URL 在 daemon 返回 hash 前只按 URL 去重。

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
