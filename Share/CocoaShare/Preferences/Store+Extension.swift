//
//  Store+Extension.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/3.
//

import Foundation
#if os(iOS)
import DanmakuRender
import YYCategories
#elseif os(tvOS)
import UIKit
#endif

protocol Storeable {
    associatedtype F
    
    static func create(from: F) -> Self?
    
    func toValue() -> F
}

extension Int: Storeable {
    static func create(from: Int) -> Int? {
        return from
    }
    
    func toValue() -> Int {
        return self
    }
}

extension UInt: Storeable {
    static func create(from: UInt) -> UInt? {
        return from
    }
    
    func toValue() -> UInt {
        return self
    }
}

extension Double: Storeable {
    static func create(from: Double) -> Double? {
        return from
    }
    
    func toValue() -> Double {
        return self
    }
}

extension Float: Storeable {
    static func create(from: Float) -> Float? {
        return from
    }
    
    func toValue() -> Float {
        return self
    }
}

extension String: Storeable {
    static func create(from: String) -> String? {
        return from
    }
    
    func toValue() -> String {
        return self
    }
}

extension Bool: Storeable {
    static func create(from: Bool) -> Bool? {
        return from
    }
    
    func toValue() -> Bool {
        return self
    }
}

extension Data: Storeable {
    static func create(from: Data) -> Data? {
        return from
    }
    
    func toValue() -> Data {
        return self
    }
}

extension ANXColor: Storeable {
#if os(iOS)
    static func create(from: UInt) -> Self? {
        return Self(rgba: UInt32(from))
    }

    func toValue() -> UInt {
        return UInt(self.rgbaValue())
    }
#else
    static func create(from: UInt) -> Self? {
        let rgb = Int(from)
        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0xFF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0xFF) / 255.0
        return UIColor(red: r, green: g, blue: b, alpha: 1) as? Self
    }

    func toValue() -> UInt {
        return UInt(self.anxRgbValue)
    }
#endif
}

extension Comment.Mode: Storeable {
    static func create(from: Int) -> Comment.Mode? {
        let rawValue = from
        return Comment.Mode(rawValue: rawValue)
    }
    
    func toValue() -> Int {
        return self.rawValue
    }
}

extension AnixLoginInfo?: Storeable {
    static func create(from: Data) -> Self? {
        return try? JSONDecoder().decode(AnixLoginInfo.self, from: from)
    }
    
    func toValue() -> Data {
        return (try? JSONEncoder().encode(self)) ?? .init()
    }
}


extension PlayerMode: Storeable {
    static func create(from: Int) -> PlayerMode? {
        let rawValue = from
        return PlayerMode(rawValue: rawValue)
    }
    
    func toValue() -> Int {
        return self.rawValue
    }
}

extension DanmakuAreaType: Storeable {
    static func create(from: Int) -> DanmakuAreaType? {
        let rawValue = from
        return DanmakuAreaType(rawValue: rawValue)
    }
    
    func toValue() -> Int {
        return self.rawValue
    }
}


#if os(iOS)
extension DanmakuEffectStyle: Storeable {
    static func create(from: Int) -> DanmakuEffectStyle? {
        let rawValue = from
        return DanmakuEffectStyle(rawValue: rawValue)
    }

    func toValue() -> Int {
        return self.rawValue
    }
}
#endif

extension PlayerAspectRatio: Storeable {
    static func create(from: String) -> PlayerAspectRatio? {
        let rawValue = from
        return PlayerAspectRatio(rawValue: rawValue)
    }

    func toValue() -> String {
        return self.rawValue
    }
}

extension MediaPlayer.CoreType: Storeable {
    static func create(from: Int) -> MediaPlayer.CoreType? {
        let rawValue = from
        return MediaPlayer.CoreType(rawValue: rawValue)
    }

    func toValue() -> Int {
        return self.rawValue
    }
}

extension AppLanguage: Storeable {
    static func create(from: Int) -> AppLanguage? {
        let rawValue = from
        return AppLanguage(rawValue: rawValue)
    }

    func toValue() -> Int {
        return self.rawValue
    }
}
