//
//  CryptoHelper.swift
//  AniXPlayer
//
//  Created for tvOS compatibility (replaces YYCategories crypto methods)
//

import Foundation
import CryptoKit

#if !os(iOS)
extension NSString {
    func md5() -> String? {
        let str = self as String
        guard let data = str.data(using: .utf8) else { return nil }
        let digest = Insecure.MD5.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension NSData {
    func md5String() -> String {
        let digest = Insecure.MD5.hash(data: self as Data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    func sha256() -> NSData {
        let digest = SHA256.hash(data: self as Data)
        return Data(digest) as NSData
    }
}

extension NSDate {
    func addingDays(_ days: Int) -> Date? {
        return Calendar.current.date(byAdding: .day, value: days, to: self as Date)
    }
}
#endif
