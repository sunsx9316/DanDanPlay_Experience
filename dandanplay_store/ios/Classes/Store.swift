//
//  Store.swift
//  dandanplaystore
//
//  Created by JimHuang on 2020/4/19.
//

import Foundation
import MMKV

open class Store {
    
    public static let defaultGroupId = "com.ddplay.default"
    
    public static let shared: Store = {
        var rootDir: String?
        #if os(iOS)
        if let path = NSSearchPathForDirectoriesInDomains(.libraryDirectory, .userDomainMask, true).first,
            var url = URL(string: path) {
            url.appendPathComponent("Store")
            rootDir = url.path
        }
        #endif
        
        MMKV.initialize(rootDir: rootDir, logLevel: .none)
        let obj = Store()
        return obj
    }()
    
    @discardableResult open func set<Value>(_ value: Value, forKey key: String, groupId: String = defaultGroupId) -> Bool {
        if let v = value as? Double {
            return self.set(v, forKey: key)
        } else if let v = value as? String {
            return self.set(v, forKey: key)
        } else if let v = value as? Int {
            return self.set(v, forKey: key)
        } else if let v = value as? Bool {
            return self.set(v, forKey: key)
        }
        return false
    }
    
    open func value<Value>(forKey: String, groupId: String = defaultGroupId) -> Value {
        let valueType = Value.self
        if valueType is Double.Type {
            let v: Double = self.value(forKey: forKey, groupId: groupId)
            return v as! Value
        } else if valueType is String.Type {
            let v: String = self.value(forKey: forKey, groupId: groupId)
            return v as! Value
        } else if valueType is Int.Type {
            let v: Int = self.value(forKey: forKey, groupId: groupId)
            return v as! Value
        } else if valueType is Bool.Type {
            let v: Bool = self.value(forKey: forKey, groupId: groupId)
            return v as! Value
        }
        
        fatalError()
    }
    
    @discardableResult open func set(_ value: Double, forKey key: String, groupId: String = defaultGroupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String, groupId: String = defaultGroupId) -> Double {
        return MMKV(mmapID: groupId)?.double(forKey: forKey) ?? 0
    }
    
    @discardableResult open func set(_ value: Int, forKey key: String, groupId: String = defaultGroupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(Int64(value), forKey: key) ?? false
    }
    
    open func value(forKey: String, groupId: String = defaultGroupId) -> Int {
        let value = MMKV(mmapID: groupId)?.int64(forKey: forKey) ?? 0
        return Int(value)
    }
    
    @discardableResult open func set(_ value: Bool, forKey key: String, groupId: String = defaultGroupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String, groupId: String = defaultGroupId) -> Bool {
        return MMKV(mmapID: groupId)?.bool(forKey: forKey) ?? false
    }
    
    @discardableResult open func set(_ value: String, forKey key: String, groupId: String = defaultGroupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String, groupId: String = defaultGroupId) -> String? {
        return MMKV(mmapID: groupId)?.string(forKey: forKey)
    }
    
    open func contains(_ forKey: String, groupId: String = defaultGroupId) -> Bool {
        return MMKV(mmapID: groupId)?.contains(key: forKey) == true
    }
    
    open func remove(_ forKey: String, groupId: String = defaultGroupId) {
        MMKV(mmapID: groupId)?.removeValue(forKey: forKey)
    }
    
}
