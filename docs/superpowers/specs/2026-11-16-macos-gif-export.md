# macOS 动图导出（GIF）

> 状态：已实现（2026-11-16）
> 范围：macOS；iOS/tvOS 不变。静态截图保持免费且行为不变。
> 入口：功能菜单「导出动图…」；会员门禁 `EntitlementGate.require(.member, feature: .gifExport)`。

## 1. 目标

- 不再依赖「AVFoundation 能解码的本地文件」，支持本地 MKV/HEVC/AV1，并尽量支持带请求头的在线源。
- 导出前给出选项，导出中可看进度、可取消，成功后预览/定位/另存为。
- 不静默生成空文件或缺帧文件；失败必须回到播放器并给出可读错误。

## 2. 抓帧管线

### 2.1 源分类

`GIFExportService` 接收当前播放的 `File`，通过 `file.createMPVMedia()?.url ?? file.url` 得到真实可播放地址：

- **本地源**：`file.url.isFileURL && playableURL.isFileURL`。
- **在线/远程源**：`anix-online://`、HTTP(S)、SMB 本地代理、FTP/WebDAV/Emby 等。请求头来自 `File.httpHeaders`，注入无头 MPV 的 `http-header-fields`。

### 2.2 抓帧顺序

1. **本地且 AVFoundation 能解析**（有视频轨 + 有效时长）：
   - `AVAssetImageGenerator` 逐帧 `copyCGImage`，`appliesPreferredTrackTransform = true`，`maximumSize = 最大宽度`。
   - 失败后回退无头 MPV。
2. **其它本地文件（MKV/HEVC/AV1 等）以及在线源**：
   - 先走无头 MPV；本地文件失败后回退 AVFoundation，在线源不会强行走 AVFoundation（避免网络阻塞）。
3. 两个内核都失败：抛出可读错误（优先展示无头 MPV 的错误），不会写出空文件。

无头 MPV 复用 `MPVFrameRenderer` 和 `MPVPlayerWrapper.MediaThumbnailFetcher` 的模式，但独立成 `GIFMPVFrameCapture`：

- 独立 `MPV` 实例 + 软件渲染上下文，不依赖屏幕上的播放器；
- 加载一次媒体，之后每帧 `seek absolute+exact` → 等 `seek` 事件 → 主动 render；
- 关闭字幕（`subtitle.autoLoad = .no`）和音频，不烧字幕/弹幕；
- 渲染阶段按最大宽度设置 `outputScale`，最终再兜底降采样；
- 超时：本地加载 15s / 在线加载 30s；本地单帧 8s / 在线单帧 15s；
- 取消通过 `GIFExportSession` 唤醒正在等待的 MPV 抓帧器并释放实例。

### 2.3 帧时间与完整性

- 片段时长被限制在剩余视频长度内；不足 0.5 秒直接报错。
- 帧数 = `round(clipDuration × fps)`，补足至少 2 帧，硬上限 75 帧（5s × 15fps）。
- 末帧时间 clamp 到 `时长 - 0.1s`，避免 seek 到 EOF。
- 任何一帧截取失败都视为整体失败；成功后还会校验帧数是否与计划一致，避免缺帧动图。

## 3. 选项与默认值

选项 sheet（`GIFExportOptionsViewController`）：

| 选项 | 可选值 | 默认 |
|---|---|---|
| 开始时间 | 当前播放位置，可编辑（秒） | 当前播放位置 |
| 时长 | 1 / 2 / 3 / 5 秒 | 3 秒 |
| 帧率 | 5 / 10 / 15 fps | 10 fps |
| 最大宽度 | 480 / 640 / 960 px | 480 px |
| 输出格式 | GIF；仅当 ImageIO 报告 WebP 编码器时追加 WebP | GIF |

界面会显示预计帧数/片段长度，并提示「弹幕和字幕不会烧录到动图中；导出过程中可随时取消」。开始时间无效或剩余不足 1 秒时禁用导出。

## 4. 进度、取消、预览

- 进度 sheet：`NSProgressIndicator` + 阶段文案（截取画面 / 编码）+ 取消按钮。进度映射：
  - 抓帧 2%–86%；
  - 编码 88%–100%。
