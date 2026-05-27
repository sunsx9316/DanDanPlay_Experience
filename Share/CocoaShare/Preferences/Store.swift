//
//  Store.swift
//  dandanplaystore
//
//  Created by JimHuang on 2020/4/19.
//

import Foundation

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
        
        public static let shared = Store()
        
        
        private lazy var imp = Imp();

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
