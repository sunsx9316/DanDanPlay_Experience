# macOS 本地媒体库体验补齐

> 状态：已完成（2026-11-16）
> 范围：macOS `Mac/AniXPlayer/Features/LocalLibrary`；iOS/tvOS 不变。
> 对应差距文档：`docs/superpowers/specs/2026-11-16-macos-feature-gaps.md` 第 4 节（未修改）。

## 1. 目标与结论

本地媒体库的数据骨架（SQLite、security-scoped bookmark、递归/增量扫描、16 MB MD5 + `/match`、海报墙、搜索/筛选、独立播放器播放）原本已经可用。本轮补齐的是「媒体库体验」和「匹配控制」：

- 重扫不再清空未变化文件的匹配元数据。
- 缺失文件可筛选、计数、清理；缺失条目不参与播放和 Finder 定位。
- 支持排序持久化、多选与批量操作。
- 支持手动 Bangumi 搜索 / 选择剧集 / 取消匹配。
- 已匹配文件按 `animeId` 聚合为剧集卡，提供剧集列表与「播放全部」。
- 后台生成缩略图、时长、分辨率，并持久化到数据库。
- 扫描可取消；哈希等待有上限；嵌套文件夹不覆盖原 `folderId`，添加时给出重叠警告。
- 扫描/播放权限失效时提供「重新选择文件夹…」引导。
- 新增控件有 AX 标识，新文案有英文 + zh-Hans。

## 2. 数据与迁移

`LocalLibraryFile` 新增可空字段：

```text
duration   REAL     // 秒
width      INTEGER  // 像素
height     INTEGER  // 像素
```

`LocalLibraryStore.migrate()` 用 `PRAGMA table_info` 做幂等补列，`user_version` 升到 2；旧库无需重建。`saveFile` 的 upsert 仍按唯一 `path` 工作。

匹配元数据保留规则在 `LocalLibraryFile.makeScanned`：

- 同路径、`fileSize` 相同、`modifiedAt` 在 1 秒容差内、哈希相同（或本次哈希失败）时：
  - 保留 `animeId / episodeId / animeTitle / episodeTitle / imageUrl / type / isMatched`；
  - 保留已探测的 `duration / width / height`；
  - 恢复 `isMissing = false`。
- 大小 / mtime / 哈希发生实际变化时，清空匹配元数据，等待重新匹配。
- `folderId` 保留首次入库归属；`saveFile` 也做同样保护，避免父/子文件夹互相覆盖。
- 哈希失败但大小/mtime 未变时保留旧哈希，避免下次扫描丢失匹配依据。

## 3. 扫描、取消与嵌套文件夹

- `LocalLibraryScanRules.enumerateVideoFiles` 支持 `shouldCancel`，在每个目录项之间检查；取消抛出 `CancellationError`，不会被误判为「文件夹已清空」。
- 扫描在每文件前后、哈希前检查取消；`LocalLibraryScanner.hashTimeout = 20s`，每 0.1 秒轮询取消，单个慢文件不会永久阻塞。
- 同一路径在多个根文件夹下只处理一次；每个文件夹的 `markMissing` 使用该文件夹本次完整枚举到的路径集合，父/子文件夹同时存在时不会把另一归属的记录误标缺失。
- 添加文件夹时通过 `LocalLibraryFolderRules` 检测相同 / 新文件夹是父目录 / 新文件夹是子目录：
  - 相同路径只更新 bookmark；
  - 父/子重叠弹出警告，说明重叠文件只保留首次入库归属，移除其中一个文件夹不会删除另一个的索引；
  - 用户可「仍然添加」或取消。
- 扫描/匹配运行期间禁用文件夹添加、移除和扫描入口，避免 DB 写入竞态。

## 4. 缺失文件

- `LocalLibraryFilter` 新增 `.missing`；`LocalLibraryQueryLogic` 与 SQL 查询语义一致。
- `includesMissing` 在 UI 中由「在列表中显示缺失文件」菜单开关控制；`.missing` 过滤器始终只显示缺失条目。
- 摘要显示「共 X · 已匹配 Y · 未匹配 Z · 缺失 N」。
- 「清理缺失记录…」只删除 `isMissing = 1` 的记录；可选择当前文件夹或全部。
- 缺失条目：Play 禁用、Finder 禁用、卡片标红/降透明度；剧集列表中的缺失集不可播放。
- 扫描仍按原逻辑把磁盘上消失的记录标为 missing，不会自动删除。

