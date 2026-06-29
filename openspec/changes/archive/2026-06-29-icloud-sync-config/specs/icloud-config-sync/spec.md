## ADDED Requirements

### Requirement: Generic Storeable Extensions

系统 SHALL 提供 `Array: Storeable where Element: Codable`、`Dictionary: Storeable where Key: Codable, Value: Codable`、`Optional: Storeable where Wrapped: Storeable` 三个泛型扩展，使得 Codable 类型的数组和字典、Storeable 类型的 Optional 自动获得 Storeable 能力。

#### Scenario: Codable array becomes Storeable automatically
- **WHEN** `LoginInfo` 是 Codable，`[LoginInfo]` 需要 Storage 支持
- **THEN** `Array where Element: Codable` 自动让 `[LoginInfo]` 实现 Storeable（F = Data，JSON 编解码），无需额外代码

#### Scenario: Optional of Storeable becomes Storeable automatically
- **WHEN** `[LoginInfo]` 已实现 Storeable
- **THEN** `Optional where Wrapped: Storeable` 自动让 `[LoginInfo]?` 实现 Storeable，无需额外代码

#### Scenario: Codable type with basic conformance gets full chain
- **WHEN** `AnixLoginInfo` 实现基础 Storeable（`F = Data`，Codable 编解码）
- **THEN** `AnixLoginInfo?` 通过泛型 Optional 自动获得 Storeable 能力

#### Scenario: Dictionary with Codable key/value becomes Storeable
- **WHEN** `[String: TimeInterval]` 需要 Storage 支持
- **THEN** `Dictionary where Key: Codable, Value: Codable` 自动让 `[String: TimeInterval]` 实现 Storeable（F = Data，JSON 编解码）

#### Scenario: Manual JSON properties converted to @StoreWrapper
- **WHEN** 泛型 Storeable 扩展完成
- **THEN** `pcLoginInfos`、`subtitleLoadOrder`、`filterDanmakus` 等属性可改为 `@StoreWrapper` 一行声明，删除手动 JSON getter/setter

### Requirement: Multi-backend Store Architecture

Store 类 SHALL 支持多后端架构，包含本地后端（UserDefaults）和 iCloud 后端（NSUbiquitousKeyValueStore），根据同步 key 白名单自动路由读写。

#### Scenario: Read from local backend when key is not synced
- **WHEN** key 不在 `Store.syncedKeyNames`中
- **THEN** Store 直接从 `LocalStoreBackend`（UserDefaults）读取值

#### Scenario: Read from iCloud backend when key is synced and available
- **WHEN** key 在 `Store.syncedKeyNames`中，且 `UbiquitousStoreBackend.isAvailable == true`，且 iCloud 中存在该 key
- **THEN** Store 返回 iCloud 中的值

#### Scenario: Fallback to local when iCloud is unavailable
- **WHEN** key 在 `Store.syncedKeyNames`中，但 `UbiquitousStoreBackend.isAvailable == false`（用户未登录 iCloud 或网络不可用）
- **THEN** Store 降级从 `LocalStoreBackend` 读取值

#### Scenario: Write to both backends for synced keys
- **WHEN** 调用 `Store.shared.set(value, forKey:)` 且 key 在 `Store.syncedKeyNames`中，且 cloud backend 可用
- **THEN** 值同时写入 `LocalStoreBackend` 和 `UbiquitousStoreBackend`

#### Scenario: Write only to local for non-synced keys
- **WHEN** 调用 `Store.shared.set(value, forKey:)` 且 key 不在 `Store.syncedKeyNames`中
- **THEN** 值仅写入 `LocalStoreBackend`

### Requirement: StoreWrapper Declarative Sync Annotation

系统 SHALL 通过 `@StoreWrapper` 的 `syncToCloud` 参数声明哪些属性参与 iCloud 同步。StoreWrapper init 时自动将 key 注册到 `Store.syncedKeyNames`，无需单独维护白名单。

