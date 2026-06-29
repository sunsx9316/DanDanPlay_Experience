//
//  Store.swift
//  dandanplaystore
//
//  Created by JimHuang on 2020/4/19.
//

import Foundation

extension Notification.Name {
    static let cloudDataDidChange = Notification.Name("cloudDataDidChange")
    static let syncConflictDetected = Notification.Name("syncConflictDetected")
}

extension Preferences {

    enum CloudSyncStatus {
        case disabled
        case available
        case syncing
        case unavailable
        case conflict([SyncConflict])
        case failed(Error)

        var displayText: String {
            switch self {
            case .disabled:
                return NSLocalizedString("关闭", comment: "")
            case .available:
                return NSLocalizedString("已同步", comment: "")
            case .syncing:
                return NSLocalizedString("同步中…", comment: "")
            case .unavailable:
                return NSLocalizedString("需要登录 iCloud", comment: "")
            case .conflict:
                return NSLocalizedString("有冲突待处理", comment: "")
            case .failed(let e):
                return String(format: NSLocalizedString("同步失败：%@", comment: ""), e.localizedDescription)
            }
        }
    }

    struct SyncConflict {
        let key: String
        let localRawValue: StoreValue
        let cloudRawValue: StoreValue
    }

    internal class Store {

        /// 由 StoreWrapper init 自动填充，Store 通过它获取同步 key 列表
        static var registry: [(key: String, syncToCloud: Bool)] = []

        private let local: StoreBackend = LocalStoreBackend()
        private let cloud: StoreBackend = UbiquitousStoreBackend()

        private var syncEnabled = false

        var syncStatus: CloudSyncStatus = .disabled

        private var syncedKeyNames: Set<String> {
            Set(Self.registry.filter(\.syncToCloud).map(\.key))
        }

        init() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(handleCloudChange(_:)),
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default
            )
        }

        deinit {
            NotificationCenter.default.removeObserver(
                self,
                name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
                object: NSUbiquitousKeyValueStore.default
            )
        }

        // MARK: - Public

        open func set<Value: Storeable>(_ value: Value?, forKey key: String) {
            guard let value = value else {
                local.remove(key)
                if syncEnabled { cloud.remove(key) }
                return
            }

            let sv = value.toStoreValue()
            local.set(sv, forKey: key)
            if syncEnabled, syncedKeyNames.contains(key) {
                cloud.set(sv, forKey: key)
            }
        }

        open func value<Value: Storeable>(forKey: String) -> Value? {
            guard let sv = local.value(forKey: forKey) else { return nil }
            return Value.create(from: sv)
        }

        open func contains(_ forKey: String) -> Bool {
            return local.contains(forKey)
        }

        open func remove(_ forKey: String) {
            local.remove(forKey)
            cloud.remove(forKey)
        }

        // MARK: - Sync Control

        func startSync() {
            if case .syncing = syncStatus { return }

            syncEnabled = true
            syncStatus = .syncing
            cloud.synchronize()

            var conflicts: [SyncConflict] = []

            for key in syncedKeyNames {
                let localHas = local.contains(key)
                let cloudHas = cloud.contains(key)

                if localHas && cloudHas {
                    guard let localVal = local.value(forKey: key),
                          let cloudVal = cloud.value(forKey: key) else { continue }
                    if localVal != cloudVal {
                        conflicts.append(SyncConflict(
                            key: key,
                            localRawValue: localVal,
                            cloudRawValue: cloudVal
                        ))
                    }
                } else if cloudHas, let cloudVal = cloud.value(forKey: key) {
                    local.set(cloudVal, forKey: key)
                } else if localHas, let localVal = local.value(forKey: key) {
                    cloud.set(localVal, forKey: key)
                }
            }

            if conflicts.isEmpty {
                syncStatus = .available
                NotificationCenter.default.post(name: .cloudDataDidChange, object: nil)
            } else {
                syncStatus = .conflict(conflicts)
                NotificationCenter.default.post(name: .syncConflictDetected, object: nil)
            }
        }

        func stopSync() {
            syncEnabled = false
            syncStatus = .disabled
        }

        func retrySync() {
            syncEnabled = false
            syncStatus = .disabled
            startSync()
        }

        func resolveConflicts(useCloud: Bool) {
            guard case .conflict(let conflicts) = syncStatus else { return }

            for conflict in conflicts {
                if useCloud {
                    local.set(conflict.cloudRawValue, forKey: conflict.key)
                    cloud.set(conflict.cloudRawValue, forKey: conflict.key)
                } else {
                    cloud.set(conflict.localRawValue, forKey: conflict.key)
                }
            }

            syncStatus = .available
            commitSync()
            NotificationCenter.default.post(name: .cloudDataDidChange, object: nil)
        }

        /// 同步成功确认后将 icloudSyncEnabled 持久化到本地 store
        func commitSync() {
            local.set(.number(NSNumber(value: true)), forKey: "icloudSyncEnabled")
        }

        // MARK: - Internal

        @objc private func handleCloudChange(_ notification: Notification) {
            guard let userInfo = notification.userInfo,
                  let reason = userInfo[NSUbiquitousKeyValueStoreChangeReasonKey] as? Int else {
                return
            }

            let shouldUpdate = (reason == NSUbiquitousKeyValueStoreServerChange) ||
                               (reason == NSUbiquitousKeyValueStoreInitialSyncChange) ||
                               (reason == NSUbiquitousKeyValueStoreQuotaViolationChange)

            guard shouldUpdate, syncEnabled else { return }

            var changedKeys: [String] = []
            if let keys = userInfo[NSUbiquitousKeyValueStoreChangedKeysKey] as? [String] {
                changedKeys = keys
            }

            for key in changedKeys where syncedKeyNames.contains(key) {
                if let cloudVal = cloud.value(forKey: key) {
                    local.set(cloudVal, forKey: key)
                }
            }

            if changedKeys.isEmpty {
                for key in syncedKeyNames where cloud.contains(key) {
                    if let cloudVal = cloud.value(forKey: key) {
                        local.set(cloudVal, forKey: key)
                    }
                }
            }

            syncStatus = .available
            NotificationCenter.default.post(name: .cloudDataDidChange, object: nil, userInfo: [
                "changedKeys": changedKeys
            ])
        }

        var isCloudAvailable: Bool {
            return cloud.isAvailable
        }
    }

    // MARK: - Preferences 桥接（外部代码通过 Preferences.shared 访问）

    var syncStatus: CloudSyncStatus {
        return store.syncStatus
    }

    var isCloudAvailable: Bool {
        return store.isCloudAvailable
    }

    func retrySync() {
        store.retrySync()
    }

    func resolveConflicts(useCloud: Bool) {
        store.resolveConflicts(useCloud: useCloud)
    }

    func commitSync() {
        store.commitSync()
    }
}
