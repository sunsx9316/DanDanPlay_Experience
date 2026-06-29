## Context

当前 `Store.swift` 是 UserDefaults 的单层封装，`Preferences.swift` 通过 `@StoreWrapper` 属性包装器读写，`HistoryManager` 直接操作 UserDefaults。所有数据仅存储在本地，无跨设备同步能力。

项目跨 iOS / tvOS / macOS 三平台，使用相同的 `Share/` 共享代码。现有 `Store.swift` 已在 `Preferences` 内部作为 `internal class`，API 稳定且经过类型擦除层（`Storeable` 协议）抽象。

## Goals / Non-Goals

**Goals:**
- Store 类支持多后端（本地 + iCloud），对上层 `@StoreWrapper` 和 `HistoryManager` 透明
- 通过 `NSUbiquitousKeyValueStore` 实现偏好设置和播放进度跨设备同步
- 同步 key 白名单机制，排除设备相关设置和敏感数据
- 首次开启同步时自动合并本地与 iCloud 数据，不丢失用户已有设置
- 监听 iCloud 外部变更，实时更新本地值和 UI

**Non-Goals:**
- 不提供细粒度分类开关（如需精细控制未来可扩展）
- 同步开关状态本身不参与 iCloud 同步（存储在本地）
- 不同步登录凭证（smb/webdav/ftp/emby 等）
- 不使用 CloudKit（容量不够时再迁移，架构已预留扩展点）
- 不涉及 Core Data 或其他持久化方案

## Decisions

### 1. StoreBackend 协议 + 多后端路由

```
                   Preferences.shared
                         │
                   @StoreWrapper
                    (含 syncToCloud)
                         │
                      Store (internal)
                    ┌────┼────┐
                    │    │    │
               local.set │  cloud?.set()
                    │    │    │
                    ▼    ▼    ▼
    ┌─────────────┐  ┌──────────────────┐
    │LocalBackend │  │UbiquitousBackend │
    │(UserDefaults)│  │(NSUbiquitousKVS) │
    └─────────────┘  └──────────────────┘
```

**Store 是 `Preferences` 的内部类，不对外暴露**。所有读写必须通过 `Preferences.shared` 的属性进行，外部代码（`GlobalSettingModel`、`SettingViewController`、`HistoryManager` 等）不得直接引用 `Store.shared`。

**选择**: Store 内部维护 `local: StoreBackend`（必需）和 `cloud: StoreBackend?`（可选，nil 表示不可用/未开启）。不再维护独立的 `syncedKeyNames: Set<String>`，而是通过 `@StoreWrapper` 的静态 registry 直接获取所有同步 key。

**自注册机制**：`@StoreWrapper` 新增 `syncToCloud: Bool` 参数（默认 `false`），init 时将 `(key, syncToCloud)` 注册到 `Store.registry`（Store 类的 static 属性）。Store 通过 `syncedKeyNames` 计算属性从 registry 中提取需同步的 key，无需单独维护白名单。

> 注：由于 Swift 泛型 struct 的 `static var` 是 per-specialization 的（`StoreWrapper<Bool>.allWrappers` ≠ `StoreWrapper<Int>.allWrappers`），不能直接在泛型 StoreWrapper 上用 static 数组。改用 `Store.registry`（Store 类的 `static var`，非泛型）存储所有 wrapper 的注册信息。`registry` 必须在 StoreWrapper 实例初始化之前可用，而 StoreWrapper 在 Preferences 初始化阶段（Phase 1）就会创建，因此 `Store.registry` 作为 `static var` 在类加载时即已就绪。

```swift
// Store 类 — static registry，由 StoreWrapper init 自动填充
internal class Store {
    static var registry: [(key: String, syncToCloud: Bool)] = []
    // ...
}

// StoreWrapper — syncToCloud 作为实例属性暴露，通过 $propertyName.syncToCloud 读取
@propertyWrapper
struct StoreWrapper<Value: Storeable> {
    let syncToCloud: Bool
    let key: KeyName
    private var defaultValue: Value

    init(defaultValue: Value, key: KeyName, syncToCloud: Bool = false) {
        self.defaultValue = defaultValue
        self.key = key
        self.syncToCloud = syncToCloud
        Store.registry.append((key.storeKey, syncToCloud))
    }
    // ...
}

// Store — 从 registry 计算同步 key 列表
private var syncedKeyNames: Set<String> {
    Set(Self.registry.filter(\.syncToCloud).map(\.key))
}
```