#### Scenario: Property annotated with syncToCloud
- **WHEN** 开发者定义 `@StoreWrapper(defaultValue: 1, key: .playerSpeed, syncToCloud: true)`
- **THEN** StoreWrapper init 时自动调用 `Store.syncedKeyNames.insert("playerSpeed")`

#### Scenario: Property without syncToCloud
- **WHEN** 开发者定义 `@StoreWrapper(defaultValue: .mpv, key: .playerCore)`（无 syncToCloud 参数）
- **THEN** `playerCore` 不会被注册到 `Store.syncedKeyNames`，仅在本地存储

#### Scenario: Synced keys are automatically collected
- **WHEN** `Preferences.shared` 初始化完成后
- **THEN** `Store.syncedKeyNames` 已包含所有标注 `syncToCloud: true` 的属性 key，可直接用于合并遍历

### Requirement: Conflict Detection and Resolution

系统 SHALL 在开启同步时检测本地与 iCloud 之间的冲突（同一 key 两边都有值且内容不同），并通过弹窗让用户选择如何处理。

#### Scenario: No conflict — silent merge
- **WHEN** 首次同步启动，所有同步 key 的本地值和 iCloud 值一致，或仅一方有值
- **THEN** 系统自动完成合并（仅一方有值 → 推送到另一方），`syncStatus` 变为 `.available`

#### Scenario: Conflict detected — show alert
- **WHEN** 首次同步启动，存在至少一个 key 在本地和 iCloud 中都有值且内容不同
- **THEN** `syncStatus` 变为 `.conflict(conflicts)`，弹出 Alert 标题"同步冲突"，内容提示"N 项设置存在不同值"，提供三个选项："使用本机数据"、"使用 iCloud 数据"、"逐项查看并选择"，以及取消按钮

#### Scenario: User chooses "Use Local"
- **WHEN** 用户在冲突弹窗中选择"使用本机数据"
- **THEN** 所有冲突 key 的本机值推送到 iCloud，`syncStatus` 变为 `.available`，副标题变为"已同步"

#### Scenario: User chooses "Use iCloud"
- **WHEN** 用户在冲突弹窗中选择"使用 iCloud 数据"
- **THEN** 所有冲突 key 以 iCloud 值覆盖本地，`syncStatus` 变为 `.available`，副标题变为"已同步"，发送 `cloudDataDidChange` 通知

#### Scenario: User chooses "View Details"
- **WHEN** 用户在冲突弹窗中选择"逐项查看并选择"
- **THEN** 展示冲突详情页（`SyncConflictViewController`），列出所有冲突项，每项显示本机值和 iCloud 值，用户可逐项选择保留本机或使用 iCloud

#### Scenario: User presses cancel on conflict alert
- **WHEN** 用户在冲突弹窗中按取消
- **THEN** iCloud 同步开关关闭，`syncStatus` 变为 `.disabled`，数据保持原状

#### Scenario: Resolve conflicts from detail page
- **WHEN** 用户在冲突详情页逐项选择后点击"确认并应用"
- **THEN** 系统按用户选择逐项处理（选本机 → 推到 iCloud；选 iCloud → 覆盖本地），`syncStatus` 变为 `.available`，pop 回设置页

#### Scenario: Conflict key display names
- **WHEN** 系统需要展示冲突列表
- **THEN** 每个冲突 key 显示人类可读名称（通过 `SyncConflict.displayName` 映射），而非原始 key 字符串

### Requirement: External Change Notification Handling

系统 SHALL 监听 `NSUbiquitousKeyValueStore.didChangeExternallyNotification` 并在收到通知后更新本地值和 UI。

#### Scenario: Device B changes a synced setting
- **WHEN** 设备 B 修改了同步 key 的值，iCloud 同步到设备 A
- **THEN** 设备 A 收到 `didChangeExternallyNotification` 后，更新本地 UserDefaults 中对应 key 的值，并发送 `cloudDataDidChange` 通知

