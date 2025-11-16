//
//  Store.swift
//  dandanplaystore
//
//  Created by JimHuang on 2020/4/19.
//

import Foundation
import MMKV

extension Preferences {
    
    internal class Store {
        private class Imp {
            func contains(key: String) -> Bool {
                return UserDefaults.standard.object(forKey: key) != nil
            }
            
            func removeValue(key: String) {
                UserDefaults.standard.removeObject(forKey: key)
            }
            
            func set(_ value: Double, forKey key: String) {
                UserDefaults.standard.setValue(NSNumber(value: value), forKey: key)
            }
            
            func value(forKey: String) -> Double? {
                if let num = UserDefaults.standard.value(forKey: forKey) as? NSNumber {
                    return num.doubleValue
                }
                return nil
            }
            
            func set(_ value: Float, forKey key: String) {
                UserDefaults.standard.setValue(NSNumber(value: value), forKey: key)
            }
            
            func value(forKey: String) -> Float? {
                if let num = UserDefaults.standard.value(forKey: forKey) as? NSNumber {
                    return num.floatValue
                }
                return nil
            }

            func set(_ value: Int, forKey key: String) {
                UserDefaults.standard.setValue(NSNumber(value: value), forKey: key)
            }
            
            func value(forKey: String) -> Int? {
                if let num = UserDefaults.standard.value(forKey: forKey) as? NSNumber {
                    return num.intValue
                }
                return nil
            }
            
            func set(_ value: UInt, forKey key: String) {
                UserDefaults.standard.setValue(NSNumber(value: value), forKey: key)
            }
            
            func value(forKey: String) -> UInt? {
                if let num = UserDefaults.standard.value(forKey: forKey) as? NSNumber {
                    return num.uintValue
                }
                return nil
            }
            
            func set(_ value: Bool, forKey key: String) {
                UserDefaults.standard.setValue(NSNumber(value: value), forKey: key)
            }
            
            func value(forKey: String) -> Bool? {
                if let num = UserDefaults.standard.value(forKey: forKey) as? NSNumber {
                    return num.boolValue
                }
                return nil
            }
            
            func set(_ value: String, forKey key: String) {
                UserDefaults.standard.setValue(value, forKey: key)
            }
            
            func value(forKey: String) -> String? {
                if let value = UserDefaults.standard.value(forKey: forKey) as? String {
                    return value
                }
                return nil
            }
            
            func set(_ value: Data, forKey key: String) {
                UserDefaults.standard.setValue(value, forKey: key)
            }
            
            func value(forKey: String) -> Data? {
                if let value = UserDefaults.standard.value(forKey: forKey) as? Data {
                    return value
                }
                return nil
            }
        }
        
        public static let shared: Store = {
            let rootDir = Store.rootPath
            // 如果需要迁移，先初始化 MMKV
            if !UserDefaults.standard.bool(forKey: "MMKVToUserDefaultsMigrationCompleted") {
                MMKV.initialize(rootDir: rootDir, logLevel: .none)
            }
            let obj = Store()
            // 执行从 MMKV 到 UserDefaults 的迁移
            obj.migrateFromMMKVToUserDefaults()
            return obj
        }()
        
        
        private lazy var imp = Imp();
        
        private static let rootPath: String? = {
            var rootDir: String?
#if os(iOS)
            if let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first,
               var url = URL(string: path) {
                url.appendPathComponent("Store")
                rootDir = url.path
            }
#endif
            return rootDir
        }()
        
        // MARK: Migration
        
        /// 迁移标记 key，用于标记是否已完成迁移
        private static let migrationCompletedKey = "MMKVToUserDefaultsMigrationCompleted"
        
