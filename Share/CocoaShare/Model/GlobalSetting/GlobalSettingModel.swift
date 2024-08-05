//
//  GlobalSettingModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/5.
//

import Foundation
import RxSwift

class GlobalSettingContext {
    
    lazy var fastMatch = BehaviorSubject<Bool>(value: Preferences.shared.fastMatch)
    
    lazy var autoLoadCustomDanmaku = BehaviorSubject<Bool>(value: Preferences.shared.autoLoadCustomDanmaku)
    
    lazy var autoLoadCustomSubtitle = BehaviorSubject<Bool>(value: Preferences.shared.autoLoadCustomSubtitle)
    
    lazy var danmakuCacheDay = BehaviorSubject<Int>(value: Preferences.shared.danmakuCacheDay)
    
    lazy var subtitleLoadOrder = BehaviorSubject<[String]?>(value: Preferences.shared.subtitleLoadOrder)
    
    lazy var host = BehaviorSubject<String>(value: Preferences.shared.host)
    
}

extension GlobalSettingModel {
    var fastMatch: Bool {
        return (try? self.context.fastMatch.value()) ?? false
    }
    
    var autoLoadCustomDanmaku: Bool {
        return (try? self.context.autoLoadCustomDanmaku.value()) ?? false
    }
    
    var autoLoadCustomSubtitle: Bool {
        return (try? self.context.autoLoadCustomSubtitle.value()) ?? false
    }
    
    var danmakuCacheDay: Int {
        return (try? self.context.danmakuCacheDay.value()) ?? 0
    }
    
    var subtitleLoadOrder: [String]? {
        return try? self.context.subtitleLoadOrder.value()
    }
    
    var host: String {
        return (try? self.context.host.value()) ?? ""
    }
}

class GlobalSettingModel {
    
    lazy var context = GlobalSettingContext()
    
    func allSettingType() -> [GlobalSettingType] {
        return GlobalSettingType.allCases
    }
    
    func subtitle(settingType: GlobalSettingType) -> String {
        switch settingType {
        case .fastMatch:
            return NSLocalizedString("关闭则手动关联", comment: "")
        case .danmakuCacheDay:
            let day = self.danmakuCacheDay
            let str: String
            if day <= 0 {
                str = NSLocalizedString("不缓存", comment: "")
            } else {
                str = String(format: "%ld天", day)
            }
            return str
        case .autoLoadCustomDanmaku:
            return NSLocalizedString("自动加载本地弹幕", comment: "")
        case .autoLoadCustomSubtitle:
            return NSLocalizedString("自动加载本地字幕", comment: "")
        case .subtitleLoadOrder:
            let desc = self.subtitleLoadOrder?.reduce("", { result, str in
                
                guard let result = result, !result.isEmpty else {
                    return str
                }
                
                return result + "," + str
            }) ?? ""
            
            if desc.isEmpty {
                return NSLocalizedString("未指定", comment: "")
            }
            return desc
        case .host:
            return self.host
        case .log:
            return NSLocalizedString("将.xlog文件提供给开发者", comment: "")
        case .cleanupCache:
            return NSLocalizedString("清除本地匹配记录、弹幕缓存等", comment: "")
        case .cleanupHistory:
            return NSLocalizedString("清除播放记录、历史等", comment: "")
        }
    }
    
    // MARK: 工具方法
    func onOpenFastMatch(_ isOn: Bool) {
        Preferences.shared.fastMatch = isOn
        self.context.fastMatch.onNext(isOn)
    }
    
    func onOpenAutoLoadCustomDanmaku(_ isOn: Bool) {
        Preferences.shared.autoLoadCustomDanmaku = isOn
        self.context.autoLoadCustomDanmaku.onNext(isOn)
    }
    
    func onOpenAutoLoadCustomSubtitle(_ isOn: Bool) {
        Preferences.shared.autoLoadCustomSubtitle = isOn
        self.context.autoLoadCustomSubtitle.onNext(isOn)
    }
    
    func onChangeDanmakuCacheDay(_ cacheDay: Int) {
        Preferences.shared.danmakuCacheDay = cacheDay
        self.context.danmakuCacheDay.onNext(cacheDay)
    }
    
    func onChangeSubtitleLoadOrder(_ subtitleLoadOrder: [String]?) {
        Preferences.shared.subtitleLoadOrder = subtitleLoadOrder
        self.context.subtitleLoadOrder.onNext(subtitleLoadOrder)
    }
    
    func onChangeHost(_ host: String) {
        Preferences.shared.host = host.isEmpty ? DefaultHost : host
        self.context.host.onNext(host)
    }
    
    func cleanupCache() {
        CacheManager.shared.cleanupCache()
    }
    
    func cleanupHistory() {
        HistoryManager.shared.cleanUpAllCache()
    }
    
    func backupAddress() -> Observable<[String]?> {
        return Observable<[String]?>.create { sub in
            ConfigNetworkHandle.getBackupIps { res, error in
                if let error = error {
                    DispatchQueue.main.async {
                        sub.onError(error)
                    }
                } else {
                    let ips = res?.answers.compactMap({ $0.data })
                    DispatchQueue.main.async {
                        sub.onNext(ips)
                        sub.onCompleted()
                    }
                }
            }
            
            return Disposables.create()
        }
    }
}