**写路径**: local 始终写入；若当前 wrapper 的 `syncToCloud == true` 且 `cloud?.isAvailable == true`，同时写入 cloud。
**读路径**: 若当前 wrapper 的 `syncToCloud == true` 且 cloud 有值，返回 cloud 值；否则返回 local 值。

**备选方案**:
- ~~Store 集中维护 syncedKeyNames~~ → 拒绝，多维护一份数据且需手动 insert（如 sendDanmakuColors）
- 直接用 NSUbiquitousKVS 替换 Store 底层 → 拒绝，因为不是所有 key 都该同步，且需要维护本地 fallback

### 2. NSUbiquitousKeyValueStore 作为同步后端

**选择**: NSUbiquitousKeyValueStore，理由：
- API 与 UserDefaults 几乎一致，Backend 实现简单
- 自动处理 iCloud 账号变更和网络恢复
- 容量 1MB / 1024 keys，当前 ~30 个同步 key，每个 value 不超过几 KB，远未达上限
- 免费，无需额外 Apple Developer 配置（不需要 CloudKit entitlement）

**备选方案**: CloudKit Private Database → 不采用，原因是需要定义 schema、处理 CKAccountChanged、更复杂，且当前数据量远不需要。

### 3. @StoreWrapper 声明式同步标注 + 静态自注册

不再使用 Store 集中白名单，改为 `@StoreWrapper` 参数声明 + 模块级 registry 自注册。每个 `@StoreWrapper` 实例在 init 时将 `(key, syncToCloud)` 注册到 `_storeWrapperRegistry`，Store 通过计算属性从中提取同步 key：

```swift
// 模块级 registry（非泛型，所有 StoreWrapper 共享）
var _storeWrapperRegistry: [(key: String, syncToCloud: Bool)] = []

// StoreWrapper — syncToCloud 暴露为实例属性
@propertyWrapper
struct StoreWrapper<Value: Storeable> {
    let syncToCloud: Bool
    let key: KeyName
    private var defaultValue: Value

    init(defaultValue: Value, key: KeyName, syncToCloud: Bool = false) {
        self.defaultValue = defaultValue
        self.key = key
        self.syncToCloud = syncToCloud
        _storeWrapperRegistry.append((key.storeKey, syncToCloud))
    }
    // ...
}

// Store — 从 registry 计算同步 key 列表
private var syncedKeyNames: Set<String> {
    Set(_storeWrapperRegistry.filter(\.syncToCloud).map(\.key))
}
```

各属性在定义处标注是否同步：

```swift
// Preferences.swift 中的实际标注

// ✅ 同步的
@StoreWrapper(defaultValue: 1, key: .playerSpeed, syncToCloud: true)
var playerSpeed: Double

@StoreWrapper(defaultValue: true, key: .fastMatch, syncToCloud: true)
var fastMatch: Bool

@StoreWrapper(defaultValue: DefaultHost, key: .host, syncToCloud: true)
var host: String

// ❌ 不同步的（syncToCloud 默认 false）
@StoreWrapper(defaultValue: .mpv, key: .playerCore)
var playerCore: MediaPlayer.CoreType

@StoreWrapper(defaultValue: false, key: .playerPiP)
var playerPiP: Bool

@StoreWrapper(defaultValue: .chinese, key: .appLanguage)
var appLanguage: AppLanguage
```

**sendDanmakuColors 改造**：从手写 computed property 改为 `@StoreWrapper`。利用 `Array: Storeable where Element: Storeable, Element.F: Codable` 泛型扩展 + `ANXColor: Storeable`（`F = UInt`），`[ANXColor]` 自动获得 Storeable 能力，无需额外 wrapper 类型：

```swift
// Preferences 中直接使用 @StoreWrapper
@StoreWrapper(defaultValue: Preferences.defaultSendDanmakuColors,
              key: .sendDanmakuColors, syncToCloud: true)
var sendDanmakuColors: [ANXColor]
```

