//
//  StoreBackend.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/28.
//

import Foundation

// MARK: - StoreValue

enum StoreValue {
    case number(NSNumber)
    case string(String)
    case data(Data)
}

// MARK: - Codable

extension StoreValue: Codable {
    private enum Tag: String, Codable {
        case number, string, data
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()
        let tag = try container.decode(Tag.self)
        switch tag {
        case .number:
            self = .number(NSNumber(value: try container.decode(Double.self)))
        case .string:
            self = .string(try container.decode(String.self))
        case .data:
            self = .data(try container.decode(Data.self))
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.unkeyedContainer()
        switch self {
        case .number(let n):
            try container.encode(Tag.number)
            try container.encode(n.doubleValue)
        case .string(let s):
            try container.encode(Tag.string)
            try container.encode(s)
        case .data(let d):
            try container.encode(Tag.data)
            try container.encode(d)
        }
    }
}

// MARK: - Equatable

extension StoreValue: Equatable {
    static func == (lhs: StoreValue, rhs: StoreValue) -> Bool {
        switch (lhs, rhs) {
        case (.number(let a), .number(let b)): return a.isEqual(to: b)
        case (.string(let a), .string(let b)): return a == b
        case (.data(let a), .data(let b)):     return a == b
        default: return false
        }
    }
}

// MARK: - StoreBackend

protocol StoreBackend {
    func set(_ value: StoreValue, forKey key: String)
    func value(forKey key: String) -> StoreValue?
    func remove(_ key: String)
    func contains(_ key: String) -> Bool
    var isAvailable: Bool { get }
    func synchronize()
}

// MARK: - Any → StoreValue

private func storeValue(from obj: Any) -> StoreValue? {
    if let num = obj as? NSNumber {
        return .number(num)
    }
    if let str = obj as? String {
        return .string(str)
    }
    if let data = obj as? Data {
        return .data(data)
    }
    return nil
}

// MARK: - LocalStoreBackend

final class LocalStoreBackend: StoreBackend {
    var isAvailable: Bool { true }
    func synchronize() { UserDefaults.standard.synchronize() }

    func set(_ value: StoreValue, forKey key: String) {
        switch value {
        case .number(let v): UserDefaults.standard.set(v, forKey: key)
        case .string(let v): UserDefaults.standard.set(v, forKey: key)
        case .data(let v):   UserDefaults.standard.set(v, forKey: key)
        }
    }

    func value(forKey key: String) -> StoreValue? {
        guard let obj = UserDefaults.standard.object(forKey: key) else { return nil }
        return storeValue(from: obj)
    }

    func remove(_ key: String) {
        UserDefaults.standard.removeObject(forKey: key)
    }

    func contains(_ key: String) -> Bool {
        UserDefaults.standard.object(forKey: key) != nil
    }
}

// MARK: - UbiquitousStoreBackend

final class UbiquitousStoreBackend: StoreBackend {
    var isAvailable: Bool {
        FileManager.default.ubiquityIdentityToken != nil
    }

    func synchronize() {
        guard isAvailable else { return }
        NSUbiquitousKeyValueStore.default.synchronize()
    }

    func set(_ value: StoreValue, forKey key: String) {
        guard isAvailable else { return }
        switch value {
        case .number(let n):
            if CFGetTypeID(n) == CFBooleanGetTypeID() {
                NSUbiquitousKeyValueStore.default.set(n.boolValue, forKey: key)
            } else if CFNumberIsFloatType(n) {
                NSUbiquitousKeyValueStore.default.set(n.doubleValue, forKey: key)
            } else {
                NSUbiquitousKeyValueStore.default.set(n.int64Value, forKey: key)
            }
        case .string(let v): NSUbiquitousKeyValueStore.default.set(v, forKey: key)
        case .data(let v):   NSUbiquitousKeyValueStore.default.set(v, forKey: key)
        }
    }

    func value(forKey key: String) -> StoreValue? {
        guard isAvailable else { return nil }
        guard let obj = NSUbiquitousKeyValueStore.default.object(forKey: key) else { return nil }
        return storeValue(from: obj)
    }

    func remove(_ key: String) {
        guard isAvailable else { return }
        NSUbiquitousKeyValueStore.default.removeObject(forKey: key)
    }

    func contains(_ key: String) -> Bool {
        guard isAvailable else { return false }
        return NSUbiquitousKeyValueStore.default.object(forKey: key) != nil
    }
}
