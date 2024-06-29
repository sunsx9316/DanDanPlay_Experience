//
//  Decodable+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/6/29.
//

import Foundation

protocol DefaultValue {
    associatedtype Value: Decodable
    static var defaultValue: Value { get }
}


/// 给Decodable添加默认值的包装器
@propertyWrapper struct Default<T: DefaultValue> {
    var wrappedValue: T.Value
}

extension Default: Decodable {
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        wrappedValue = (try? container.decode(T.Value.self)) ?? T.defaultValue
    }
}

extension KeyedDecodingContainer {
    func decode<T>(
        _ type: Default<T>.Type,
        forKey key: Key
    ) throws -> Default<T> where T: DefaultValue {
        try decodeIfPresent(type, forKey: key) ?? Default(wrappedValue: T.defaultValue)
    }
}
extension String: DefaultValue {
    static var defaultValue: String { "Unknown" }
}

extension Int: DefaultValue {
    static var defaultValue: Int { 0 }
}

extension Bool: DefaultValue {
    static var defaultValue: Bool { false }
}

extension Double: DefaultValue {
    static var defaultValue: Double { 0 }
}

extension Array: DefaultValue where Element: Decodable {
    static var defaultValue: [Element] { [] }
}
