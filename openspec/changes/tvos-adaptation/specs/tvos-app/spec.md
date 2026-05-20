## ADDED Requirements

### Requirement: tvOS 独立工程结构
系统 SHALL 在 `tvOS/` 目录下创建独立的 Xcode 工程，与 `iOS/` 和 `Mac/` 同级。

#### Scenario: 工程目录存在
- **WHEN** 开发者进入 `tvOS/` 目录
- **THEN** 存在 `AniXPlayer.xcodeproj`、`Podfile`、`AniXPlayer/` 源码目录

#### Scenario: 工程可独立编译
- **WHEN** 运行 `xcodebuild -workspace tvOS/AniXPlayer.xcworkspace -scheme AniXPlayer -destination 'platform=tvOS' build`
- **THEN** 编译成功，无编译错误

### Requirement: tvOS Podfile 配置
tvOS Podfile SHALL 使用 `platform :tvos, '13.0'`，仅包含 tvOS 兼容的依赖。

#### Scenario: pod install 成功
- **WHEN** 在 `tvOS/` 目录运行 `pod install`
- **THEN** 成功安装 MMKV、AMSMB2、GCDWebServer、ANXLog，不包含 MobileVLCKit、FSPagerView、JXCategoryView

### Requirement: tvOS 构建配置
tvOS Target SHALL 使用 `appletvos` SDKROOT，deployment target 为 tvOS 13.0，架构为 arm64。

#### Scenario: 构建配置正确
- **WHEN** 检查 target build settings
- **THEN** `SDKROOT = appletvos`，`TVOS_DEPLOYMENT_TARGET = 13.0`，`TARGETED_DEVICE_FAMILY = 3`

### Requirement: tvOS Info.plist
tvOS 的 Info.plist SHALL 不包含 iOS 专用 Key（`LSRequiresIPhoneOS`、`UISupportedInterfaceOrientations`、URL Schemes），保留 Bonjour 服务声明。

#### Scenario: Info.plist 不包含 iOS 专用 Key
- **WHEN** 检查 `tvOS/AniXPlayer/Info.plist`
- **THEN** 不存在 `LSRequiresIPhoneOS`、`UISupportedInterfaceOrientations`、`CFBundleURLTypes` 中非必需的 scheme
- **AND** 存在 `NSBonjourServices` 包含 `_smb._tcp.`

### Requirement: AppDelegate 入口
tvOS App SHALL 使用传统的 UIWindow + AppDelegate 模式启动，不使用 UIScene。

#### Scenario: 应用启动
- **WHEN** 用户在 Apple TV 上打开 AniXPlayer
- **THEN** 显示 MainViewController（TabBar 根控制器）

### Requirement: Share 代码引用方式
tvOS 工程 SHALL 通过相对路径引用 `Share/CocoaShare/` 中的源文件，不复制到 tvOS 目录。

#### Scenario: 编译时正确解析条件编译
- **WHEN** 编译 tvOS target
- **THEN** Share 文件中的 `#if os(tvOS)` 分支被正确选中
- **AND** `#if os(iOS)` 分支被跳过
