## ADDED Requirements

### Requirement: Watch Progress iCloud Sync

HistoryManager 中的播放进度 SHALL 通过 Store.shared 读写，从而支持 iCloud 同步。用户在一个设备上的观看进度可以同步到其他设备。

#### Scenario: Store watch progress on one device
- **WHEN** 用户在设备 A 上观看视频到 30 分钟处
- **THEN** `HistoryManager.shared.storeWatchProgress(media:progress:)` 通过 `Store.shared` 写入进度数据，该数据同时写入本地 UserDefaults 和 NSUbiquitousKeyValueStore

#### Scenario: Resume watch progress on another device
- **WHEN** 用户在设备 B 上打开同一个视频
- **THEN** `HistoryManager.shared.watchProgress(media:)` 通过 `Store.shared` 读取到设备 A 保存的进度，返回 30 分钟

#### Scenario: Watch progress sync when iCloud unavailable
- **WHEN** 设备未登录 iCloud，用户保存观看进度
- **THEN** 进度仅写入本地 UserDefaults，不影响正常使用，等待 iCloud 恢复后自动同步

### Requirement: Last Watch Date iCloud Sync

HistoryManager 中的最后观看时间 SHALL 通过 Store.shared 读写，支持跨设备同步。

#### Scenario: Sync last watch date
- **WHEN** 用户在设备 A 上观看视频
- **THEN** `HistoryManager.shared.storeLastWatchDate(media:date:)` 通过 `Store.shared` 写入最后观看时间，该时间可同步到其他设备

#### Scenario: Read synced last watch date on another device
- **WHEN** 用户在设备 B 上查看播放历史
- **THEN** `HistoryManager.shared.lastWatchDate(media:)` 通过 `Store.shared` 读取到设备 A 记录的最后观看时间

### Requirement: HistoryManager Uses Store Layer

HistoryManager SHALL 不再直接操作 `UserDefaults.standard`，改为通过 `Store.shared` 读写数据。

#### Scenario: HistoryManager writes through Store
- **WHEN** HistoryManager 需要持久化播放进度字典到 `DDPWatchTimeHistory` key
- **THEN** 调用 `Store.shared.set(dictionary, forKey: "DDPWatchTimeHistory")` 而非 `UserDefaults.standard.set(dictionary, forKey: "DDPWatchTimeHistory")`

#### Scenario: HistoryManager reads through Store
- **WHEN** HistoryManager 需要读取播放进度字典
- **THEN** 调用 `Store.shared.value(forKey: "DDPWatchTimeHistory")` 而非 `UserDefaults.standard.value(forKey: "DDPWatchTimeHistory")`

### Requirement: History Data Types Support Storeable Protocol

播放历史的数据类型（`[String: TimeInterval]`）SHALL 支持 `Storeable` 协议，以便通过 `Store.shared` 读写。

#### Scenario: Watch progress dictionary conforms to Storeable
- **WHEN** `Store.shared.set` 或 `Store.shared.value` 操作 `[String: TimeInterval]` 类型
- **THEN** 数据正确序列化和反序列化

#### Scenario: Legacy data migration
- **WHEN** 用户从旧版本升级到新版本
- **THEN** 之前存储在 UserDefaults 中的播放历史数据（`DDPWatchTimeHistory`、`DDPLatWatchDateHistory`）在新 Store 架构下仍然可读