        /// 执行从 MMKV 到 UserDefaults 的迁移
        /// 根据 Preferences.swift 中定义的 key 和类型进行精确迁移
        @discardableResult
        private func migrateFromMMKVToUserDefaults() -> Bool {
            // 检查是否已经迁移过
            if UserDefaults.standard.bool(forKey: Self.migrationCompletedKey) {
                debugPrint("MMKV 到 UserDefaults 的迁移已完成，跳过")
                return true
            }
            
            guard let mmkv = MMKV.default() else {
                debugPrint("MMKV 实例不存在，无法执行迁移")
                UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
                return true
            }
            
            var migratedCount = 0
            var failedKeys: [String] = []
            
            debugPrint("开始迁移 MMKV 数据到 UserDefaults")
            
            // 根据 Preferences.swift 中定义的 key 和类型进行迁移
            // 定义 key 和对应的类型映射
            let keyTypeMap: [(key: Preferences.KeyName, migrate: (String) -> Bool)] = [
                // Bool 类型
                (.fastMatch, { self._migrateBool(from: mmkv, key: $0) }),
                (.subtitleSafeArea, { self._migrateBool(from: mmkv, key: $0) }),
                (.showHomePageTips, { self._migrateBool(from: mmkv, key: $0) }),
                (.checkUpdate, { self._migrateBool(from: mmkv, key: $0) }),
                (.showDanmaku, { self._migrateBool(from: mmkv, key: $0) }),
                (.autoLoadCustomDanmaku, { self._migrateBool(from: mmkv, key: $0) }),
                (.autoLoadCustomSubtitle, { self._migrateBool(from: mmkv, key: $0) }),
                (.mergeSameDanmaku, { self._migrateBool(from: mmkv, key: $0) }),
                (.autoJumpTitleEnding, { self._migrateBool(from: mmkv, key: $0) }),
                (.openDanmakuRandomColor, { self._migrateBool(from: mmkv, key: $0) }),
                
                // Int 类型
                (.danmakuCacheDay, { self._migrateInt(from: mmkv, key: $0) }),
                (.danmakuOffsetTime, { self._migrateInt(from: mmkv, key: $0) }),
                (.subtitleOffsetTime, { self._migrateInt(from: mmkv, key: $0) }),
                (.audioOffsetTime, { self._migrateInt(from: mmkv, key: $0) }),
                (.subtitleMargin, { self._migrateInt(from: mmkv, key: $0) }),
                
                // Double 类型
                (.playerSpeed, { self._migrateDouble(from: mmkv, key: $0) }),
                (.danmakuFontSize, { self._migrateDouble(from: mmkv, key: $0) }),
                (.danmakuSpeed, { self._migrateDouble(from: mmkv, key: $0) }),
                (.danmakuAlpha, { self._migrateDouble(from: mmkv, key: $0) }),
                (.jumpTitleDuration, { self._migrateDouble(from: mmkv, key: $0) }),
                (.jumpEndingDuration, { self._migrateDouble(from: mmkv, key: $0) }),
                
                // Float 类型
                (.subtitleFontSize, { self._migrateFloat(from: mmkv, key: $0) }),
                (.danmakuDensity, { self._migrateFloat(from: mmkv, key: $0) }),
                
                // String 类型
                (.host, { self._migrateString(from: mmkv, key: $0) }),
                (.lastUpdateVersion, { self._migrateString(from: mmkv, key: $0) }),
                (.subtitleFontName, { self._migrateString(from: mmkv, key: $0) }),
                
                // Data 类型（自定义对象，通过 JSON 编码）
                (.pcLoginInfo, { self._migrateData(from: mmkv, key: $0) }),
                (.smbLoginInfo, { self._migrateData(from: mmkv, key: $0) }),
                (.webDavLoginInfo, { self._migrateData(from: mmkv, key: $0) }),
                (.ftpLoginInfo, { self._migrateData(from: mmkv, key: $0) }),
                (.subtitleLoadOrder, { self._migrateData(from: mmkv, key: $0) }),
                (.filterDanmaku, { self._migrateData(from: mmkv, key: $0) }),
                (.loginInfo, { self._migrateData(from: mmkv, key: $0) }),
                
                // 枚举类型（存储为 Int 或 String）
                (.sendDanmakuType, { self._migrateInt(from: mmkv, key: $0) }), // Comment.Mode -> Int
                (.playerMode, { self._migrateInt(from: mmkv, key: $0) }), // PlayerMode -> Int
                (.danmakuArea, { self._migrateInt(from: mmkv, key: $0) }), // DanmakuAreaType -> Int
                (.danmakuEffectStyle, { self._migrateInt(from: mmkv, key: $0) }), // DanmakuEffectStyle -> Int
                (.aspectRatio, { self._migrateString(from: mmkv, key: $0) }), // PlayerAspectRatio -> String
                (.sendDanmakuColor, { self._migrateUInt(from: mmkv, key: $0) }), // ANXColor -> UInt
                (.mainColor, { self._migrateUInt(from: mmkv, key: $0) }), // ANXColor -> UInt
            ]
            
            for (keyName, migrateFunc) in keyTypeMap {
                let key = keyName.rawValue
                if migrateFunc(key) {
                    migratedCount += 1
                } else if mmkv.contains(key: key) {
                    // key 存在但迁移失败
                    failedKeys.append(key)
                    debugPrint("警告: 无法迁移 key: \(key)")
                }
            }
            
            // 标记迁移完成
            UserDefaults.standard.set(true, forKey: Self.migrationCompletedKey)
            UserDefaults.standard.synchronize()
            
            debugPrint("迁移完成: 成功迁移 \(migratedCount) 个 key")
            if !failedKeys.isEmpty {
                debugPrint("迁移失败的 key: \(failedKeys)")
            }
            
            return failedKeys.isEmpty
        }
        
