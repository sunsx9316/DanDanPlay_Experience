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
        
        @discardableResult open func set<Value: Storeable>(_ value: Value?, forKey key: String) -> Bool {
            let valueType = Value.F.self
            
            guard let value = value else {
                self.remove(key)
                return true
            }
            
            if valueType is Double.Type {
                let v = value.toValue() as! Double
                return self._set(v, forKey: key)
            } else if valueType is Float.Type {
                let v = value.toValue() as! Float
                return self._set(v, forKey: key)
            } else if valueType is String.Type {
                let v = value.toValue() as! String
                return self._set(v, forKey: key)
            } else if valueType is Int.Type {
                let v = value.toValue() as! Int
                return self._set(v, forKey: key)
            } else if valueType is Bool.Type {
                let v = value.toValue() as! Bool
                return self._set(v, forKey: key)
            } else if valueType is Data.Type {
                let v = value.toValue() as! Data
                return self._set(v, forKey: key)
            } else if valueType is UInt.Type {
                let v = value.toValue() as! UInt
                return self._set(v, forKey: key)
            }
            assert(false, "未支持的数据类型")
            return false
        }
        
        open func value<Value: Storeable>(forKey: String) -> Value? {
            let valueType = Value.F.self
            
            if !self.contains(forKey) {
                return nil
            }
            
            if valueType is Double.Type {
                let v: Double? = self._value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Float.Type {
                let v: Float? = self._value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is String.Type {
                let v: String? = self._value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Int.Type {
                let v: Int? = self._value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Bool.Type {
                let v: Bool? = self._value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            } else if valueType is Data.Type {
                let v: Data? = self._value(forKey: forKey)
                return Value.create(from: v as! Value.F)
            }
            
            fatalError()
        }
        
        open func contains(_ forKey: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.contains(key: forKey) == true
        }
        
        open func remove(_ forKey: String) {
            let mmkv = self.mmkv()
            mmkv?.removeValue(forKey: forKey)
        }
        
        // MARK: Private
        @discardableResult private func _set(_ value: Double, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(value, forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> Double? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            
            return mmkv.double(forKey: forKey)
        }
        
        @discardableResult private func _set(_ value: Float, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(value, forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> Float? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            return mmkv.float(forKey: forKey)
        }
        
        @discardableResult private func _set(_ value: Int, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(Int32(value), forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> Int? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            
            let value = mmkv.int64(forKey: forKey)
            return Int(value)
        }
        
        @discardableResult private func _set(_ value: Bool, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(value, forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> Bool? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            
            return mmkv.bool(forKey: forKey)
        }
        
        @discardableResult private func _set(_ value: String, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(value, forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> String? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            
            return mmkv.string(forKey: forKey)
        }
        
        @discardableResult private func _set(_ value: Data, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(value, forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> Data? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            
            return mmkv.data(forKey: forKey)
        }
        
        @discardableResult private func _set(_ value: UInt, forKey key: String) -> Bool {
            let mmkv = self.mmkv()
            return mmkv?.set(UInt64(value), forKey: key) ?? false
        }
        
        private func _value(forKey: String) -> UInt? {
            guard let mmkv = self.mmkv(),
                  mmkv.contains(key: forKey) else { return nil }
            
            return UInt(mmkv.uint64(forKey: forKey))
        }
        
        private func mmkv() -> MMKV? {
            return MMKV.default()
        }
        
    }
    
}
