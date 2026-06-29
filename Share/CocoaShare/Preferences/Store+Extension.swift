//
//  Store+Extension.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/3.
//

import Foundation
import DanmakuRender

// MARK: - Storeable

protocol Storeable {
    static func create(from: StoreValue) -> Self?
    func toStoreValue() -> StoreValue
}

// MARK: - 基础类型

extension Int: Storeable {
    static func create(from value: StoreValue) -> Int? {
        if case .number(let n) = value { return n.intValue }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: self)) }
}

extension UInt: Storeable {
    static func create(from value: StoreValue) -> UInt? {
        if case .number(let n) = value { return n.uintValue }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: self)) }
}

extension Double: Storeable {
    static func create(from value: StoreValue) -> Double? {
        if case .number(let n) = value { return n.doubleValue }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: self)) }
}

extension Float: Storeable {
    static func create(from value: StoreValue) -> Float? {
        if case .number(let n) = value { return n.floatValue }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: Double(self))) }
}

extension String: Storeable {
    static func create(from value: StoreValue) -> String? {
        if case .string(let v) = value { return v }; return nil
    }
    func toStoreValue() -> StoreValue { .string(self) }
}

extension Bool: Storeable {
    static func create(from value: StoreValue) -> Bool? {
        if case .number(let n) = value { return n.boolValue }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: self)) }
}

extension Data: Storeable {
    static func create(from value: StoreValue) -> Data? {
        if case .data(let v) = value { return v }; return nil
    }
    func toStoreValue() -> StoreValue { .data(self) }
}

// MARK: - ANXColor

extension ANXColor: Storeable {
    static func create(from value: StoreValue) -> Self? {
        if case .number(let n) = value { return ANXColor(anxRgb: n.intValue) as? Self }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: self.anxRgbValue)) }
}

// MARK: - Codable 模型（→ StoreValue = .data）

extension AnixLoginInfo: Storeable {
    static func create(from value: StoreValue) -> AnixLoginInfo? {
        if case .data(let data) = value { return try? JSONDecoder().decode(AnixLoginInfo.self, from: data) }; return nil
    }
    func toStoreValue() -> StoreValue {
        return .data((try? JSONEncoder().encode(self)) ?? .init())
    }
}

extension LoginInfo: Storeable {
    static func create(from value: StoreValue) -> LoginInfo? {
        if case .data(let data) = value { return try? JSONDecoder().decode(LoginInfo.self, from: data) }; return nil
    }
    func toStoreValue() -> StoreValue {
        return .data((try? JSONEncoder().encode(self)) ?? .init())
    }
}

extension FilterDanmaku: Storeable {
    static func create(from value: StoreValue) -> FilterDanmaku? {
        if case .data(let data) = value { return try? JSONDecoder().decode(FilterDanmaku.self, from: data) }; return nil
    }
    func toStoreValue() -> StoreValue {
        return .data((try? JSONEncoder().encode(self)) ?? .init())
    }
}

// MARK: - Array<Storeable>

extension Array: Storeable where Element: Storeable {
    static func create(from value: StoreValue) -> Array<Element>? {
        if case .data(let data) = value,
           let svArray = try? JSONDecoder().decode([StoreValue].self, from: data) {
            return svArray.compactMap { Element.create(from: $0) }
        }
        return nil
    }

    func toStoreValue() -> StoreValue {
        let svArray = self.map { $0.toStoreValue() }
        return .data((try? JSONEncoder().encode(svArray)) ?? .init())
    }
}

// MARK: - Dictionary

extension Dictionary: Storeable where Key: Codable, Value: Storeable {
    static func create(from value: StoreValue) -> Dictionary<Key, Value>? {
        if case .data(let data) = value,
           let svDict = try? JSONDecoder().decode([Key: StoreValue].self, from: data) {
            var result: [Key: Value] = [:]
            for (k, sv) in svDict {
                guard let v = Value.create(from: sv) else { return nil }
                result[k] = v
            }
            return result
        }
        return nil
    }

    func toStoreValue() -> StoreValue {
        var svDict: [Key: StoreValue] = [:]
        for (k, v) in self {
            svDict[k] = v.toStoreValue()
        }
        return .data((try? JSONEncoder().encode(svDict)) ?? .init())
    }
}

// MARK: - Optional

/// StoreWrapper 用于检测 Optional 是否为 nil，避免 Store.set double-wrap 崩溃
protocol _OptionalNilable {
    var _isNil: Bool { get }
}

extension Optional: _OptionalNilable {
    var _isNil: Bool { return self == nil }
}

extension Optional: Storeable where Wrapped: Storeable {
    static func create(from value: StoreValue) -> Optional<Wrapped>? {
        return Wrapped.create(from: value)
    }

    func toStoreValue() -> StoreValue {
        guard let self = self else {
            // StoreWrapper 检测到 nil Optional 时应调 store.remove 而非 set，
            // 此分支作为防守性兜底，避免 Store.set 的 double-wrap 导致崩溃
            return .data(Data())
        }
        return self.toStoreValue()
    }
}

// MARK: - 枚举类型

extension Comment.Mode: Storeable {
    static func create(from value: StoreValue) -> Comment.Mode? {
        if case .number(let n) = value { return Comment.Mode(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}

extension PlayerMode: Storeable {
    static func create(from value: StoreValue) -> PlayerMode? {
        if case .number(let n) = value { return PlayerMode(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}

extension DanmakuAreaType: Storeable {
    static func create(from value: StoreValue) -> DanmakuAreaType? {
        if case .number(let n) = value { return DanmakuAreaType(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}

extension DanmakuEffectStyle: Storeable {
    static func create(from value: StoreValue) -> DanmakuEffectStyle? {
        if case .number(let n) = value { return DanmakuEffectStyle(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}

extension PlayerAspectRatio: Storeable {
    static func create(from value: StoreValue) -> PlayerAspectRatio? {
        if case .string(let v) = value { return PlayerAspectRatio(rawValue: v) }; return nil
    }
    func toStoreValue() -> StoreValue { .string(rawValue) }
}

extension MediaPlayer.CoreType: Storeable {
    static func create(from value: StoreValue) -> MediaPlayer.CoreType? {
        if case .number(let n) = value { return MediaPlayer.CoreType(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}

extension FileSortOption: Storeable {
    static func create(from value: StoreValue) -> FileSortOption? {
        if case .number(let n) = value { return FileSortOption(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}

extension AppLanguage: Storeable {
    static func create(from value: StoreValue) -> AppLanguage? {
        if case .number(let n) = value { return AppLanguage(rawValue: n.intValue) }; return nil
    }
    func toStoreValue() -> StoreValue { .number(NSNumber(value: rawValue)) }
}