- 取消：
  - `GIFExportSession.cancel()` 设置原子取消标记，抓帧每帧前检查；
  - 无头 MPV 会立即终止并唤醒等待；
  - UI 2 秒兜底，避免个别解码器卡住导致 sheet 无法关闭；
  - 切换媒体、停止播放、关闭播放器窗口都会取消并清理 sheet。
- 成功后显示预览 sheet：`NSImageView.animates = true` 播放动图，提供「在 Finder 中显示」「另存为…」「完成」。
- 失败/取消：关闭进度 sheet，回到播放器；失败用 HUD 显示错误。
- 导出期间 `isExportingGIF` 阻止菜单重复触发。

Accessibility identifiers 已加在 `AccessibilityID.Player`：options/progress/preview 三个窗口，以及开始时间、时长、帧率、宽度、格式、预计帧数、确认/取消、进度条、预览图、Finder/另存为/完成按钮。

## 5. 输出

- 保存目录复用截图目录与 security-scoped bookmark（`SnapshotLocation`）。
- 文件名：`视频名_yyyyMMdd_HHmmss_SSS.gif`。
- GIF：`CGImageDestination`，无限循环，帧延迟 = `1/fps`。
- WebP：只有 `CGImageDestinationCopyTypeIdentifiers()` 包含 `org.webmproject.webp` / `UTType.webP` 时才出现在格式选项；编码使用 `kCGImagePropertyWebPDictionary`、`kCGImagePropertyWebPDelayTime`、`kCGImagePropertyWebPUnclampedDelayTime`、`kCGImagePropertyWebPLoopCount`。当前开发机（macOS 27.2 SDK 环境）的 ImageIO 未报告 WebP 编码器，因此实际只展示 GIF；WebP 分支属于运行时开关，未在真机验证动画 WebP 输出。
- APNG：ImageIO 不支持可靠编码，未实现，也未在文案中宣称。

## 6. 限制与未做

- 不烧录弹幕；也不烧录字幕。若后续需要字幕，必须做离线字幕合成，不能截屏幕。
- 在线源依赖无头 MPV 的 seek 能力：m3u8 慢源、强防盗链、DRM/MSE 可能失败；失败会明确提示，不做静默降级。
- 远程源不走 AVFoundation 回退，避免网络请求无法取消/长时间阻塞。
- 内存上限约为 75 帧 × 960px 宽（最坏约 150 MB 的 CGImage 数据），已通过帧数和宽度双重限制；没有做分块流式编码。
- WebP 动画输出未在本机验证；APNG 不支持；没有画质/调色板/裁剪起止时间等高级选项。
- 选项中的开始时间以秒为单位输入，没有做时间码控件。
- 没有新增自动化测试；本次只做编译验证。

## 7. 相关文件

- `Mac/AniXPlayer/Features/GIFExport/GIFExportService.swift`：配置、会话、抓帧调度、编码。
- `Mac/AniXPlayer/Features/GIFExport/GIFMPVFrameCapture.swift`：无头 MPV 逐帧抓取。
- `Mac/AniXPlayer/Features/GIFExport/GIFExportOptionsViewController.swift`：选项 sheet。
- `Mac/AniXPlayer/Features/GIFExport/GIFExportProgressViewController.swift`：进度/取消 sheet。
- `Mac/AniXPlayer/Features/GIFExport/GIFExportPreviewViewController.swift`：预览/定位/另存为。
- `Mac/AniXPlayer/Features/GIFExport/GIFExportFlowController.swift`：选项 → 导出 → 预览的状态流转。
- `Mac/AniXPlayer/Player/PlayerViewController.swift`：菜单入口、门禁、取消钩子。
- `Mac/AniXPlayer/Base/Helper/AccessibilityID.swift`、`Mac/AniXPlayer/Localizable.xcstrings`。
- `Share/CocoaShare/Membership/EntitlementGate.swift`：会员文案已改为「将视频片段导出为 GIF 动图。」

## 8. 验证

```bash
DERIVED_DATA_PATH=/tmp/anix-dd-gif bash scripts/build-mac.sh Debug
```

结果：`BUILD SUCCEEDED`。未运行网络/UI 功能测试。