#### Scenario: UI updates after external change
- **WHEN** `GlobalSettingContext` 的 `BehaviorSubject` 收到 `cloudDataDidChange` 通知
- **THEN** 对应的 BehaviorSubject 更新为最新值，UI 自动刷新

### Requirement: Graceful Degradation When iCloud Unavailable

系统 SHALL 在 iCloud 不可用时自动降级为纯本地模式，不影响正常使用。

#### Scenario: User not signed into iCloud
- **WHEN** 用户未在设备上登录 iCloud 账号
- **THEN** `UbiquitousStoreBackend.isAvailable == false`，所有读写仅走本地后端，功能正常

#### Scenario: iCloud becomes unavailable during use
- **WHEN** 用户在系统设置中登出 iCloud
- **THEN** 系统收到 `CKAccountChanged`（或等效通知）后，将 cloud backend 标记为不可用，后续读写自动降级为本地模式

### Requirement: iCloud Sync Toggle

系统 SHALL 在设置页提供"iCloud 同步"开关，允许用户自主控制是否启用跨设备同步。开关状态存储在本地，不参与同步。副标题 SHALL 实时展示当前同步状态。

#### Scenario: Toggle is off by default
- **WHEN** 用户首次安装新版本
- **THEN** "iCloud 同步"开关为关闭状态，副标题显示"关闭"，所有读写仅走本地后端

#### Scenario: User enables iCloud sync successfully
- **WHEN** 用户打开"iCloud 同步"开关，且已登录 iCloud，且同步成功
- **THEN** Store 调用 `startSync()` 执行首次合并，副标题显示"已同步"

#### Scenario: User enables iCloud sync — iCloud unavailable
- **WHEN** 用户在未登录 iCloud 时打开开关
- **THEN** 开关立即回到关闭状态（或置灰不可操作），副标题显示"需要登录 iCloud"

#### Scenario: Syncing state shown during merge
- **WHEN** `startSync()` 正在执行首次合并
- **THEN** 副标题显示"同步中…"

#### Scenario: Sync fails with error
- **WHEN** 同步过程中 NSUbiquitousKeyValueStore 写入失败（如网络错误、配额超限）
- **THEN** `Store.shared.syncStatus` 变为 `.failed(error)`，副标题显示"同步失败：<错误描述>"（红色文字），开关保持 ON 位

#### Scenario: Retry on tap when failed
- **WHEN** 用户在同步失败状态下点击该设置行
- **THEN** 系统调用 `Store.shared.retrySync()`，重新执行合并，状态变为 `.syncing`，尝试恢复同步

#### Scenario: Retry succeeds
- **WHEN** 重试同步成功
- **THEN** 副标题变为"已同步"

#### Scenario: Retry fails again
- **WHEN** 重试同步再次失败
- **THEN** 副标题再次显示失败原因，开关保持 ON 位，不会自动重试

#### Scenario: User disables iCloud sync
- **WHEN** 用户关闭"iCloud 同步"开关
- **THEN** Store 调用 `stopSync()`，停止读写 cloud 后端，副标题变为"关闭"。已有的本地数据不受影响

#### Scenario: Toggle state is not synced
- **WHEN** 用户在设备 A 打开 iCloud 同步开关
- **THEN** 设备 B 的开关状态不受影响（开关状态存储在 `icloudSyncEnabled` key，该 key 不在 `Store.syncedKeyNames`中）

### Requirement: Backend Abstraction

Store 的 `StoreBackend` 协议 SHALL 提供统一接口，使得未来可以无缝替换 iCloud 后端实现（如从 NSUbiquitousKVS 切换到 CloudKit）而不影响上层代码。

#### Scenario: New backend implementation
- **WHEN** 需要添加新的同步后端（如 `CloudKitStoreBackend`）
- **THEN** 只需实现 `StoreBackend` 协议并在 `Store` 中注册，无需修改 `Preferences.swift`、`@StoreWrapper`、`Storeable` 协议或任何 UI 代码
