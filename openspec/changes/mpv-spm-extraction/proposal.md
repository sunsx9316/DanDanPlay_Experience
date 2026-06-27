## Why

当前 MPVFramework 是一个 Xcode target（动态 framework），包含 8 份源文件（Core 4 + 集成层 4），直接依赖远程 SPM `mpvkit/MPVKit`。这导致：
- Core 层（纯 mpv C API → Swift API 映射）无法独立版本化和复用
- 每次创建新平台 target 都需要手动在 pbxproj 中添加 Core 文件引用
- 新增 MPV 属性/API 时需在多处同步

## What Changes

- **新建 SPM 包 `Share/MPVFramework/`**：产出 `MPVFramework` 动态库，包含 Core 4 文件
- **删除 `MPVFramework` Xcode target**（iOS/tvOS/Mac 三平台）：Core 文件改用 SPM 引入
- **集成层 4 文件移入 AniXPlayer target**：`MPVPlayerWrapper.swift`、`MPVPiPProvider.swift`、`MPVFrameRenderer.swift`、`MPVRenderContext.swift`
- **AniXPlayer 直接依赖新 SPM**：替代原来对 MPVFramework.framework 的 weak link

## Capabilities

### New Capabilities

- `mpv-spm`: 独立的 SPM 包，产出 `MPVFramework` 动态库，封装 mpv C API 为类型安全 Swift API

### Modified Capabilities

- `mpv-core`: Core 4 文件从 Xcode target 迁移到 SPM 包
- `mpv-integration`: 集成层 4 文件从 MPVFramework target 迁移到 AniXPlayer target

### Removed Capabilities

- `mpvframework-target`: 删除三平台的 MPVFramework Xcode target

## Impact

- **新增**: `Share/MPVFramework/`（`Package.swift` + `Sources/`）
- **删除**: 3 个 pbxproj 中 MPVFramework target 的所有引用
- **修改**: 集成层 4 文件的 target membership（MPVFramework → AniXPlayer）
- **编译验证**: iOS 真机编译通过
