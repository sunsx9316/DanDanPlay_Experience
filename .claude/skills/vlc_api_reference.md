# VLC API 参考文档

基于 [VLC command-line help](https://wiki.videolan.org/VLC_command-line_help) 官方文档。

## 1. 视频选项 (Video Options)

### 1.1 视频显示

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--video` | bool | 启用视频 | `--video` / `--no-video` |
| `--fullscreen` | bool | 全屏模式 | `--fullscreen` |
| `--window-fullscreen` | bool | 窗口全屏 | `--window-fullscreen` |
| `--autoscale` | bool | 自动缩放 | `--autoscale` / `--no-autoscale` |
| `--scale` | float | 缩放因子 | `--scale=1.5` |

### 1.2 视频画面

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--aspect-ratio` | string | 源画面比例 | `--aspect-ratio=16:9` |
| `--crop` | string | 视频裁剪 | `--crop=4:3` |
| `--custom-aspect-ratios` | string | 自定义比例 | `--custom-aspect-ratios=1:1,4:3` |
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

### 1.5 视频输出

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--vout` | string | 视频输出模块 | `--vout=gles2` |
| `--gl` | string | OpenGL 扩展 | `--gl=any`, `wgl`, `none` |

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

### 2.4 均衡器

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--equalizer-preset` | string | 预设 | `--equalizer-preset=flat` |
| `--equalizer-bands` | string | 频段增益 | `--equalizer-bands="0 2 4 6 8 10"` |

**预设值:** `flat`, `classical`, `club`, `dance`, `fullbass`, `fullbasstreble`, `fulltreble`, `headphones`, `largehall`, `live`, `party`, `pop`, `reggae`, `rock`, `ska`, `soft`, `softrock`, `techno`

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
| `--sub-type` | string | 强制字幕格式 | `--sub-type=ass` |

**字幕格式:** `auto`, `microdvd`, `subrip`, `subviewer`, `ssa1`, `ssa2-4`, `ass`, `vplayer`, `sami`, `dvdsubtitle`, `mpl2`, `aqt`, `pjs`, `mpsub`, `jacosub`, `psb`, `realtext`, `dks`, `subviewer1`, `sbv`

### 3.4 FreeType 字体渲染

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--freetype-font` | string | 字幕字体家族名 (Font Family Name) | `--freetype-font=Source Han Sans SC` |
| `--freetype-bold` | bool | 强制加粗 | `--freetype-bold` |
| `--freetype-fontsize` | int | 字体大小 | `--freetype-fontsize=48` |
| `--freetype-color` | int | 字体颜色 | `--freetype-color=16777215` (白色) |
| `--freetype-opacity` | int | 不透明度 (0-255) | `--freetype-opacity=255` |

**字体家族名称注意:**
- `--freetype-font` 需要使用**字体家族名称** (Font Family Name)，不是文件名
- 思源黑体 (Source Han Sans) 的字体家族名称是 `Source Han Sans SC` (简体中文) / `Source Han Sans TC` (繁体中文)
- 系统字体如 `Helvetica`, `Arial` 可直接使用

**颜色值 (十六进制):**
- `0x000000` - 黑色
- `0xFF0000` - 红色
- `0x00FF00` - 绿色
- `0xFFFF00` - 黄色
- `0xFFFFFF` - 白色

### 3.5 字幕背景/轮廓

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--freetype-background-opacity` | int | 背景不透明度 | `--freetype-background-opacity=128` |
| `--freetype-outline-opacity` | int | 轮廓不透明度 | `--freetype-outline-opacity=255` |
| `--freetype-outline-thickness` | int | 轮廓粗细 | `--freetype-outline-thickness=4` |
| `--freetype-shadow-opacity` | int | 阴影不透明度 | `--freetype-shadow-opacity=128` |

**轮廓粗细选项:** `0` (无), `2` (细), `4` (正常), `6` (粗)

---

## 4. 播放控制选项 (Playback Control)

### 4.1 播放速度

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--rate` | float | 播放速率 | `--rate=1.0`, `--rate=2.0` |
| `--input-rate` | float | 输入速率 | `--input-rate=1.0` |

### 4.2 跳转/定位

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--start-time` | int | 开始时间 (秒) | `--start-time=60` |
| `--stop-time` | int | 停止时间 (秒) | `--stop-time=120` |
| `--run-time` | int | 运行时间 (秒) | `--run-time=300` |
| `--position` | float | 初始位置 (0-1) | `--position=0.5` |

### 4.3 循环/随机

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--loop` | bool | 循环播放 | `--loop` |
| `--repeat` | bool | 重复播放 | `--repeat` |
| `--random` | bool | 随机播放 | `--random` |

---

## 5. 网络/缓存选项 (Network/Cache Options)

### 5.1 网络协议

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--http-proxy` | string | HTTP 代理 | `--http-proxy=http://proxy:8080` |
| `--http-referrer` | string | HTTP Referrer | `--http-referrer=http://example.com` |
| `--http-user-agent` | string | User-Agent | `--http-user-agent=VLC/3.0` |

### 5.2 缓存

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--file-caching` | int | 文件缓存 (ms) | `--file-caching=300` |
| `--disc-caching` | int | 光盘缓存 (ms) | `--disc-caching=300` |
| `--network-caching` | int | 网络缓存 (ms) | `--network-caching=300` |
| `--live-cache` | int | 直播缓存 (ms) | `--live-cache=300` |

### 5.3 网络协议选项

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--ftp-pwd` | string | FTP 密码 | `--ftp-pwd=secret` |
| `--ftp-user` | string | FTP 用户名 | `--ftp-user=anonymous` |
| `--smb-pwd` | string | SMB 密码 | `--smb-pwd=secret` |
| `--smb-user` | string | SMB 用户名 | `--smb-user=guest` |
| `--http-password` | string | HTTP 密码 | `--http-password=secret` |

---

## 6. 输入/输出选项 (Input/Output Options)

### 6.1 输入模块

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--access` | string | 访问模块 | `--access=http,ftp` |
| `--demux` | string | 解复用器 | `--demux=mp4,avi` |

**常用访问模块:** `any`, `filesystem`, `http`, `ftp`, `smb`, `sftp`, `udp`, `tcp`, `rtp`, `mms`, `nfs`, `dvd`, `cdda`

**常用解复用器:** `any`, `mp4`, `avi`, `asf`, `ogg`, `mkv`, `ts`, `flac`, `mp3`, `mov`

### 6.2 RTSP 选项

| 选项 | 类型 | 说明 | 示例 |
|------|------|------|------|
| `--rtsp-port` | int | RTSP 端口 | `--rtsp-port=554` |
| `--rtsp-timeout` | int | RTSP 超时 (秒) | `--rtsp-timeout=60` |

---

## 7. VLCKit 使用方式

### 7.1 通过 VLCMediaPlayer 初始化选项

```swift
// 创建播放器时传入选项
let options = [
    "--subsdec-encoding=UTF-8",
    "--freetype-font=SourceHanSansSC-Regular",
    "--network-caching=300"
]
let player = VLCMediaPlayer(options: options)
```

### 7.2 通过 VLCMedia 设置选项

```swift
let media = VLCMedia(url: URL)
media.addOptions([
    "subsdec-encoding": "UTF-8",
    "freetype-font": "SourceHanSansSC-Regular"
])
```

### 7.3 动态设置选项

```swift
// 通过 addOption 方法添加选项
player.addOption("--fullscreen")
player.addOption("--sub-margin=30")
```

---

## 8. 与 MPV 选项对比

| 功能 | MPV 选项 | VLC 选项 |
|------|----------|----------|
| 字幕编码 | `--sub-encoding` | `--subsdec-encoding` |
| 字幕字体 | `--sub-font` | `--freetype-font` |
| 字体目录 | `--sub-fonts-dir` | 不支持 (使用系统字体) |
| 硬件加速 | `--hwdec` | `--avcodec-hw` |
| 网络缓存 | `--cache` | `--network-caching` |
| 播放速率 | `--rate` | `--rate` |
| 字幕延迟 | `--sub-delay` | `--sub-delay` |
| 音频延迟 | `--audio-delay` | `--audio-desync` |

---

## 9. 重要注意事项

1. **VLC 不支持 `--sub-fonts-dir`**: VLC 使用系统字体注册表，不支持指定字体目录。字体必须通过 `UIAppFonts` (iOS) 或系统字体目录注册。

2. **VLC 不支持 `--sub-ass-override`**: ASS 字幕样式覆盖选项在 VLC 中不可用。

3. **VLC 选项格式**: VLC 选项使用 `--option=value` 格式，而 VLCKit 可能接受简化的格式。

4. **颜色格式**: VLC 的 freetype 颜色使用十进制 (如 `16777215` 表示白色)，而 MPV 使用十六进制 (如 `0xFFFFFF`)。
