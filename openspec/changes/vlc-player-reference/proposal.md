## Why

修改 `VLCPlayerWrapper.swift`、VLC wrapper、VLCKit 封装或任何与 VLC 播放器相关的代码时，必须先查阅这份参考文档，确保选项名称、参数格式、平台限制正确。

## When to Consult

- 修改 `VLCPlayerWrapper.swift` 中的选项配置
- 新增 VLC 播放器特性（字幕、音频、视频参数调整）
- 调试 VLC 相关的播放问题
- 对比 VLC 与 MPV 的选项差异

## Workflow

1. **修改代码前**：阅读 `api-reference.md`，确认要使用的选项和参数
2. **编写代码时**：参考文档中的选项格式，确保选项名称和值正确
3. **检查兼容性**：确认使用的 VLC 选项在目标版本（VLC 3.6.0）可用

## Quick Reference

### VLC 选项格式
- VLC 选项使用 `--option=value` 格式
- 示例：`--subsdec-encoding=UTF-8`

### 字幕选项
| 功能 | 选项 | 说明 |
|------|------|------|
| 字幕编码 | `--subsdec-encoding` | 解决乱码问题 |
| 字幕字体 | `--freetype-font` | 使用字体家族名称 |
| 字幕边距 | `--sub-margin` | 字幕底部间距 |
| 字幕延迟 | `--sub-delay` | 单位为 1/10 秒 |

### 重要限制
- **VLC 不支持 `--sub-fonts-dir`**：VLC 使用系统字体注册表，不支持指定字体目录
- **字体必须通过 UIAppFonts 注册**：在 Info.plist 中添加字体文件
- **ASS 字幕不受 `--freetype-font` 控制**：libass 有自己的字体选择机制
- **VLC 不支持 `--sub-ass-override`**：ASS 字幕样式覆盖选项不可用

### 字体家族名称
| 字体 | 家族名称 |
|------|----------|
| 思源黑体简体中文 | `Source Han Sans SC` |
| 思源黑体繁体中文 | `Source Han Sans TC` |
| 系统默认中文字体 | `PingFang SC` |

### 颜色格式
- VLC freetype 颜色使用**十进制**（如 `16777215` 表示白色）
- 不是十六进制

### 注意事项
- VLCKit 是 Objective-C 封装，不是所有 libvlc API 都暴露
- 播放器选项通过 `VLCMediaPlayer(options:)` 初始化时设置
- **修改 `VLCPlayerWrapper.swift` 的选项时，必须确认选项对字幕渲染器有效**
- 详细 API 参数见 `api-reference.md`