## 5. 排序、多选与批量操作

- 排序弹窗：标题 / 文件名 / 大小 / 路径；写入 `UserDefaults` 键 `LocalLibrary.sort`，重启后保持。
- `NSCollectionView` 开启 `allowsMultipleSelection`；单击只选择，双击或「播放」按钮播放/打开剧集列表。
- 选择状态使用卡片 ID 集合（`anime-<id>` / `file-<id>`），刷新后尽量恢复。
- 批量操作：
  - 重新匹配所选；
  - 取消匹配所选；
  - 在 Finder 中显示（只有非缺失文件）；
  - 移出媒体库（只删索引，不删磁盘）；
  - 清理缺失记录。
- 「移出媒体库」按所选卡片展开到文件级，删除对应 DB 行；分组卡会移除该组全部剧集记录。

## 6. 匹配修正

`LocalLibraryMatchEditorViewController`：

1. 目标是当前所选卡片包含的文件；分组/多选时提供「目标文件」下拉。
2. 用现有 `/search/anime`（`SearchUpgradeNetworkHandle.searchAnime`）按标题搜索；搜索走登录门禁，失败显示真实错误，不生成假结果。
3. 选择番剧后调用 `BangumiNetworkHandle.detail(animateId:)` 加载剧集；按集数/标题排序。
4. 选择剧集后通过 `LocalLibraryStore.applyManualMatch(fileId:info:)` 写入 `animeId / episodeId / animeTitle / episodeTitle / imageUrl / type / isMatched`。
5. 「取消匹配」调用 `LocalLibraryStore.clearMatch(fileId:)` 清空匹配字段；主界面也提供「取消匹配所选…」批量入口。
6. 自动匹配逻辑不变：扫描后只对 `unmatchedFiles()` 调用 `/match`；手动修正不会阻止后续自动匹配未匹配文件。
7. 对已匹配文件执行「重新匹配所选」时，若 `/match` 失败/多候选，保留旧匹配；未匹配文件仍写回失败状态。需要清空时使用「取消匹配」。

## 7. 剧集分组

- 纯逻辑在 `LocalLibraryGrouping` / `LocalLibraryCard` / `LocalLibraryAnimeGroup`：
  - 只有 `isMatched == true` 且 `animeId > 0` 的文件按 `animeId` 聚合；
  - 未匹配文件保持独立卡片，不做文件名启发式分组；
  - 组内按集数排序，支持「第12话」「EP03」「S02E05」「12.5」和纯数字；无数字时按标题/路径。
- 组卡显示：海报、番剧标题、集数、总大小、缺失集数、时长/分辨率（来自代表文件）。
- 双击组卡或点「播放」打开剧集列表 sheet：
  - 每集显示标题、文件名、大小、时长/分辨率、缺失状态；
  - 单集播放、双击播放、「播放全部」；
  - 缺失集禁用播放。
- 组卡排序沿用当前排序：标题、首个文件名、总大小、首个路径。

## 8. 缩略图 / 时长 / 分辨率

`LocalLibraryThumbnailProvider`：

- AVFoundation 在 `OperationQueue`（最多 2 并发、utility QoS）读取本地文件：
  - 时长：`AVAsset.duration`；
  - 分辨率：视频轨 `naturalSize` + `preferredTransform`；
  - 缩略图：`AVAssetImageGenerator`，取 10% 或至少 1 秒，限制 640×960。
- AVFoundation 能解码的 MP4/MOV 等会显示本地缩略图；MKV/HEVC/AV1 等失败时保持 nil，UI 回退到远程海报或扩展名占位。
- 内存缓存键为 `path + mtime + size`；磁盘缓存在 `Caches/AniXPlayer/LocalLibraryThumbnails/<sha256>.jpg`。
- 探测到的时长/分辨率写回 SQLite；卡片信息异步补全，不阻塞主线程。
- cell 复用调用 `cancel(token)`，移除回调并尽量取消 Operation；AVAssetImageGenerator 的同步解码无法中途打断，但结果会被丢弃。

## 9. 权限与性能

