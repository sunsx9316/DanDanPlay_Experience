//
//  HistoryManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/10/16.
//

import Foundation


class HistoryManager {
    
    protocol WatchProgressStoreable {
        var watchProgressKey: String { get }
    }
    
    protocol lastWatchDateStoreable {
        var lastWatchDateKey: String { get }
    }
    
    static let shared = HistoryManager()
    
    private let watchProgressStoreKey = "DDPWatchTimeHistory"
    
    private let lastWatchDateStoreKey = "DDPLatWatchDateHistory"
    
    private lazy var watchProgressStoreMap: [String : TimeInterval] = {
        let dic = UserDefaults.standard.value(forKey: watchProgressStoreKey) as? [String : TimeInterval] ?? [String : TimeInterval]()
        return dic
    }()
    
    private lazy var lastWatchDateStoreMap: [String : TimeInterval] = {
        let dic = UserDefaults.standard.value(forKey: lastWatchDateStoreKey) as? [String : TimeInterval] ?? [String : TimeInterval]()
        return dic
    }()
    
    
    /// 保存上次播放进度
    /// - Parameters:
    ///   - mediaKey: 媒体
    ///   - progress: 进度，为空则清除进度
    func storeWatchProgress(media: WatchProgressStoreable, progress: Double?) {
        self.watchProgressStoreMap[media.watchProgressKey] = progress
        self.storeWatchProgress()
    }
    
    /// 获取上次播放进度
    /// - Parameter media: 媒体
    /// - Returns: 进度
    func watchProgress(media: WatchProgressStoreable) -> Double? {
        return self.watchProgressStoreMap[media.watchProgressKey]
    }
    
    
    /// 保存上次播放时间
    /// - Parameters:
    ///   - mediaKey: 媒体id
    ///   - date: 播放时间，为空则清除进度
    func storeLastWatchDate(media: lastWatchDateStoreable, date: Date?) {
        self.lastWatchDateStoreMap[media.lastWatchDateKey] = date?.timeIntervalSince1970
        self.storeLastWatchDate()
    }
    
    /// 获取上次播放时间
    /// - Parameter mediaKey: 媒体id
    /// - Returns: 进度
    func lastWatchDate(media: lastWatchDateStoreable) -> Date? {
        if let timeIntervalSince1970 = self.lastWatchDateStoreMap[media.lastWatchDateKey] {
            return Date(timeIntervalSince1970: timeIntervalSince1970)
        }
        return nil
    }
    
    /// 清空历史记录
    func cleanUpAllCache() {
        self.watchProgressStoreMap.removeAll()
        self.lastWatchDateStoreMap.removeAll()
        self.storeWatchProgress()
        self.storeLastWatchDate()
    }
    
    // MARK: Private Method
    private func storeWatchProgress() {
        UserDefaults.standard.set(self.watchProgressStoreMap, forKey: watchProgressStoreKey)
    }
    
    private func storeLastWatchDate() {
        UserDefaults.standard.set(self.lastWatchDateStoreMap, forKey: lastWatchDateStoreKey)
    }
    
}