`Array<ANXColor>.toValue()` 的流程：`[ANXColor]` → `map { $0.toValue() }` → `[UInt]` → `JSONEncoder` → `Data`。反之 `create(from:)` 解码流程对称。

**HistoryManager 的 key 迁移**：`DDPWatchTimeHistory` 和 `DDPLatWatchDateHistory` 不再由 HistoryManager 手动注册到 `Store.syncedKeyNames`，而是在 Preferences 中定义 `@StoreWrapper` 属性（见 Section 7）。

**同步 key 汇总**（标注 `syncToCloud: true` 的属性）：

| key | 说明 |
|-----|------|
| playerSpeed, playerMode | 播放偏好 |
| fastMatch, danmakuCacheDay, danmakuSpeed, danmakuAlpha, danmakuArea, showDanmaku, mergeSameDanmaku, danmakuDensity, danmakuEffectStyle, openDanmakuRandomColor, danmakuOffsetTime | 弹幕偏好 |
| subtitleSafeArea, autoLoadCustomDanmaku, autoLoadCustomSubtitle, subtitleLoadOrder, subtitleOffsetTime, subtitleStyle | 字幕偏好 |
| host, customHosts, backupHosts | 网络配置 |
| autoJumpTitleEnding, jumpTitleDuration, jumpEndingDuration | 自动跳过 |
| filterDanmaku | 弹幕屏蔽 |
| fileBrowserSortOption, fileBrowserSortAscending | 文件排序 |
| checkUpdate | 检查更新 |
| sendDanmakuColor, sendDanmakuColors | 弹幕颜色 |
| DDPWatchTimeHistory, DDPLatWatchDateHistory | 播放进度 |

**不同步的 key**（未加 `syncToCloud`，或 `syncToCloud: false`）：
playerCore, playerPiP, miniProgressBar, hwdecEnabled, appLanguage, mainColor, subtitleFontSize, subtitleFontName, subtitleYPosition, subtitleColor, danmakuFontSize（iOS/tvOS 默认值不同）, loginInfo, smbLoginInfo, webDavLoginInfo, ftpLoginInfo, pcLoginInfo, embyLoginInfo, jellyfinLoginInfo, showHomePageTips, lastUpdateVersion, icloudSyncEnabled, aspectRatio, audioOffsetTime

### 4. 泛型 Storeable 扩展

利用 Swift 条件泛型，让 Codable 数组和 Storeable Optional 自动获得 Storeable 能力，避免为每种组合类型写重复的 JSON 编解码代码。

**三个泛型扩展**：

```swift
// 元素为 Storeable 且其 F 为 Codable 的数组 → 自动 Storeable（F = Data，先编解码 [Element.F] 再通过 create/toValue 转换）
extension Array: Storeable where Element: Storeable, Element.F: Codable {
    static func create(from data: Data) -> Array<Element>? {
        guard let elementValues = try? JSONDecoder().decode([Element.F].self, from: data) else { return nil }
        return elementValues.compactMap { Element.create(from: $0) }
    }
    func toValue() -> Data {
        return (try? JSONEncoder().encode(self.map { $0.toValue() })) ?? .init()
    }
}

// 任何 Codable key-value 字典 → 自动 Storeable（F = Data，JSON 编解码）
// 覆盖 [String: TimeInterval] 等播放进度字典
extension Dictionary: Storeable where Key: Codable, Value: Codable {
    static func create(from data: Data) -> Dictionary<Key, Value>? {
        return try? JSONDecoder().decode(Dictionary<Key, Value>.self, from: data)
    }
    func toValue() -> Data {
        return (try? JSONEncoder().encode(self)) ?? .init()
    }
}

// 任何 Storeable 的 Optional → 自动 Storeable（委托给 Wrapped）
extension Optional: Storeable where Wrapped: Storeable {
    static func create(from value: Wrapped.F) -> Optional<Wrapped>? {
        return Wrapped.create(from: value)
    }
    func toValue() -> Wrapped.F {
        return self!.toValue()  // Store.set 在 nil 时先 remove，不会走到这里
    }
}
```