- 扫描枚举失败会带 `folderId` 返回 `LocalLibraryScanSummary.folderFailures`；主界面弹出「无法访问媒体库文件夹」并提供「重新选择文件夹…」，更新 bookmark 后重新扫描。
- 播放前只检查当前选中文件，不再对整页文件 `fileExists`；使用 DB `isMissing` 过滤播放列表。
- 播放时通过 `LocalLibraryFolderAccess` 解析 bookmark 并保持 security-scoped access 到进程结束，避免扫描停止访问后播放器读不到文件。
- 权限失效时弹出「无法访问视频文件」并可直接重选文件夹；确认文件真的不存在时只把当前文件标为 missing。
- 缩略图/元数据异步更新不会触发整表 reload；用户操作后的刷新仍使用一次快照查询（分组/统计需要整体视图）。

## 10. 可访问性与本地化

- `AccessibilityID.LocalLibrary` 新增排序、播放、匹配修正、更多批量操作、清理缺失、剧集 sheet/播放全部、匹配修正 sheet 等标识。
- 本轮新增用户文案已加入 `Mac/AniXPlayer/Localizable.xcstrings`，含英文和 zh-Hans。
- 现有 LocalLibrary 旧文案未全部补英文；本轮只保证新增/修改文案。

## 11. 测试覆盖

`Mac/AniXPlayerTests/LocalLibraryTests.swift`（31 个测试，纯单元，无网络/UI）：

- 重扫保留匹配元数据（内容未变、缺失恢复、哈希失败）。
- 大小/哈希变化清空匹配元数据。
- 文件 upsert 保留 ID / 原始 folderId。
- 文件夹关系：相同、父目录、子目录、兄弟目录。
- 缺失过滤器、`includesMissing`、只清理缺失记录。
- 按 ID 删除记录。
- 手动匹配 / 取消匹配。
- 按 animeId 分组、未匹配保独立、集数排序与解析。
- 时长/分辨率持久化与格式化。
- 旧库缺少 duration/width/height 时自动迁移。
- 目录枚举取消。
- 原有 CRUD、统计、搜索/筛选、匹配响应解码、扫描进度等回归。

验证命令：

```bash
DERIVED_DATA_PATH=/tmp/anix-dd-media bash scripts/build-mac.sh Debug
DERIVED_DATA_PATH=/tmp/anix-dd-media-tests bash scripts/test-mac.sh Debug --only AniXPlayerTests/LocalLibraryTests
```

## 12. 剩余限制

1. **观看状态没有数据源**：当前 DB 不记录「已看/未看」；分组卡只显示缺失，不伪造 watched 状态。后续可接播放历史表。
2. **手动匹配只写入单集**：分组/多选时通过「目标文件」逐集修正；没有「整组按顺序批量套用剧集」的一键映射。
3. **搜索依赖登录**：手动修正复用现有搜索 API 和登录门禁；未登录时不会伪造 Bangumi 结果。
4. **缩略图只支持 AVFoundation 可解码文件**：MKV/HEVC/AV1 等仍回退远程海报/占位；无头 MPV 抓帧未接入。
5. **同步 AVFoundation 探测不可强取消**：cell 复用会丢弃结果并取消排队 Operation，但已经进入解码的调用可能跑到结束（最多 2 并发，后台）。
6. **播放访问保持到进程结束**：`LocalLibraryFolderAccess` 不主动 stop，避免独立播放器窗口关闭前失效；属于有意的资源泄漏，后续可接播放结束回调。
7. **权限恢复一次处理一个文件夹**：扫描完成只弹第一个失败文件夹；其余可再次扫描后处理。
8. **刷新仍以整表快照为主**：排序、分组和统计需要全局视图；只对缩略图/元数据做了局部更新。
9. **没有 FSEvents / 文件重命名追踪**：仍依赖手动或启动扫描。
10. **分页/虚拟化未做**：超大媒体库（数万文件）仍会一次性查询和生成卡片。
11. **缩略图磁盘缓存没有过期清理**：目前只按 path+mtime+size 的哈希复用；后续可加 LRU/容量上限。
12. **文件夹移动不会自动重映射路径**：重新授权要求选择原路径；移动后的文件夹需移除后重新添加。

## 13. 明确未做

- 不新增 OneDrive/Plex/SFTP 等远程 provider。
- 不改 Online、Download、GIF、BangumiDetail、Player、AppDelegate 和全局导航。
- 不做文件重命名、标签、评分、播放列表编辑。
- 不修改 `2026-11-16-macos-feature-gaps.md`。
