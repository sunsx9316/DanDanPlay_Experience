# VLC API 参考文档

基于 [VLC command-line help](https://wiki.videolan.org/VLC_command-line_help) 官方文档。

## 1. 视频选项 (Video Options)

### 1.1 视频显示

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--video` | bool | 启用视频 | `--video` / `--no-video` |
| `--fullscreen` | bool | 全屏模式 | `--fullscreen` |
| `--autoscale` | bool | 自动缩放 | `--autoscale` / `--no-autoscale` |
| `--scale` | float | 缩放因子 | `--scale=1.5` |

### 1.2 视频画面

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--aspect-ratio` | string | 源画面比例 | `--aspect-ratio=16:9` |
| `--crop` | string | 视频裁剪 | `--crop=4:3` |
| `--deinterlace` | int | 反交错 (0=关闭, -1=自动, 1=开启) | `--deinterlace=1` |
| `--deinterlace-mode` | string | 反交错模式 | `--deinterlace-mode=yadif` |

**Deinterlace 模式:** `auto`, `discard`, `blend`, `mean`, `bob`, `linear`, `x`, `yadif`, `yadif2x`, `phosphor`, `ivtc`

### 1.3 视频颜色/图像调整

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--brightness` | float | 亮度 (0-2) | `--brightness=1.5` |
| `--contrast` | float | 对比度 (0-2) | `--contrast=1.2` |
| `--saturation` | float | 饱和度 (0-3) | `--saturation=1.5` |
| `--hue` | float | 色调 (-180 to 180) | `--hue=30` |
| `--gamma` | float | 伽马值 | `--gamma=2.2` |

### 1.4 硬件解码

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--avcodec-hw` | string | 硬件加速解码 | `--avcodec-hw=any` |

**硬件加速选项:** `any`, `d3d11va`, `dxva2`, `none`

---

## 2. 音频选项 (Audio Options)

### 2.1 音频控制

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--audio` | bool | 启用音频 | `--audio` / `--no-audio` |
| `--volume` | int | 音量 (0-320) | `--volume=200` |
| `--volstep` | int | 音量步进 | `--volstep=2` |

### 2.2 音频轨道

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--audio-track` | int | 音频轨道编号 | `--audio-track=0` |
| `--audio-track-id` | int | 音频轨道 ID | `--audio-track-id=1` |
| `--audio-language` | string | 音频语言 | `--audio-language=eng,chn` |

### 2.3 音频处理

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--audio-filter` | string | 音频滤镜 | `--audio-filter=normvol` |
| `--audio-resampler` | string | 重采样器 | `--audio-resampler=samplerate` |
| `--audio-time-stretch` | bool | 时间拉伸 | `--audio-time-stretch` |
| `--audio-desync` | int | 音频延迟补偿 (ms) | `--audio-desync=100` |

---

## 3. 字幕选项 (Subtitle Options)

### 3.1 字幕基础

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--sub-file` | string | 外部字幕文件 | `--sub-file=/path/to/sub.srt` |
| `--sub-autodetect-file` | bool | 自动检测字幕 | `--sub-autodetect-file` |
| `--sub-track` | int | 字幕轨道编号 | `--sub-track=0` |
| `--sub-track-id` | int | 字幕轨道 ID | `--sub-track-id=1` |
| `--sub-language` | string | 字幕语言 | `--sub-language=chi,eng` |

### 3.2 字幕编码 (重要!)

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--subsdec-encoding` | string | 文本字幕编码 | `--subsdec-encoding=UTF-8` |

**常用编码值:**
- `UTF-8` - 通用编码 (推荐)
- `GB18030` - 简体中文
- `GBK` - 简体中文 (扩展)
- `BIG5` - 繁体中文
- `Shift_JIS` - 日文
- `Windows-1252` - 西欧语言

### 3.3 字幕显示

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--sub-margin` | int | 字幕底部间距 | `--sub-margin=20` |
| `--sub-text-scale` | int | 字幕缩放 (10-500%) | `--sub-text-scale=100` |
| `--sub-delay` | int | 字幕延迟 (1/10秒) | `--sub-delay=100` 表示10秒 |

### 3.4 FreeType 字体渲染

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--freetype-font` | string | 字幕字体家族名 (Font Family Name) | `--freetype-font=Source Han Sans SC` |
| `--freetype-bold` | bool | 强制加粗 | `--freetype-bold` |
| `--freetype-fontsize` | int | 字体大小 | `--freetype-fontsize=48` |
| `--freetype-color` | int | 字体颜色 (十进制) | `--freetype-color=16777215` (白色) |
| `--freetype-opacity` | int | 不透明度 (0-255) | `--freetype-opacity=255` |

**字体家族名称注意:**
- `--freetype-font` 需要使用**字体家族名称**，不是文件名
- 思源黑体的字体家族名称是 `Source Han Sans SC` (简体) / `Source Han Sans TC` (繁体)
- 系统字体如 `Helvetica`, `Arial` 可直接使用

**颜色值 (十进制):**
- `0` - 黑色
- `16711680` - 红色
- `65280` - 绿色
- `16776960` - 黄色
- `16777215` - 白色

### 3.5 字幕背景/轮廓

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--freetype-background-opacity` | int | 背景不透明度 | `--freetype-background-opacity=128` |
| `--freetype-outline-opacity` | int | 轮廓不透明度 | `--freetype-outline-opacity=255` |
| `--freetype-outline-thickness` | int | 轮廓粗细 | `--freetype-outline-thickness=4` |
| `--freetype-shadow-opacity` | int | 阴影不透明度 | `--freetype-shadow-opacity=128` |

---

## 4. 播放控制选项 (Playback Control)

### 4.1 播放速度

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--rate` | float | 播放速率 | `--rate=1.0`, `--rate=2.0` |

### 4.2 跳转/定位

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--start-time` | int | 开始时间 (秒) | `--start-time=60` |
| `--stop-time` | int | 停止时间 (秒) | `--stop-time=120` |
| `--run-time` | int | 运行时间 (秒) | `--run-time=300` |

### 4.3 循环/随机

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--loop` | bool | 循环播放 | `--loop` |
| `--repeat` | bool | 重复播放 | `--repeat` |
| `--random` | bool | 随机播放 | `--random` |

---

## 5. 网络/缓存选项 (Network/Cache Options)

### 5.1 缓存

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--file-caching` | int | 文件缓存 (ms) | `--file-caching=300` |
| `--network-caching` | int | 网络缓存 (ms) | `--network-caching=300` |
| `--live-cache` | int | 直播缓存 (ms) | `--live-cache=300` |

---

## 6. VLCKit 使用方式

### 6.1 通过 VLCMediaPlayer 初始化选项

```swift
let options = [
    "--subsdec-encoding=UTF-8",
    "--freetype-font=SourceHanSansSC-Regular",
    "--network-caching=300"
]
let player = VLCMediaPlayer(options: options)
```

### 6.2 通过 VLCMedia 设置选项

```swift
let media = VLCMedia(url: URL)
media.addOptions([
    "subsdec-encoding": "UTF-8",
    "freetype-font": "SourceHanSansSC-Regular"
])
```

---

## 7. 与 MPV 选项对比

| 功能 | MPV 选项 | VLC 选项 | 差异 |
|------|----------|----------|------|
| 字幕编码 | `--sub-encoding` | `--subsdec-encoding` | 选项名不同 |
| 字幕字体 | `--sub-font` | `--freetype-font` | 选项名不同 |
| 字体目录 | `--sub-fonts-dir` | 不支持 | VLC 使用系统字体 |
| 硬件加速 | `--hwdec` | `--avcodec-hw` | 选项名不同 |
| 网络缓存 | `--cache` | `--network-caching` | 选项名不同 |
| 播放速率 | `--rate` | `--rate` | 相同 |
| 字幕延迟 | `--sub-delay` | `--sub-delay` | 相同 (单位不同) |
| 音频延迟 | `--audio-delay` | `--audio-desync` | 选项名不同 |
| ASS 覆盖 | `--sub-ass-override` | 不支持 | VLC 无此功能 |

---

## 8. 重要注意事项

1. **VLC 不支持 `--sub-fonts-dir`**: VLC 使用系统字体注册表，字体必须通过 `UIAppFonts` (iOS) 或系统字体目录注册。

2. **VLC 不支持 `--sub-ass-override`**: ASS 字幕样式覆盖选项在 VLC 中不可用。

3. **VLC 选项格式**: VLC 选项使用 `--option=value` 格式，而 VLCKit 可能接受简化的格式。

4. **颜色格式**: VLC 的 freetype 颜色使用十进制 (如 `16777215` 表示白色)，而 MPV 使用十六进制 (如 `#FFFFFF`)。

5. **字幕延迟单位**: VLC 的 `--sub-delay` 单位为 1/10 秒，MPV 的 `--sub-delay` 单位为秒。