**AnixLoginInfo 只需实现基础 Storeable**：

```swift
extension AnixLoginInfo: Storeable {
    static func create(from data: Data) -> AnixLoginInfo? {
        return try? JSONDecoder().decode(AnixLoginInfo.self, from: data)
    }
    func toValue() -> Data {
        return (try? JSONEncoder().encode(self)) ?? .init()
    }
}
```

**自动推导链**：

```
AnixLoginInfo: Storeable (F = Data)
  → Optional where Wrapped: Storeable → AnixLoginInfo?: Storeable ✅

LoginInfo: Storeable (F = Data)
  → Array where Element: Storeable, Element.F: Codable → [LoginInfo]: Storeable (F = Data)
    → Optional → [LoginInfo]?: Storeable ✅

ANXColor: Storeable (F = UInt, Codable)
  → Array where Element: Storeable, Element.F: Codable → [ANXColor]: Storeable (F = Data) ✅

String: Codable & Storeable (F = String)
  → Array where Element: Storeable, Element.F: Codable → [String]: Storeable (F = Data)
    → Optional → [String]?: Storeable ✅
```

**现有代码删除**：
- `extension AnixLoginInfo?: Storeable` 手动实现 → 删掉，泛型 Optional 自动覆盖

**效果**：Preferences.swift 中所有 JSON 手写 getter/setter（pcLoginInfos ×6、subtitleLoadOrder、customHosts、backupHosts、filterDanmakus 等共约 12 个属性）全部改为 `@StoreWrapper` 一行，删除约 150 行重复样板代码。

### 5. 冲突检测与处理

开启 iCloud 同步时，可能存在本地和 iCloud 对同一个 key 都有值但内容不同的情况。不能静默覆盖，需要让用户决定。

**冲突检测流程**：

```
startSync():
  conflicts = []
  for key in syncedKeyNames:
    localVal = local.get(key)
    cloudVal = cloud.get(key)

    if localVal != nil && cloudVal != nil && localVal != cloudVal:
      conflicts.append(Conflict(key: key, local: localVal, cloud: cloudVal))
    else if cloudVal != nil:
      local.set(cloudVal)              // 仅 iCloud 有 → 直接覆盖
    else if localVal != nil:
      cloud.set(localVal)              // 仅本地有 → 推上去

  if conflicts.isEmpty:
    syncStatus = .available            // 无冲突，直接完成
  else:
    syncStatus = .conflict(conflicts)  // 有冲突，等待用户决策
```

**冲突弹窗（Alert）**：

```
┌─────────────────────────────────────────┐
│           同步冲突                       │
│                                         │
│  检测到 N 项设置在本机和 iCloud 中       │
│  存在不同值，请选择如何处理：              │
│                                         │
│   [使用本机数据]                         │
│        保留本机设置，推送到 iCloud        │
│                                         │
│   [使用 iCloud 数据]                     │
│        以 iCloud 数据覆盖本机            │
│                                         │
│   [逐项查看并选择]                       │
│        进入详情页，逐项决定               │
│                                         │
│                    [取消] (关闭同步)      │
└─────────────────────────────────────────┘
```

**冲突详情页**（选择"逐项查看"时进入）：

```
┌─────────────────────────────────────────┐
│  同步冲突                  < 返回       │
├─────────────────────────────────────────┤
│                                         │
│  以下设置存在冲突，请逐项选择：            │
│                                         │
│  ┌─────────────────────────────────┐    │
│  │ 播放速度                        │    │
│  │   本机: 1.5x     ◉ 保留本机      │    │
│  │   iCloud: 2.0x  ○ 使用 iCloud   │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 弹幕透明度                      │    │
│  │   本机: 80%     ○ 保留本机      │    │
│  │   iCloud: 50%  ◉ 使用 iCloud   │    │
│  └─────────────────────────────────┘    │
│  ┌─────────────────────────────────┐    │
│  │ 请求域名                        │    │
│  │   本机: a.com   ◉ 保留本机      │    │
│  │   iCloud: b.com  ○ 使用 iCloud  │    │
│  └─────────────────────────────────┘    │
│                                         │
│          [确认并应用]                     │
└─────────────────────────────────────────┘
```

