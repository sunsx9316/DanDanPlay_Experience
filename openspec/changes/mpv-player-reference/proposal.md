## Why

修改 `MPV.swift`、MPV wrapper、libmpv 封装或任何与 MPV 播放器相关的代码时，必须先查阅这份参考文档，确保属性类型、命令参数、API 用法正确。

## When to Consult

- 新增 MPV 属性封装（`MPVProperty` 定义）
- 修改 `MPV.swift` 核心逻辑
- 修改 `MPVPlayerWrapper.swift` 播放器适配
- 修改 `MPVPiPProvider.swift` 画中画逻辑
- 修改 `MPV+APIs.swift` 中的 API 外观类

## Workflow

1. **修改代码前**：阅读 `api-reference.md`，确认要使用的属性、命令、选项
2. **编写代码时**：参考文档中的用法示例，确保类型和参数正确
3. **检查兼容性**：确认使用的 mpv API 在目标版本可用

## Quick Reference

### 属性命名
- 使用 `MPV.Property<ValueType>` 泛型 struct，不要硬编码字符串
- 示例：`MPV.Property.pause` 而不是 `"pause"`

### 命令执行
- 使用 `MPV.Command` 枚举（已封装）
- 示例：`MPV.Command.loadFile`

### API 模块
| 模块 | 用途 |
|------|------|
| `mpv.playback` | 播放控制、暂停、速度 |
| `mpv.time` | 时间位置、跳转、时长 |
| `mpv.audio` | 音频轨道、音量、静音 |
| `mpv.video` | 视频轨道、全屏、硬件解码 |
| `mpv.subtitle` | 字幕轨道、延迟、样式 |
| `mpv.track` | 轨道信息查询 |

### 注意事项
- mpv 属性名使用 kebab-case（如 `playback-time`）
- 颜色使用 hex 格式：`#RRGGBB` 或 `#AARRGGBB`
- 硬件解码推荐使用 `videotoolbox`（macOS/iOS）
- **修改 MPV.swift 的 API 时，必须同步检查并修改所有调用点**，确保参数类型和含义一致
- `MPVProperty+Values.swift` 中定义静态属性，`MPV+APIs.swift` 中定义外观类

## Core Files

| 文件 | 职责 |
|------|------|
| `MPV/Core/MPV.swift` | 核心类 + 嵌套类型（Event、Property<ValueType>、Command）+ 核心方法 |
| `MPV/Core/MPVProperty+Values.swift` | Bool/Int64/Double/String/ObservableOnly 属性静态定义 |
| `MPV/Core/MPV+APIs.swift` | PlaybackAPI、TimeAPI、AudioAPI、VideoAPI、SubtitleAPI、TrackAPI |
| `MPV/Core/MPVColor+Hex.swift` | MPVColor hex 字符串互转 |
