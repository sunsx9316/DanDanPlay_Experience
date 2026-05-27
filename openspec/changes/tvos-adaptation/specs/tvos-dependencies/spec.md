## ADDED Requirements

### Requirement: TVVLCKit 集成
tvOS 工程 SHALL 使用 `Share/TVVLCKit/` 中的 TVVLCKit.xcframework 作为视频播放内核。

#### Scenario: TVVLCKit 编译链接成功
- **WHEN** 编译 tvOS target
- **THEN** TVVLCKit.xcframework 被正确链接，`import TVVLCKit` 可用

#### Scenario: VLC 播放器可正常初始化
- **WHEN** 应用启动并创建 VLC 播放器实例
- **THEN** VLC 播放器对象创建成功，不报错

### Requirement: ANXLog tvOS 平台支持
ANXLog 的 Package.swift SHALL 声明 tvOS 平台支持（`.tvOS(.v13)`）。

#### Scenario: ANXLog 在 tvOS 上编译通过
- **WHEN** 编译 tvOS target
- **THEN** `import ANXLog` 可用，日志输出正常

### Requirement: ANXLog mars 降级
当 mars.framework 无 tvOS 版本时，ANXLog SHALL 自动降级为 os_log 输出。

#### Scenario: tvOS 上日志降级生效
- **WHEN** 在 tvOS 上调用 `ANX.logInfo()`
- **THEN** 日志通过 os_log 输出
- **AND** 不会因 mars 不可用而崩溃

### Requirement: CocoaPods 依赖安装
tvOS 的 pod install SHALL 仅安装 tvOS 兼容的 pods。

#### Scenario: pod install 结果正确
- **WHEN** 在 `tvOS/` 目录运行 `pod install`
- **THEN** 安装的 Pods 目录中仅包含 MMKV、AMSMB2、GCDWebServer、ANXLog
- **AND** 不包含 MobileVLCKit、FSPagerView、JXCategoryView、FirebaseCrashlytics

### Requirement: 无 FirebaseCrashlytics 依赖
tvOS 工程 SHALL NOT 依赖 FirebaseCrashlytics，崩溃日志通过系统方式收集。

#### Scenario: 无 Firebase 引用
- **WHEN** 检查 tvOS 工程文件
- **THEN** Podfile 中不包含 FirebaseCrashlytics
- **AND** 源代码中无 `import FirebaseCrashlytics`

### Requirement: GCDWebServer 文件上传
GCDWebServer SHALL 在 tvOS 前台运行时正常工作，支持通过局域网浏览器上传文件。

#### Scenario: 文件上传服务启动
- **WHEN** 用户启动 HTTP 文件上传功能
- **THEN** GCDWebServer 在指定端口启动
- **AND** 局域网内设备可通过浏览器访问上传页面
