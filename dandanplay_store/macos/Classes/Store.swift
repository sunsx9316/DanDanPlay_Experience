//
//  Store.swift
//  dandanplaystore
//
//  Created by JimHuang on 2020/4/19.
//

import Foundation
import MMKV

class Store {
    
    static private let _groupId = "com.ddplay.default"
    
    static let shared: Store = {
        MMKV.initialize(rootDir: nil, logLevel: .none)
        let obj = Store()
        return obj
    }()
    
    func set(_ value: Double, forKey key: String, groupId: String = _groupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(value, forKey: key) ?? false
    }
    
    func value(forKey: String, groupId: String = _groupId) -> Double {
        return MMKV(mmapID: groupId)?.double(forKey: forKey) ?? 0
    }
    
    func set(_ value: Int, forKey key: String, groupId: String = _groupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(Int32(value), forKey: key) ?? false
    }
    
    func value(forKey: String, groupId: String = _groupId) -> Int {
        let value = MMKV(mmapID: groupId)?.int32(forKey: forKey) ?? 0
        return Int(value)
    }
    
    func set(_ value: Bool, forKey key: String, groupId: String = _groupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(value, forKey: key) ?? false
    }
    
    func value(forKey: String, groupId: String = _groupId) -> Bool {
        return MMKV(mmapID: groupId)?.bool(forKey: forKey) ?? false
    }
    
    func set(_ value: String, forKey key: String, groupId: String = _groupId) -> Bool {
        return MMKV(mmapID: groupId)?.set(value, forKey: key) ?? false
    }
    
    func value(forKey: String, groupId: String = _groupId) -> String? {
        return MMKV(mmapID: groupId)?.string(forKey: forKey)
    }
    
    func contains(_ forKey: String, groupId: String = _groupId) -> Bool {
        return MMKV(mmapID: groupId)?.contains(key: forKey) == true
        return false
    }
    
    func remove(_ forKey: String, groupId: String = _groupId) {
        MMKV(mmapID: groupId)?.removeValue(forKey: forKey)
    }
    
}
