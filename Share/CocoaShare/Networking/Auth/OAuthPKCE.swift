//
//  OAuthPKCE.swift
//  AniXPlayer
//
//  macOS only：PKCE（S256）与随机串生成。
//

import CryptoKit
import Foundation
import Security

struct OAuthPKCEPair: Equatable {
    let verifier: String
    let challenge: String
}

enum OAuthPKCE {
    /// RFC 7636：verifier 43-128 字符；这里用 32 字节随机数 -> 43 字符 base64url。
    static func makePair() -> OAuthPKCEPair {
        let verifier = randomURLSafeString(byteCount: 32)
        return OAuthPKCEPair(verifier: verifier, challenge: challenge(for: verifier))
    }

    /// S256：BASE64URL(SHA256(ASCII(verifier)))。
    static func challenge(for verifier: String) -> String {
        let digest = SHA256.hash(data: Data(verifier.utf8))
        return Data(digest).base64URLEncodedString
    }

    static func randomURLSafeString(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: max(byteCount, 16))
        let status = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        precondition(status == errSecSuccess, "SecRandomCopyBytes failed: \(status)")
        return Data(bytes).base64URLEncodedString
    }
}

extension Data {
    var base64URLEncodedString: String {
        base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }
}
