## Context

`MPV.swift` 是 MPV 播放器的 Swift 封装层，位于 `Share/CocoaShare/MediaPlayer/Wrapper/MPV/`。它通过 libmpv C API 暴露类型安全的 Swift 接口给上层（MPVPlayerWrapper、MPVPiPProvider 等）使用。

原有文件 1133 行，包含：
- `MPV` 主类 + 嵌套类型（Event、Property<ValueType>、Command 等）
- ~80 个 static property 定义（pause、mute、volume、timePos…）
- 6 个 API 外观类（PlaybackAPI、TimeAPI、AudioAPI、VideoAPI、SubtitleAPI、TrackAPI）
- Track 相关类型（TrackInfo、AudioTrack、SubtitleTrack、VideoTrack）
- MPVColor 的 hex 转换扩展

拆分目标：核心类型保留在主文件，属性定义、API 外观、颜色工具独立成文件，均收入 `Core/` 子目录。

## Goals / Non-Goals

**Goals:**
- 将 1133 行文件拆分为 4 个职责清晰的文件
- 核心嵌套类型保留在 `MPV.swift`（Swift 不支持在 extension 中定义嵌套类型）
- 4 个 core 文件放入 `MPV/Core/` 子目录，与其他 wrapper 文件区分
- 3 个平台的 pbxproj 同步更新

**Non-Goals:**
- 不修改任何外部 API 接口
- 不改变 Property 泛型 struct 的类型安全设计
- 不修改 pbxproj 中非 MPV 相关的 group 结构

## Decisions

### 1. 拆分策略：按职责而非按类型

**选择**：按语义职责拆分为 4 个文件，而非按 Swift 类型（class/struct/enum/extension）

| 文件 | 内容 | 理由 |
|------|------|------|
| `MPV.swift` | 核心类 + 嵌套类型 + 核心方法 | 嵌套类型必须在类体内 |
| `MPVProperty+Values.swift` | 所有 `static let` 属性定义 | 纯数据定义，独立维护 |
| `MPV+APIs.swift` | 6 个 API 外观类 + Track 类型 | 对上层暴露的外观接口 |
| `MPVColor+Hex.swift` | MPVColor hex 转换 | 独立工具扩展 |

**替代方案**：按类型拆分（enums.swift / structs.swift / extensions.swift）→ 不直观，修改一个功能需跨多个文件

### 2. 子目录命名：`Core/`

**选择**：`MPV/Core/` 存放核心封装文件

**理由**：
- 与同目录下的 `MPVPlayerWrapper.swift`、`MPVPiPProvider.swift` 等上层 wrapper 区分
- 语义清晰——Core 是底层 mpv C API 的类型安全封装，Wrapper 是播放器协议适配

### 3. pbxproj 操作策略：找已有 group 直接添加引用

**选择**：找到已有的 MPV group（包含 MPV.swift 的那个），在其下创建 Core subgroup，直接 `new_reference` 添加文件引用

**理由**：
- 避免 `ensure_group` 模式创建重复 group 层级
- `scripts/add_to_project.rb` 的 `infer_target_name` 硬编码 `AniXPlayer`，而 MPV 代码属于 `MPVFramework` target
- `remove_from_project` 会同时移除 group 和 build phase 引用，需谨慎使用

**教训**：
- 操作 pbxproj 时，先找已有 group，直接操作它
- `remove_from_project` 后需重新 `add_file_reference` 到正确的 target
- 每次移动文件后立即验证 build phase 文件列表

## File Structure (Final)

```
Share/CocoaShare/MediaPlayer/Wrapper/MPV/
├── Core/
│   ├── MPV.swift                  # 核心类 + 嵌套类型 + 核心方法 (584 行)
│   ├── MPVProperty+Values.swift   # 属性静态定义 (89 行)
│   ├── MPV+APIs.swift             # API 外观类 + Track 类型 (340 行)
│   └── MPVColor+Hex.swift         # 颜色 hex 转换 (55 行)
├── MPVFrameRenderer.swift         # 帧渲染器
├── MPVPiPProvider.swift           # 画中画提供者
├── MPVPlayerWrapper.swift         # 播放器协议适配
└── MPVRenderContext.swift         # 渲染上下文
```

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|---------|
| pbxproj 操作可能引入 group 重复或 build phase 丢失 | 操作后立即编译验证，发现问题及时 `git checkout` 恢复 |
| 文件移动后 import 路径可能断裂 | 所有文件在同一 module（MPVFramework）内，无需 import 调整 |
| Mac 工程可能因缺少真机无法验证 | 至少保证 pbxproj 结构一致，CI 中验证 |