**Conflict 数据结构**：

```swift
struct SyncConflict {
    let key: String               // 原始 key（如 "playerSpeed"）
    let displayName: String       // 显示名（如 "播放速度"），通过 key→GlobalSettingType 映射获取
    let localValue: Any            // 本地值
    let cloudValue: Any            // iCloud 值
    let localDisplayValue: String  // 本地值的人类可读描述
    let cloudDisplayValue: String  // iCloud 值的人类可读描述
    var resolution: Resolution    // 用户选择，默认 nil
}

enum Resolution {
    case useLocal     // 保留本机
    case useCloud     // 使用 iCloud
}
```

**冲突解决后的处理**：

```swift
func resolveConflicts(_ decisions: [SyncConflict]) {
    for conflict in decisions {
        switch conflict.resolution {
        case .useLocal:
            cloud.set(conflict.localValue, forKey: conflict.key)  // 推本地到 iCloud
        case .useCloud:
            local.set(conflict.cloudValue, forKey: conflict.key)  // iCloud 覆盖本地
        }
    }
    syncStatus = .available
    NotificationCenter.default.post(name: .cloudDataDidChange, ...)
}
```

**key → 显示名映射**：

在 `SyncConflictResolver` 中维护一个映射表，将 `Preferences.KeyName` 的 rawValue 映射到人类可读名称。优先复用 `GlobalSettingType.title` 已有的翻译，其余新增映射。播放进度/历史 key（`DDPWatchTimeHistory`、`DDPLatWatchDateHistory`）在冲突详情中特殊处理（整体比较，不能逐 key 选）。

### 6. 外部变更处理

当其他设备通过 iCloud 修改数据时，`NSUbiquitousKeyValueStore` 会发送 `didChangeExternallyNotification`。Store 内部监听此通知，将 iCloud 变更同步到本地，并通过自定义通知 `cloudDataDidChange` 驱动 UI 更新：

```swift
@objc private func handleCloudChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo,
          let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else { return }

    let shouldUpdate = (reason == NSUbiquitousKeyValueStoreServerChange) ||
                       (reason == NSUbiquitousKeyValueStoreInitialSyncChange) ||
                       (reason == NSUbiquitousKeyValueStoreQuotaViolationChange)
    guard shouldUpdate, let cloud = cloud else { return }

    // 收集变更的 key（仅保留同步范围内的）
    let syncedKeySet = syncedKeyNames
    var changedKeys = (userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] ?? [])
        .filter { syncedKeySet.contains($0) }

    for key in changedKeys {
        copyValue(forKey: key, from: cloud, to: local)
    }

    // 若 changedKeys 为空，全量同步
    if changedKeys.isEmpty {
        for key in syncedKeySet where cloud.contains(key) {
            copyValue(forKey: key, from: cloud, to: local)
        }
    }

    syncStatus = .available
    NotificationCenter.default.post(name: .cloudDataDidChange, object: nil, userInfo: ["changedKeys": changedKeys])
}
```

UI 层（`GlobalSettingContext`）监听 `cloudDataDidChange`，更新对应的 `BehaviorSubject`，驱动设置页 UI 刷新。监听在 Store 内部完成，外部代码无需直接接触 `NSUbiquitousKeyValueStore` 的通知。

### 7. HistoryManager 迁移

HistoryManager 当前直接读写 `UserDefaults.standard`。迁移方案：

**存储层**：改为通过 `Preferences.shared.store` 读写（Store 是 Preferences 内部类，HistoryManager 属于 Share 层，可访问 internal）。

**Key 注册**：在 `Preferences.KeyName` 中新增两个 case，并添加对应的 `@StoreWrapper` 属性：

```swift
// KeyName 新增
case watchTimeHistory = "DDPWatchTimeHistory"
case lastWatchDateHistory = "DDPLatWatchDateHistory"

// Preferences 新增（syncToCloud: true 自动注册到 Store.registry）
@StoreWrapper(defaultValue: nil, key: .watchTimeHistory, syncToCloud: true)
var watchTimeHistory: [String: TimeInterval]?

@StoreWrapper(defaultValue: nil, key: .lastWatchDateHistory, syncToCloud: true)
var lastWatchDateHistory: [String: TimeInterval]?
```

