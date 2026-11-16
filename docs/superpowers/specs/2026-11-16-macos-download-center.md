# macOS 下载中心 MVP 设计（P7）

> 状态：MVP 已实现并合并 win-porting（2026-11-16）
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

## 5. 边下边播

- BT：任务开始时请求 sequential download；当第一个视频文件已有可读数据且播放器能打开时，允许“边下边播”。失败时提示“下载完成后播放”。
- HTTP：直接播放本地临时文件只有在容器格式支持增长写入时才可用；首期标记为实验性。
- 不在任务未开始时声称支持边下边播。

## 6. 测试

- URL 解析：magnet（btih/sha1/DN/TR）、`.torrent` URL、HTTP 直链、非法输入。
- 任务状态机：queued → downloading → paused/stopped/completed/failed 的合法迁移。
- Transmission RPC：409 session id、torrent-add/get/start/stop/remove 的请求与响应解码。
- SQLite CRUD / 重启恢复。
- HTTP 下载：URLProtocol stub 的进度/取消/resumeData（纯逻辑层）。
- UI/AX：窗口、添加、任务行、空态；BT 未配置提示。

## 7. 风险

1. **没有内置 BT 内核**：开箱即用性不足；需要产品决策（捆绑 libtorrent/aria2 或依赖外部 Transmission）。
2. **边下边播**：不同容器/播放器对增长文件支持不一致，首期只能 best effort。
3. **RPC 凭据安全**：密码必须进 Keychain，不能写 UserDefaults/日志。
4. **许可证**：若后续捆绑 GPL 下载器，需要重新评估分发方式。

## 8. 实现结果（2026-11-16）

- 新增 `Mac/AniXPlayer/Features/Download/`：任务模型、SQLite 持久化、HTTP 引擎、Transmission RPC 引擎、管理器、窗口、添加/设置 sheet。
- HTTP：URLSessionDownloadTask，暂停保留 resumeData、停止删除、2xx 校验、文件名冲突处理；macOS 12/13 无 resumeData API 时从头下载。
- BT：默认 `127.0.0.1:9091`，409 session id 自动重试，magnet/metainfo add、get、start/stop/remove；`sequentialDownload` 不支持时自动回退。
- 未检测到 Transmission 时不落库、不伪造任务，显示安装/重试提示。
- RPC 密码优先 Keychain；Debug 回退 0600 文件，避免未签名构建弹钥匙串。
- 菜单：功能 → 下载中心…；AX 标识 `download.*`。
- 验证：192 个单测通过（DownloadTests 18 个）；HTTP 手工联调（27MB，暂停续传 Range 成功）；L2/UI 冒烟通过。
- 限制：真实 Transmission 未联调；App 退出后 HTTP 任务不后台继续；BT 边下边播取决于版本与 sequential 支持；发布前仍需决定是否捆绑 BT 内核。
