//
//  HistoryManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/10/16.
//

import Foundation

class HistoryManager {
    
    static let shared = HistoryManager()
    
    private let storeKey = "DDPWatchTimeHistory"
    
    private lazy var storeObject: [String : TimeInterval] = {
        let dic = UserDefaults.standard.value(forKey: storeKey) as? [String : TimeInterval] ?? [String : TimeInterval]()
        return dic
    }()
    
    func storeWatchProgress(mediaKey: String, progress: Double) {
        self.storeObject[mediaKey] = progress
        self.store()
    }
    
    func cleanWatchProgress(mediaKey: String) {
        self.storeObject[mediaKey] = nil
        self.store()
    }
    
    func watchProgress(mediaKey: String) -> Double? {
        return self.storeObject[mediaKey]
    }
    
    private func store() {
        UserDefaults.standard.set(self.storeObject, forKey: storeKey)
    }
    
}
