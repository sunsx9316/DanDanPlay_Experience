# mpv API 参考手册

> 基于 [mpv.io/manual/stable/](https://mpv.io/manual/stable/) 的常用API整理

---

## 1. 属性 (Properties)

### 播放控制 (Playback)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `pause` | flag | 暂停状态 |
| `speed` | double | 播放速度 |
| `cache` | int64 | 缓存状态 |

### 时间 (Time)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `time-pos` | double | 当前播放位置（秒） |
| `time-start` | double | 开始时间 |
| `duration` | double | 媒体总时长（秒） |
| `remaining` | double | 剩余播放时间（秒） |
| `playtime-remaining` | double | 剩余播放时间 |

### 音频 (Audio)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `aid` | int64 | 音频轨道ID |
| `audio-device` | string | 音频设备名称 |
| `volume` | int64 | 音量 (0-100) |
| `mute` | flag | 静音状态 |
| `audio-delay` | double | 音频延迟（秒） |
| `audio-params` | - | 音频参数信息 |

### 视频 (Video)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `vid` | int64 | 视频轨道ID |
| `video-aspect-override` | double | 视频宽高比覆盖 |
| `fullscreen` | flag | 全屏状态 |
| `wid` | int64 | 窗口ID（用于嵌入） |
| `hwdec` | string | 硬件解码模式 (`no`, `auto`, `videotoolbox`) |
| `vo` | string | 视频输出驱动 |
| `gpu-api` | string | GPU API类型 |
| `gpu-context` | string | GPU上下文类型 |

### 字幕 (Subtitle)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `sid` | int64 | 字幕轨道ID |
| `secondary-sid` | int64 | 副字幕轨道ID |
| `sub-delay` | double | 字幕延迟（秒） |
| `sub-margin` | int64 | 字幕边距 |
| `sub-margin-y` | int64 | 字幕垂直边距 |
| `sub-pos` | int64 | 字幕位置 |
| `sub-font-size` | int64 | 字幕字体大小 |
| `sub-color` | string | 字幕颜色 (hex如 `#FFFFFF`) |
| `sub-back-color` | string | 字幕后景色 (hex如 `#00000080`) |
| `sub-font` | string | 字幕字体名称 |
| `sub-fonts-dir` | string | 字幕字体目录 |
| `sub-ass` | string | ASS字幕样式 |
| `sub-ass-override` | string | ASS覆盖模式 (`yes`, `no`, `force`, `scale`, `strip`) |
| `sub-auto` | string | 自动加载字幕 (`no`, `exact`, `fuzzy`, `all`) |
| `sub-use-margins` | flag | 使用边距 |

### 轨道 (Track)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `track-list` | - | 轨道列表 |
| `track-list/{n}/type` | string | 轨道类型 (`audio`, `video`, `sub`) |
| `track-list/{n}/id` | int64 | 轨道ID |
| `track-list/{n}/title` | string | 轨道标题 |
| `track-list/{n}/lang` | string | 轨道语言 |

### 其他
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `screenshot-mode` | - | 截图模式 |
| `eof-reached` | flag | 播放结束标志 |
| `seeking` | flag | 是否正在跳转 |
| `pause-for-cache` | flag | 因缓存暂停 |
| `cache-buffering` | double | 缓存缓冲百分比 |

---

## 2. 命令 (Commands)

### 文件操作 (File)
```
loadfile <path> [replace|append]
stop
```

### 跳转 (Seek)
```
seek <seconds> [absolute|relative|exact]
revert-seek
```

### 轨道 (Track)
```
track-select [no|audio|video|sub]
audio-add <path> [select|auto]
audio-remove [id]
sub-add <path> [select|auto]
sub-remove [id]
```

### 属性操作 (Property)
```
set <property> <value>
add <property> <delta>
multiply <property> <factor>
cycle <property> [up|down]
cycle-values <property> <value1> <value2> ...
```

### 截图 (Screenshot)
```
screenshot [subtitles|video|window]
screenshot-to-file <path> <format>
```

### 播放控制
```
quit [exit-code]
quit-watch-later [exit-code]
```

---

## 3. 事件 (Events)

| 事件名 | ID | 说明 |
|--------|-----|------|
| `none` | 0 | 无事件 |
| `shutdown` | 1 | 关闭事件 |
| `log-message` | 2 | 日志消息 |
| `get-property-reply` | 3 | 属性获取回复 |
| `set-property-reply` | 4 | 属性设置回复 |
| `command-reply` | 5 | 命令执行回复 |
| `start-file` | 6 | 开始播放文件 |
| `end-file` | 7 | 文件播放结束 |
| `file-loaded` | 8 | 文件加载完成 |
| `idle` | 11 | 空闲状态 |
| `tick` | 14 | 定期Tick |
| `client-message` | 16 | 客户端消息 |
| `video-reconfig` | 17 | 视频重配置 |
| `audio-reconfig` | 18 | 音频重配置 |
| `seek` | 20 | 跳转完成 |
| `playback-restart` | 21 | 播放重启 |
| `property-change` | 22 | 属性变化 |
| `queue-overflow` | 24 | 队列溢出 |
| `hook` | 25 | Hook事件 |

---

## 4. 硬件解码 (Hardware Decoding)

| 模式 | 说明 |
|------|------|
| `no` | 禁用硬件解码 |
| `auto` | 自动选择最佳硬件解码 |
| `videotoolbox` | VideoToolbox (macOS/iOS/tvOS) |
| `mediacodec` | MediaCodec (Android) |
| `drmprime` | DRM Prime (Linux) |

---

## 5. 颜色格式

mpv使用hex格式的颜色：`#RRGGBB` 或 `#AARRGGBB`

```swift
// 白色
"#FFFFFF"
// 半透明黑色 (50% alpha)
"#00000080"
// 红色
"#FF0000"
```

---

## 6. 常见用法示例

### 初始化
```swift
guard let mpv = MPV() else { return }
mpv.setProperty(.hwdec, "videotoolbox")
mpv.initialize()
```

### 加载文件
```swift
mpv.loadFile("/path/to/video.mkv")
```

### 播放控制
```swift
mpv.playback.isPaused = true
mpv.playback.togglePause()
mpv.playback.setSpeed(1.5)
```

### 时间控制
```swift
let pos = mpv.time.position
mpv.time.seek(to: 120.0)
let dur = mpv.time.duration
```

### 音频控制
```swift
mpv.audio.volume = 80
mpv.audio.isMuted = true
mpv.audio.audioId = 2
```

### 字幕控制
```swift
mpv.subtitle.delay = 1.5
mpv.subtitle.addExternal(path: "/path/to/sub.srt")
mpv.subtitle.fontSize = 50
mpv.subtitle.color = MPVColor(hex: "#FFFFFF")
```

---

## 7. 官方文档

- 主文档: https://mpv.io/manual/stable/
- 属性列表: https://mpv.io/manual/stable/#properties
- 命令列表: https://mpv.io/manual/stable/#command-interface
- 选项列表: https://mpv.io/manual/stable/#options
- libmpv C API: https://mpv.io/manual/stable/#c-api
