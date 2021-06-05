//
//  Store.swift
//  dandanplaystore
//
//  Created by JimHuang on 2020/4/19.
//

import Foundation
import MMKV

open class Store {
    
    public static let shared: Store = {
        let rootDir = Store.rootPath
        MMKV.initialize(rootDir: rootDir, logLevel: .none)
        let obj = Store()
        return obj
    }()
    
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
    
    @discardableResult open func set<Value>(_ value: Value, forKey key: String) -> Bool {
        if let v = value as? Double {
            return self.set(v, forKey: key)
        } else if let v = value as? String {
            return self.set(v, forKey: key)
        } else if let v = value as? Int {
            return self.set(v, forKey: key)
        } else if let v = value as? Bool {
            return self.set(v, forKey: key)
        } else if let v = value as? Data {
            return self.set(v, forKey: key)
        }
        return false
    }
    
    open func value<Value>(forKey: String) -> Value? {
        let valueType = Value.self
        if valueType is Double.Type {
            let v: Double? = self.value(forKey: forKey)
            return v as? Value
        } else if valueType is String.Type {
            let v: String? = self.value(forKey: forKey)
            return v as? Value
        } else if valueType is Int.Type {
            let v: Int? = self.value(forKey: forKey)
            return v as? Value
        } else if valueType is Bool.Type {
            let v: Bool? = self.value(forKey: forKey)
            return v as? Value
        } else if valueType is Data.Type {
            let v: Data? = self.value(forKey: forKey)
            return v as? Value
        }
        
        fatalError()
    }
    
    @discardableResult open func set(_ value: Double, forKey key: String) -> Bool {
        let mmkv = self.mmkv()
        return mmkv?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String) -> Double? {
        guard let mmkv = self.mmkv(),
              mmkv.contains(key: forKey) else { return nil }
        
        return mmkv.double(forKey: forKey)
    }
    
    @discardableResult open func set(_ value: Int, forKey key: String) -> Bool {
        let mmkv = self.mmkv()
        return mmkv?.set(Int64(value), forKey: key) ?? false
    }
    
    open func value(forKey: String) -> Int? {
        guard let mmkv = self.mmkv(),
              mmkv.contains(key: forKey) else { return nil }
        
        let value = mmkv.int64(forKey: forKey)
        return Int(value)
    }
    
    @discardableResult open func set(_ value: Bool, forKey key: String) -> Bool {
        let mmkv = self.mmkv()
        return mmkv?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String) -> Bool? {
        guard let mmkv = self.mmkv(),
              mmkv.contains(key: forKey) else { return nil }
        
        return mmkv.bool(forKey: forKey)
    }
    
    @discardableResult open func set(_ value: String, forKey key: String) -> Bool {
        let mmkv = self.mmkv()
        return mmkv?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String) -> String? {
        guard let mmkv = self.mmkv(),
              mmkv.contains(key: forKey) else { return nil }
        
        return mmkv.string(forKey: forKey)
    }
    
    @discardableResult open func set(_ value: Data, forKey key: String) -> Bool {
        let mmkv = self.mmkv()
        return mmkv?.set(value, forKey: key) ?? false
    }
    
    open func value(forKey: String) -> Data? {
        guard let mmkv = self.mmkv(),
              mmkv.contains(key: forKey) else { return nil }
        
        return mmkv.data(forKey: forKey)
    }
    
    open func contains(_ forKey: String) -> Bool {
        let mmkv = self.mmkv()
        return mmkv?.contains(key: forKey) == true
    }
    
    open func remove(_ forKey: String) {
        let mmkv = self.mmkv()
        mmkv?.removeValue(forKey: forKey)
    }
    
    private func mmkv() -> MMKV? {
        return MMKV.default()
    }
    
}
