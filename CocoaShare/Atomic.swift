//
//  Atomic.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/4/17.
//

import Foundation

@propertyWrapper
struct Atomic<Value> {

    private var value: Value
    private let lock = NSLock()

    init(wrappedValue value: Value) {
        self.value = value
    }

    var wrappedValue: Value {
      get { return load() }
      set { store(newValue: newValue) }
    }

    private func load() -> Value {
        lock.lock()
        defer { lock.unlock() }
        return value
    }

    private mutating func store(newValue: Value) {
        lock.lock()
        defer { lock.unlock() }
        value = newValue
    }
}
