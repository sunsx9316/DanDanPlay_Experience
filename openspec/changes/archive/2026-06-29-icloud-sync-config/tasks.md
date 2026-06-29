## 1. Core Store Backend Abstraction

- [x] 1.1 定义 `StoreBackend` 协议（`value`、`set`、`remove`、`contains`、`isAvailable`、`synchronize`），放在 `Share/CocoaShare/Preferences/StoreBackend.swift`
- [x] 1.2 实现 `LocalStoreBackend`，将现有 `Store.Imp` 逻辑迁移到该类，遵循 `StoreBackend` 协议
- [x] 1.3 实现 `UbiquitousStoreBackend`，封装 `NSUbiquitousKeyValueStore.default`，遵循 `StoreBackend` 协议

## 2. Generic Storeable Extensions

- [x] 2.1 新增 `Array: Storeable where Element: Storeable, Element.F: Codable` 泛型扩展（`F = Data`，先编解码 `[Element.F]` 再通过 `Element.create(from:)` / `toValue()` 转换，避免 `Element: Codable` 约束冲突）
- [x] 2.2 新增 `Dictionary: Storeable where Key: Codable, Value: Codable` 泛型扩展（`F = Data`，JSON 编解码），覆盖 `[String: TimeInterval]` 等字典类型
- [x] 2.3 新增 `Optional: Storeable where Wrapped: Storeable` 泛型扩展（委托给 Wrapped）
- [x] 2.4 新增 `AnixLoginInfo: Storeable`（`F = Data`，Codable 编解码）
- [x] 2.5 删除 `extension AnixLoginInfo?: Storeable` 手动实现（泛型 Optional 自动覆盖）
- [x] 2.6 将 Preferences 中所有 JSON 手写 getter/setter 改为 `@StoreWrapper`：pcLoginInfos、smbLoginInfos、webDavLoginInfos、ftpLoginInfos、embyLoginInfos、jellyfinLoginInfos、subtitleLoadOrder、customHosts、backupHosts、filterDanmakus、sendDanmakuColors（利用 `Array: Storeable where Element: Storeable, Element.F: Codable` + `ANXColor: Storeable` 实现），删除约 160 行重复代码
- [x] 2.7 验证 `AnixLoginInfo?` 的 `@StoreWrapper(defaultValue: nil, key: .loginInfo)` 在删除手动 conformance 后仍正常工作

## 3. Multi-Backend Store Routing

- [x] 3.1 重构 `Store` 类：持有 `local: StoreBackend`（必需）和 `cloud: StoreBackend?`（可选），添加 `static var syncedKeyNames: Set<String> = []`（由 StoreWrapper init 自动填充）
- [x] 3.2 实现读写路由逻辑：写时 local 必写 + cloud 条件写入；读时 cloud 优先 + local 降级
- [x] 3.3 实现 `startSync()` 方法：检测 cloud 可用性，执行合并检测（逐 key 比对本地和 iCloud 值），无冲突时自动合并，有冲突时返回冲突列表
- [x] 3.4 实现 `stopSync()` 方法：停止读写 cloud，`cloud` 设为 nil
- [x] 3.5 确保 `@StoreWrapper` 对上层完全透明，Preferences.swift 读写行为不变

## 4. StoreWrapper Sync Annotation

- [x] 4.1 在 `@StoreWrapper` 新增 `syncToCloud: Bool` 参数（默认 `false`），init 时若为 `true` 则调用 `Store.syncedKeyNames.insert(key.storeKey)`
- [x] 4.2 在 `Preferences.swift` 中为需要同步的属性添加 `syncToCloud: true`（播放偏好、弹幕偏好、字幕偏好、网络配置、自动跳过、弹幕屏蔽、文件排序、检查更新、弹幕颜色），共约 33 个属性（全部通过 `@StoreWrapper` 自动注册，`init()` 无需手动处理）
- [x] 4.3 确认以下属性不加 `syncToCloud`：playerCore、playerPiP、miniProgressBar、hwdecEnabled、appLanguage、mainColor、subtitleFontSize、subtitleFontName、subtitleYPosition、subtitleColor、所有 loginInfo 变体、showHomePageTips、lastUpdateVersion、aspectRatio、audioOffsetTime
- [x] 4.4 确保 `icloudSyncEnabled` 属性不加 `syncToCloud`（开关本身不同步）
- [x] 4.5 `danmakuFontSize` 不同步 — iOS 默认 20，tvOS 默认 30，跨平台同步会导致显示异常

## 5. Sync Status and Retry

- [x] 5.1 定义 `CloudSyncStatus` 枚举（disabled / available / syncing / unavailable / conflict([SyncConflict]) / failed(Error)），放在 `Store.swift` 中
- [x] 5.2 `Store` 新增 `syncStatus: CloudSyncStatus` 属性，内部根据同步操作结果实时更新
- [x] 5.3 写操作失败时更新 status 为 `.failed(error)`；外部变更通知成功时更新为 `.available`；`startSync()` 中更新为 `.syncing` / `.conflict` / `.available` / `.failed`
- [x] 5.4 实现 `retrySync()` 方法：清除旧错误/冲突状态，重新执行 `startSync()` 合并逻辑

## 6. Conflict Resolution（启动时模态弹窗，二选一覆盖）

