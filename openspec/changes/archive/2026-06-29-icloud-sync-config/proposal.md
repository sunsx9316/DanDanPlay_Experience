## Why

弹弹Play 目前所有偏好设置和播放进度都只存储在本地 UserDefaults，用户在 iPhone、iPad、Mac 之间使用时需要重复配置，也无法跨设备续播。通过 iCloud 同步可以让用户在多设备间获得一致的体验。

## What Changes

- **@StoreWrapper 扩展 syncToCloud 参数**：StoreWrapper 新增 `syncToCloud: Bool` 参数（默认 `false`），在属性声明处直接标注是否同步。init 时自动将 key 注册到 `Store.syncedKeyNames`
- **泛型 Storeable 扩展**：新增 `Array: Storeable where Element: Codable` 和 `Optional: Storeable where Wrapped: Storeable` 两个泛型扩展。任何 Codable 类型只需实现基础 Storeable，其数组和 Optional 变体自动支持
- **Preferences 属性统一为 @StoreWrapper**：利用泛型 Storeable 扩展，将 `pcLoginInfos`、`subtitleLoadOrder`、`filterDanmakus` 等手写 JSON getter/setter 改为 `@StoreWrapper`，删除约 150 行重复代码
- **播放进度 iCloud 同步**：HistoryManager 改为走 Store 层，使其播放进度和最后观看时间可同步
- **设置页 iCloud 同步开关**：在设置页新增"iCloud 同步"开关，用户可自主控制是否开启同步。开关状态存储在本地（不同步），默认为关闭。副标题实时展示同步状态（已同步/同步中/失败原因），失败时支持重试
- **冲突处理**：开启同步时若本地和 iCloud 都有值且不一致，弹窗让用户选择：使用本地、使用 iCloud、或进入详情页逐项查看差异并决定
- **监听外部变更**：收到 `NSUbiquitousKeyValueStoreDidChangeExternallyNotification` 后更新本地值和 UI

## Capabilities

### New Capabilities

- `icloud-config-sync`: 偏好设置通过 iCloud 在多设备间自动同步，基于 StoreWrapper 声明式同步标注、多后端 Store 架构、冲突处理
- `icloud-history-sync`: 播放进度和最后观看时间通过 iCloud 同步，支持跨设备续播

### Modified Capabilities

（无现有 spec 需要修改）

## Impact

- **Store.swift**：重构为多后端路由器（LocalStoreBackend + UbiquitousStoreBackend），新增同步状态枚举、状态查询、冲突检测、合并逻辑
- **Preferences.swift**：各属性 `@StoreWrapper` 增加 `syncToCloud` 标注；新增 `icloudSyncEnabled` 属性（存储在本地，不同步）
- **Store+Extension.swift**：新增 `Array: Storeable where Element: Codable`、`Optional: Storeable where Wrapped: Storeable` 泛型扩展；新增 `AnixLoginInfo: Storeable`；删除 `extension AnixLoginInfo?: Storeable`（泛型 Optional 自动覆盖）
- **HistoryManager.swift**：不变（走 Store.shared，后端的 syncedKeys 自动覆盖其 key）
- **GlobalSettingModel.swift**：新增 `.icloudSync` case 的处理逻辑，包含同步状态查询、失败重试
- **Enum.swift**：`GlobalSettingType` 新增 `.icloudSync` case
- **新增文件**：`LocalStoreBackend.swift`、`UbiquitousStoreBackend.swift`、`SyncConflictResolver.swift`、`SyncConflictViewController.swift`（冲突详情页）
- **Capabilities**：三个 target（iOS/tvOS/macOS）需添加 iCloud capability 和 entitlements
- **依赖**：无新第三方依赖，仅使用系统框架 `NSUbiquitousKeyValueStore`