**HistoryManager 内部**：读写改为走 `Preferences.shared.store`（HistoryManager 与 Store 同属 Share module，可访问 internal）：

```swift
// 迁移前
UserDefaults.standard.set(map, forKey: "DDPWatchTimeHistory")

// 迁移后
Preferences.shared.store.set(map, forKey: Preferences.KeyName.watchTimeHistory.storeKey)
```

**旧数据迁移**：首次读取时检测 UserDefaults 中旧格式（NSDictionary）数据，自动迁移为 JSON Data 格式（`Dictionary: Storeable where Key: Codable, Value: Codable` 泛型扩展已覆盖 `[String: TimeInterval]`）：

```swift
private static func loadMap(storeKey: String) -> [String: TimeInterval] {
    if let value: [String: TimeInterval] = Preferences.shared.store.value(forKey: storeKey) {
        return value
    }
    // 迁移旧 UserDefaults NSDictionary 格式
    if let oldData = UserDefaults.standard.value(forKey: storeKey) as? [String: TimeInterval] {
        Preferences.shared.store.set(oldData, forKey: storeKey)
        return oldData
    }
    return [:]
}
```

播放历史是 `[String: TimeInterval]` 字典，作为一个整体 value 存储，不需要逐条 key 同步。冲突检测时将整个字典作为整体比较。

### 8. iCloud 同步开关（含状态展示与失败重试）

在设置页新增"iCloud 同步"开关，除了开关本身，副标题实时展示同步状态，失败时展示原因并支持重试。

**API 边界**：`Store` 是 `Preferences` 的内部类（`internal`），外部代码（`GlobalSettingModel`、`SettingViewController`）不直接引用 `Store.shared`。同步状态通过 `Preferences.shared` 暴露：

```swift
// Preferences.shared 对外暴露
var syncStatus: CloudSyncStatus { store.syncStatus }
var isCloudAvailable: Bool { store.isCloudAvailable }

func retrySync() { store.retrySync() }
func resolveConflicts(_ conflicts: [SyncConflict]) { store.resolveConflicts(conflicts) }
```

**同步状态枚举**（定义在 `Preferences` 中）：

```swift
enum CloudSyncStatus {
    case disabled         // 用户关闭同步
    case available        // iCloud 可用，同步正常
    case syncing          // 正在执行首次合并同步
    case unavailable      // iCloud 不可用（未登录/受限）
    case conflict([SyncConflict])  // 发现冲突，等待用户决策
    case failed(Error)    // 同步失败，携带错误信息

    var displayText: String {
        switch self {
        case .disabled:     return NSLocalizedString("关闭", comment: "")
        case .available:    return NSLocalizedString("已同步", comment: "")
        case .syncing:      return NSLocalizedString("同步中…", comment: "")
        case .unavailable:  return NSLocalizedString("需要登录 iCloud", comment: "")
        case .conflict:     return NSLocalizedString("有冲突待处理", comment: "")
        case .failed(let e): return String(format: NSLocalizedString("同步失败：%@", comment: ""), e.localizedDescription)
        }
    }
}
```

**UI 交互**：

```
开关 OFF → 副标题: "关闭"
开关 ON → if !isCloudAvailable → 开关弹回 + HUD "需要登录 iCloud"
开关 ON → 触发同步 → 副标题: "同步中…"
  ├─ 无冲突成功 → 副标题: "已同步"（灰色文字）
  ├─ 有冲突 → 副标题: "有冲突待处理" → 弹出 Alert
  │     ├─ "使用本机" → 推送本地值到 iCloud → 副标题: "已同步"
  │     ├─ "使用 iCloud" → iCloud 覆盖本地 → 副标题: "已同步"
  │     ├─ "逐项查看" → push SyncConflictViewController
  │     └─ "取消" → 关闭开关，回退到 disabled
  └─ 失败 → 副标题: "同步失败：xxx"（红色文字）
             → 点击行可重试
```