- [x] 6.1 `SyncConflict` 结构体（key, localRawValue, cloudRawValue），放在 `Store.swift`
- [x] 6.2 `startSync()` 检测冲突 → `.conflict([SyncConflict])` 状态，不自动覆盖
- [x] 6.3 `resolveConflicts(useCloud:)` — true 用云端覆盖本地，false 用本地覆盖云端
- [x] 6.4 iOS/tvOS: `Preferences+ConflictUI.swift` — UIViewController 扩展，启动时 `viewDidAppear` 检测冲突弹 UIAlertController
- [x] 6.5 macOS: `PlayerViewController.viewDidAppear()` 直接调 NSAlert 弹窗
- [x] 6.6 `Preferences.init()` 中 `icloudSyncEnabled == true` 时自动调 `startSync()`，确保重启后恢复同步

## 7. External Change Notification

- [x] 7.1 在 `Store` 中监听 `NSUbiquitousKeyValueStore.didChangeExternallyNotification`，收到后重新读取变更 key 并更新本地
- [x] 7.2 定义新的 `Notification.Name.cloudDataDidChange` 通知，携带变更的 key 列表
- [x] 7.3 在 `GlobalSettingContext` 中监听 `cloudDataDidChange`，更新对应的 `BehaviorSubject`

## 8. iCloud Sync Toggle UI

- [x] 8.1 在 `Preferences.KeyName` 中新增 `icloudSyncEnabled` key
- [x] 8.2 在 `Preferences` 中新增 `icloudSyncEnabled: Bool` 属性（`@StoreWrapper(defaultValue: false, key: .icloudSyncEnabled)`），didSet 中调用 `Store.shared.startSync()` / `stopSync()`
- [x] 8.3 确保 `icloudSyncEnabled` 属性不加 `syncToCloud: true`（开关状态不同步）
- [x] 8.4 在 `GlobalSettingType` 中新增 `.icloudSync` case，title 为 "iCloud 同步"
- [x] 8.5 在 `GlobalSettingModel` 中新增 `.icloudSync` 的处理：title 返回 "iCloud 同步"，subtitle 动态读取 `Store.shared.syncStatus.displayText`
- [x] 8.6 同步失败时 subtitle 显示错误信息（通过 `CloudSyncStatus.displayText`）；冲突时展示副标题"有冲突待处理"
- [x] 8.7 点击 `.icloudSync` 行时：`.failed` → 触发 `retrySync()`；`.conflict` → 弹出冲突 Alert；否则切换开关状态
- [x] 8.8 iCloud 不可用时开关弹回关闭状态并显示 HUD 提示"需要登录 iCloud"

## 9. HistoryManager Migration

- [x] 9.1 将 `HistoryManager` 中 `watchProgressStoreMap` 的持久化从 `UserDefaults.standard.set` 改为 `Store.shared.set`
- [x] 9.2 将 `lastWatchDateStoreMap` 的持久化从 `UserDefaults.standard.set` 改为 `Store.shared.set`
- [x] 9.3 将初始化时从 `UserDefaults.standard.value` 读取改为 `Store.shared.value`
- [x] 9.4 添加旧数据迁移逻辑：首次读取时检测 UserDefaults 中的 NSDictionary 格式数据，自动迁移为 JSON Data 格式

## 10. Platform Configuration

- [x] 10.1 iOS target: iCloud capability 需在 Xcode 中手动启用（Signing & Capabilities → +iCloud → Key-value storage）。代码已支持无 entitlements 时优雅降级
- [x] 10.2 tvOS target: 同 iOS，需在 Xcode 中手动配置
- [x] 10.3 macOS target: 同 iOS，需在 Xcode 中手动配置。现有 Mac entitlements 已存在（com.apple.security.cs.allow-unsigned-executable-memory），需追加 ubiquity-kvstore-identifier
- [x] 10.4 三平台应使用相同的 iCloud container identifier（通常为 TeamID.BundleID），确保跨平台数据互通
- [x] 10.5 运行 `scripts/add_to_project.rb` 将 `StoreBackend.swift`（三平台）和 `SyncConflictViewController.swift`（仅 iOS）加入 Xcode 工程

## 11. Verification

- [x] 11.1 iOS 真机编译通过
- [x] 11.2 tvOS 真机编译通过
- [x] 11.3 macOS 编译通过
- [ ] 11.4 开关打开/关闭功能测试：关闭时不同步，打开后开始同步并显示状态
- [ ] 11.5 同步成功状态测试：iCloud 同步正常时副标题显示"已同步"
- [ ] 11.6 冲突弹窗测试：模拟两端不同值 → 启动时弹模态 → 选本机/选云端 → 验证统一
- [ ] 11.8 失败重试测试：模拟同步失败 → 副标题显示错误 → 点击重试 → 恢复同步
- [ ] 11.9 同 iCloud 账号的两台 iOS 设备间同步测试：修改设置 → 对端收到变更
- [ ] 11.10 播放进度跨设备同步测试：设备 A 观看 → 设备 B 续播
- [ ] 11.11 iCloud 不可用时降级测试：登出 iCloud → 开关置灰 + 提示 → 重新登录 → 可正常开启同步
- [ ] 11.12 升级测试：旧版本地 UserDefaults 数据 → 升级新版本 → 数据不丢失
- [x] 11.13 Storeable 泛型扩展验证：`[LoginInfo]?`、`[String]?`、`[FilterDanmaku]?` 等通过 `@StoreWrapper` 读写正常
