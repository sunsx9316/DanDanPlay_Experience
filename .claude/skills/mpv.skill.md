---
name: mpv-reference
description: mpv播放器适配参考 - 修改MPV.swift或mpv相关代码前必读
---
# mpv 参考手册

## 触发条件
当用户要求修改 `MPV.swift`、mpv wrapper、libmpv 封装或任何与mpv播放器相关的代码时，必须先阅读此skill。

## 核心文档
mpv API参考文档位于：
```
.claude/skills/mpv_api_reference.md
```

## 使用流程

1. **修改代码前**：先阅读 `mpv_api_reference.md`，确认要使用的属性、命令、选项
2. **编写代码时**：参考文档中的用法示例，确保类型和参数正确
3. **检查兼容性**：确认使用的mpv API在目标版本（VLC 3.6.0分支）可用

## 快速查询

### 属性命名
- 使用 `MPVProperty` 枚举（已封装），不要硬编码字符串
- 示例：`MPVProperty.pause` 而不是 `"pause"`

### 命令执行
- 使用 `MPVCommand` 枚举（已封装）
- 示例：`MPVCommand.loadFile`

### API模块
| 模块 | 用途 |
|------|------|
| `mpv.playback` | 播放控制、暂停、速度 |
| `mpv.time` | 时间位置、跳转、时长 |
| `mpv.audio` | 音频轨道、音量、静音 |
| `mpv.video` | 视频轨道、全屏、硬件解码 |
| `mpv.subtitle` | 字幕轨道、延迟、样式 |
| `mpv.track` | 轨道信息查询 |
| `mpv.screenshot` | 截图功能 |

## 注意事项
- mpv属性名使用 kebab-case（如 `playback-time`）
- 颜色使用hex格式：`#RRGGBB` 或 `#AARRGGBB`
- 硬件解码推荐使用 `drmprime`（Linux）
- **修改 `MPV.swift` 的 API 时，必须同步检查并修改所有调用点**，确保参数类型和含义一致
- 详细的API说明见 `mpv_api_reference.md`