**重试机制**：
- 失败后开关保持在 ON 位，副标题变红提示失败原因
- 用户点击该设置行 → 触发 `Preferences.shared.retrySync()` 重试
- 重试时清除旧错误，状态变为 `.syncing`
- 连续失败不自动重试（避免无限循环）

**GlobalSettingModel 读取状态**：

```swift
// GlobalSettingModel 通过 Preferences.shared 获取
func subtitle(settingType: GlobalSettingType) -> String {
    switch settingType {
    case .icloudSync:
        return Preferences.shared.syncStatus.displayText
    // ...
    }
}
```

**Preferences 属性**：

```swift
@StoreWrapper(defaultValue: false, key: .icloudSyncEnabled)
var icloudSyncEnabled: Bool {
    didSet {
        if icloudSyncEnabled {
            store.enableCloud()
            store.startSync()
        } else {
            store.stopSync()
        }
    }
}
```

## Store 可见性边界

`Store` 是 `Preferences` 的内部类（`internal class Store`，定义在 `extension Preferences` 中），仅 `Share/` 模块内可见。外部代码（`GlobalSettingModel`、`SettingViewController`、`SyncConflictViewController` 等）必须通过 `Preferences.shared` 访问同步能力和状态：

```
外部代码                    Preferences (public)           Store (internal)
─────────                  ─────────────                  ─────
GlobalSettingModel  ──→   .syncStatus            ──→    store.syncStatus
                          .isCloudAvailable             store.isCloudAvailable
SettingViewController ─→  .retrySync()          ──→    store.retrySync()
                          .resolveConflicts()           store.resolveConflicts()
                          .icloudSyncEnabled            @StoreWrapper
HistoryManager       ──→  (通过 KeyName + @StoreWrapper，自动路由到 Store)
```

**例外**：`HistoryManager` 与 `Store` 同属 Share module，可直接访问 `Preferences.shared.store` 进行复杂字典读写（`[String: TimeInterval]`），但同步 key 的注册通过 `Preferences.KeyName` + `@StoreWrapper(syncToCloud: true)` 完成。

## Risks / Trade-offs

| 风险 | 缓解措施 |
|------|----------|
| 两个设备同时修改不同 key，冲突时 last-write-wins | 当前设置项之间独立，不存在事务性需求，LWW 可接受 |
| iCloud 同步延迟（数秒到数分钟） | 本地读写始终走 UserDefaults，iCloud 是异步附加写入，用户感知不到延迟 |
| 用户登出 iCloud 或网络不可用 | `cloud?.isAvailable` 为 false 时自动降级为纯本地模式，功能不受影响 |
| NSUbiquitousKVS 1MB 限制 | 当前估算总量 < 50KB，预留大量空间；架构已预留换 CloudKit backend 的扩展点 |
| 播放历史字典越来越大 | 当前只存 key 映射，单条记录 < 100 bytes，需观察增长趋势；未来可在 10KB 以上时考虑分片 |
| tvOS 模拟器不支持 iCloud | tvOS 开发必须使用真机，模拟器测试降级为本地模式 |
| macOS 沙盒与 iCloud 兼容性 | Mac 版本需确认 entitlement 配置正确（com.apple.developer.icloud-services） |
| `danmakuFontSize` 跨平台默认值不同（iOS 20 / tvOS 30） | 不同步，各设备独立；同步 key 列表中排除此项 |

## Migration Plan

1. 创建 `LocalStoreBackend` 和 `UbiquitousStoreBackend`
2. 重构 `Store` 类为多后端路由
3. 首次启动调用 `startSync()` 执行合并
4. 上线后运行一段时间，监控同步数据量
5. 若接近 NSUbiquitousKVS 限制 → 评估 CloudKit 迁移

**回滚方案**: 关闭 iCloud capability，Store 检测到 cloud 不可用后自动降级为纯本地模式，数据不丢失。

## Open Questions

- 播放历史字典当前大小是多少？需要真机测试确认
- tvOS 的 NSUbiquitousKeyValueStore 在 Apple TV 上的行为是否有差异？

## Resolved Questions

- ~~同步 `danmakuFontSize` 是否合理？~~ → **不同步**。iOS 默认 20，tvOS 默认 30，跨平台同步会导致显示异常。各平台独立维护默认值。
