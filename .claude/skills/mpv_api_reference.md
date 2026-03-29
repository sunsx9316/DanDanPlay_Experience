# mpv API 参考手册

> 基于 [mpv.io/manual/stable/](https://mpv.io/manual/stable/) 的常用API整理

---

## 1. 属性 (Properties)

### 播放控制 (Playback)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `pause` | flag | 暂停状态 |
| `playback-time` | double | 播放速度 |
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
| `audio-params` | - | 音频参数信息 |

### 视频 (Video)
| 属性名 | 类型 | 说明 |
|--------|------|------|
| `vid` | int64 | 视频轨道ID |
| `video-aspect-override` | double | 视频宽高比覆盖 |
| `fullscreen` | flag | 全屏状态 |
| `wid` | int64 | 窗口ID（用于嵌入） |
| `hwdec` | string | 硬件解码模式 (`no`, `auto`, `drmprime`) |
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
| `sub-font-size` | int64 | 字幕字体大小 |
| `sub-color` | string | 字幕颜色 (hex如 `#FFFFFF`) |
| `sub-back-color` | string | 字幕后景色 (hex如 `#00000080`) |
| `sub-font` | string | 字幕字体名称 |
| `sub-fonts-dir` | string | 字幕字体目录 |
| `sub-ass` | string | ASS字幕样式 |
| `sub-ass-override` | string | ASS覆盖模式 (`yes`, `no`, `force`) |
| `sub-auto` | string | 自动加载字幕 (`fuzzy`) |
| `sub-use-margins` | flag | 使用边距 |
| `sub-ass-use-video-data` | - | ASS使用视频数据 |

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
| `eof` | flag | 播放结束标志 |
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

### 字幕 (Subtitle)
```
sub-seek
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

### OSD
```
show-text <text> [duration|level]
overlay-add <id> <dx> <dy> <file> <offset> <fmt> <w> <h> <stride>
overlay-remove <id>
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

## 4. 选项 (Options)

### 播放选项
| 选项 | 说明 |
|------|------|
| `--speed=<0.01-100>` | 播放速度 |
| `--pause` | 初始暂停状态 |
| `--fs` | 全屏 |
| `--no-fullscreen` | 非全屏 |

### 视频选项
| 选项 | 说明 |
|------|------|
| `--vo=<driver>` | 视频输出驱动 (`libmpv`, `opengl`, `wayland`, ...) |
| `--hwdec=<mode>` | 硬件解码 (`no`, `auto`, `drmprime`) |
| `--video-aspect-override=<ratio>` | 强制视频宽高比 |
| `--fullscreen` | 全屏 |
| `--ontop` | 窗口置顶 |
| `--panscan=<0.0-1.0>` | Pan-and-scan范围 |

### 音频选项
| 选项 | 说明 |
|------|------|
| `--volume=<0-100>` | 音量 |
| `--mute=<yes|no|auto>` | 静音 |
| `--audio-device=<name>` | 音频设备 |

### 字幕选项
| 选项 | 说明 |
|------|------|
| `--sub-delay=<sec>` | 字幕延迟 |
| `--sub-font-size=<size>` | 字幕字体大小 |
| `--sub-color=<color>` | 字幕颜色 |
| `--sub-back-color=<color>` | 字幕后景色 |
| `--sub-font=<font>` | 字幕字体 |
| `--sub-fonts-dir=<dir>` | 字幕字体目录 |
| `--sub-ass-override=<mode>` | ASS覆盖模式 |
| `--sub-auto=<mode>` | 自动加载字幕 (`fuzzy`) |
| `--sub-use-margins` | 使用边距 |
| `--sub-ass-use-video-data` | ASS使用视频数据 |

### 字幕文件选项
| 选项 | 说明 |
|------|------|
| `--sub-files=<files>` | 外部字幕文件列表 |
| `--slang=<languages>` | 首选字幕语言 |

### 轨道选项
| 选项 | 说明 |
|------|------|
| `--aid=<id|auto|no>` | 音频轨道 |
| `--vid=<id|auto|no>` | 视频轨道 |
| `--sid=<id|auto|no>` | 字幕轨道 |
| `--alang=<codes>` | 首选音频语言 |
| `--slang=<codes>` | 首选字幕语言 |

### 输入/控制选项
| 选项 | 说明 |
|------|------|
| `--input-ipc-server=<path>` | IPC服务器路径 |
| `--input-file=<file>` | 输入命令文件 |
| `--input-test` | 测试模式 |

### 日志选项
| 选项 | 说明 |
|------|------|
| `--log-file=<path>` | 日志文件 |
| `--msg-level=<level>` | 消息级别 |

### 其他选项
| 选项 | 说明 |
|------|------|
| `--save-position-on-quit` | 退出时保存播放位置 |
| `--watch-later-options=<list>` | 恢复播放选项 |
| `--config=yes/no` | 是否加载配置文件 |
| `--config-dir=<path>` | 配置目录 |
| `--ytdl=yes/no` | 是否使用youtube-dl |
| `--profile=<name>` | 配置Profile |

---

## 5. 硬件解码 (Hardware Decoding)

### 常用模式
| 模式 | 说明 |
|------|------|
| `no` | 禁用硬件解码 |
| `auto` | 自动选择最佳硬件解码 |
| `drmprime` | DRM Prime (Linux推荐) |
| `mediacodec` | MediaCodec (Android) |
| `videotoolbox` | VideoToolbox (macOS/iOS) |

### DRM Prime 示例配置
```swift
player.setOptionString(.hwdec, "drmprime")
player.setOptionString(.vo, "libmpv")
```

---

## 6. 颜色格式

mpv使用hex格式的颜色：`#RRGGBB` 或 `#AARRGGBB`

### 示例
```swift
// 白色
"#FFFFFF"

// 半透明黑色 (50% alpha)
"#00000080"

// 红色
"#FF0000"
```

---

## 7. 常见用法示例

### 初始化
```swift
guard let mpv = MPV() else { return }
mpv.setOptionString(.hwdec, "drmprime")
mpv.initialize()
```

### 加载文件
```swift
mpv.loadFile("/path/to/video.mkv")
```

### 播放控制
```swift
// 暂停
mpv.playback.isPaused = true

// 切换暂停
mpv.playback.togglePause()

// 设置速度
mpv.playback.setSpeed(1.5)
```

### 时间控制
```swift
// 获取当前位置
let pos = mpv.time.position

// 跳转
mpv.time.seek(to: 120.0)  // 跳转到2分钟

// 获取时长
let dur = mpv.time.duration
```

### 音频控制
```swift
// 设置音量
mpv.audio.volume = 80

// 静音
mpv.audio.isMuted = true

// 切换音轨
mpv.audio.audioId = 2
```

### 字幕控制
```swift
// 设置字幕延迟
mpv.subtitle.delay = 1.5  // 延迟1.5秒

// 添加外部字幕
mpv.subtitle.addExternal(path: "/path/to/sub.srt")

// 设置字幕样式
mpv.subtitle.fontSize = 50
mpv.subtitle.color = UIColor.white
```

### 截图
```swift
// 截图（包含字幕）
mpv.screenshot.capture()

// 截图（不包含字幕）
mpv.screenshot.captureWithoutSubtitle()

// 保存到文件
mpv.screenshot.saveToFile(path: "/tmp/screenshot.png")
```

---

## 8. 官方文档链接

- 主文档: https://mpv.io/manual/stable/
- 属性列表: https://mpv.io/manual/stable/#properties
- 命令列表: https://mpv.io/manual/stable/#command-interface
- 选项列表: https://mpv.io/manual/stable/#options
- libmpv C API: https://mpv.io/manual/stable/#c-api
