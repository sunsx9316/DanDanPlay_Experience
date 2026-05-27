//
//  CryptoHelper.swift
//  AniXPlayer
//
//  Created for tvOS compatibility (replaces YYCategories crypto methods)
//

import Foundation
import CommonCrypto

#if !os(iOS)
extension NSString {
    func md5() -> String? {
        let str = self as String
        guard let data = str.data(using: .utf8) else { return nil }
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        data.withUnsafeBytes { ptr in
            _ = CC_MD5(ptr.baseAddress, CC_LONG(data.count), &digest)
        }
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
}

extension NSData {
    func md5String() -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_MD5_DIGEST_LENGTH))
        CC_MD5(self.bytes, CC_LONG(self.length), &digest)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }

    func sha256() -> NSData {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA256_DIGEST_LENGTH))
        CC_SHA256(self.bytes, CC_LONG(self.length), &digest)
        return NSData(bytes: digest, length: digest.count)
    }
}

extension NSDate {
    func addingDays(_ days: Int) -> Date? {
        return Calendar.current.date(byAdding: .day, value: days, to: self as Date)
    }
}
#endif
