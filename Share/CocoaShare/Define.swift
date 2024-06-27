//
//  Define.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/6/26.
//

import Foundation

#if os(iOS)
import UIKit
typealias ANXColor = UIColor
typealias ANXView = UIView
typealias ANXImage = UIImage
typealias ANXViewController = UIViewController
#else
import Cocoa
typealias ANXColor = NSColor
typealias ANXView = NSView
typealias ANXImage = NSImage
typealias ANXViewController = NSViewController
#endif

public extension ANXColor {
    convenience init(rgb rgbValue: Int) {
        self.init(red: CGFloat((rgbValue & 0xFF0000) >> 16) / 255.0,
                     green: CGFloat((rgbValue & 0xFF00) >> 8) / 255.0,
                     blue: CGFloat((rgbValue & 0xFF)) / 255.0,
                     alpha: 1)
    }

    var rgbValue: Int {
        var r: CGFloat = 0
        var g: CGFloat = 0
        var b: CGFloat = 0

        #if os(macOS)
        r = self.redComponent
        g = self.greenComponent
        b = self.blueComponent
        #else
        self.getRed(&r, green: &g, blue: &b, alpha: nil)
        #endif

        r = r * 255 * 256 * 256
        g = g * 255 * 256
        b = b * 255

        return Int(r + g + b)
    }
}


protocol DefaultValue {
    associatedtype Value: Decodable
    static var defaultValue: Value { get }
}

@propertyWrapper
struct Default<T: DefaultValue> {
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
