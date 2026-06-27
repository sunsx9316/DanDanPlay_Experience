## Why

`MPV.swift` 原有 1133 行，将 Property 定义、API 外观类、颜色扩展全部混在一个文件里，难以维护。同时 `MPVProperty` 是普通 enum，`setProperty`/`getProperty` 方法接受任意 property + 任意类型的组合，编译器无法阻止类型错误。

## What Changes

- **拆分 MPV.swift**：从 1133 行拆为 4 个文件，收拢到 `Core/` 子目录
  - `MPV.swift`（584 行）：核心类 + 嵌套类型（Event、Property<ValueType>、Command 等）+ 核心方法
  - `MPVProperty+Values.swift`（89 行）：Bool/Int64/Double/String 属性静态定义
  - `MPV+APIs.swift`（340 行）：PlaybackAPI、TimeAPI、AudioAPI、VideoAPI、SubtitleAPI、TrackAPI + Track 类型
  - `MPVColor+Hex.swift`（55 行）：MPVColor 的 hex 字符串互转扩展
- **目录结构**：4 个 core 文件移入 `MPV/Core/` 子目录，与 `MPVPlayerWrapper.swift` 等文件区分
- **Xcode 工程更新**：3 个平台（iOS/tvOS/Mac）的 pbxproj 同步更新 group 结构和 build phase 引用

## Capabilities

### Modified Capabilities

- `mpv-core`: MPV.swift 文件拆分和目录重组，API 接口不变，外部调用无影响

## Impact

- **Share/CocoaShare/MediaPlayer/Wrapper/MPV/**：新增 `Core/` 子目录，4 个文件移入
- **iOS/tvOS/Mac pbxproj**：PBXGroup 结构更新（新增 Core subgroup），PBXBuildFile 引用更新
- **外部接口**：零影响——所有 `mpv.playback.isPaused`、`mpv.audio.volume` 等调用不变
- **编译验证**：iOS BUILD SUCCEEDED，tvOS MPVFramework BUILD SUCCEEDED（AniXPlayer target 因 provisioning 失败，非代码问题）
