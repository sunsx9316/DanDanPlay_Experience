//
//  AccessTokenHolder.swift
//  AniXPlayer
//
//  macOS only：access token 的内存持有者。
//
//  SessionStore 是 actor，但旧 NetworkManager 的 bearerTokenProvider 是同步闭包，
//  因此用一个加锁的小对象把「当前 access token」暴露给任意线程读取。
//

import Foundation

final class AccessTokenHolder: @unchecked Sendable {
    static let shared = AccessTokenHolder()

    private let lock = NSLock()
    private var token: String?

    func current() -> String? {
        lock.lock()
        defer { lock.unlock() }
        return token
    }

    func set(_ token: String?) {
        lock.lock()
        self.token = token
        lock.unlock()
    }
}