        // MARK: Migration Helpers
        
        private func _migrateBool(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key) else { return false }
            let value = mmkv.bool(forKey: key)
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        private func _migrateInt(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key) else { return false }
            let value = Int(mmkv.int64(forKey: key))
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        private func _migrateDouble(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key) else { return false }
            let value = mmkv.double(forKey: key)
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        private func _migrateFloat(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key) else { return false }
            let value = mmkv.float(forKey: key)
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        private func _migrateString(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key), let value = mmkv.string(forKey: key) else { return false }
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        private func _migrateData(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key), let value = mmkv.data(forKey: key), value.count > 0 else { return false }
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        private func _migrateUInt(from mmkv: MMKV, key: String) -> Bool {
            guard mmkv.contains(key: key) else { return false }
            let value = UInt(mmkv.uint64(forKey: key))
            UserDefaults.standard.set(value, forKey: key)
            return true
        }
        
        open func set<Value: Storeable>(_ value: Value?, forKey key: String) {
            let valueType = Value.F.self
            
            guard let value = value else {
                self.remove(key)
                return
            }
            
            if valueType is Double.Type {
                let v = value.toValue() as! Double
                self.imp.set(v, forKey: key)
            } else if valueType is Float.Type {
                let v = value.toValue() as! Float
                self.imp.set(v, forKey: key)
            } else if valueType is String.Type {
                let v = value.toValue() as! String
                self.imp.set(v, forKey: key)
            } else if valueType is Int.Type {
                let v = value.toValue() as! Int
                self.imp.set(v, forKey: key)
            } else if valueType is Bool.Type {
                let v = value.toValue() as! Bool
                self.imp.set(v, forKey: key)
            } else if valueType is Data.Type {
                let v = value.toValue() as! Data
                self.imp.set(v, forKey: key)
            } else if valueType is UInt.Type {
                let v = value.toValue() as! UInt
                self.imp.set(v, forKey: key)
            } else {
                assert(false, "未支持的数据类型")
            }
            
        }
        
        open func value<Value: Storeable>(forKey: String) -> Value? {
            let valueType = Value.F.self
            
            if !self.contains(forKey) {
                return nil
            }
            
            if valueType is Double.Type {
                let v: Double? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Float.Type {
                let v: Float? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is String.Type {
                let v: String? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Int.Type {
                let v: Int? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Bool.Type {
                let v: Bool? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Data.Type {
                let v: Data? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is UInt.Type {
                let v: UInt? = self.imp.value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else {
                assert(false)
                return nil
            }
        }
        
        open func contains(_ forKey: String) -> Bool {
            return self.imp.contains(key: forKey) == true
        }
        
        open func remove(_ forKey: String) {
            self.imp.removeValue(key: forKey)
        }
        
    }
    
}
