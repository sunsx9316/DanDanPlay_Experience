//
//  GlobalSettingModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/5.
//

import Foundation
import RxSwift
#if os(iOS)
import YYCategories
#endif

class GlobalSettingContext {

    lazy var fastMatch = BehaviorSubject<Bool>(value: Preferences.shared.fastMatch)

    lazy var autoLoadCustomDanmaku = BehaviorSubject<Bool>(value: Preferences.shared.autoLoadCustomDanmaku)

    lazy var autoLoadCustomSubtitle = BehaviorSubject<Bool>(value: Preferences.shared.autoLoadCustomSubtitle)

    lazy var danmakuCacheDay = BehaviorSubject<Int>(value: Preferences.shared.danmakuCacheDay)

    lazy var subtitleLoadOrder = BehaviorSubject<[String]?>(value: Preferences.shared.subtitleLoadOrder)

    lazy var host = BehaviorSubject<String>(value: Preferences.shared.host)

    lazy var mainColor = BehaviorSubject<ANXColor>(value: Preferences.shared.mainColor)

    lazy var playerCore = BehaviorSubject<MediaPlayer.CoreType>(value: Preferences.shared.playerCore)

    lazy var appLanguage = BehaviorSubject<AppLanguage>(value: Preferences.shared.appLanguage)

    lazy var hardwareDecoding = BehaviorSubject<Bool>(value: Preferences.shared.hwdecEnabled)

    lazy var icloudSyncEnabled = BehaviorSubject<Bool>(value: {
        if case .disabled = Preferences.shared.syncStatus { return false }
        return true
    }())

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
    
    var mainColor: ANXColor? {
        return (try? self.context.mainColor.value())
    }

    var playerCore: MediaPlayer.CoreType {
        return Preferences.shared.playerCore
    }

    var appLanguage: AppLanguage {
        return Preferences.shared.appLanguage
    }

    var hardwareDecodingEnabled: Bool {
        return (try? self.context.hardwareDecoding.value()) ?? true
    }

    var icloudSyncEnabled: Bool {
        return (try? self.context.icloudSyncEnabled.value()) ?? false
    }
}

class GlobalSettingModel {
    
    lazy var context = GlobalSettingContext()
    
    func allSettingType() -> [GlobalSettingType] {
        var types = GlobalSettingType.allCases
        if playerCore != .mpv {
            types.removeAll { $0 == .hardwareDecoding }
        }
        return types
    }
    
    func subtitle(settingType: GlobalSettingType) -> String {
        switch settingType {
        case .appLanguage:
            return Preferences.shared.appLanguage.displayName
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
        case .mainColor:
            return NSLocalizedString("App主题色", comment: "")
        case .playerCore:
            return self.playerCore.displayName
        case .hardwareDecoding:
            return self.hardwareDecodingEnabled ? NSLocalizedString("开启", comment: "") : NSLocalizedString("关闭", comment: "")
        case .icloudSync:
            return Preferences.shared.syncStatus.displayText
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
    
    func onChangeMainColor(_ color: ANXColor) {
        Preferences.shared.mainColor = color
        self.context.mainColor.onNext(color)
    }

    func onChangePlayerCore(_ coreType: MediaPlayer.CoreType) {
        Preferences.shared.playerCore = coreType
        self.context.playerCore.onNext(coreType)
    }

    func onChangeHwdecEnabled(_ enabled: Bool) {
        Preferences.shared.hwdecEnabled = enabled
        self.context.hardwareDecoding.onNext(enabled)
    }

    func onChangeAppLanguage(_ language: AppLanguage) {
        switch language {
        case .chinese:
            UserDefaults.standard.set(["zh-Hans"], forKey: "AppleLanguages")
        case .english:
            UserDefaults.standard.set(["en"], forKey: "AppleLanguages")
        case .followSystem:
            UserDefaults.standard.removeObject(forKey: "AppleLanguages")
        }
        UserDefaults.standard.synchronize()
        Preferences.shared.appLanguage = language
        self.context.appLanguage.onNext(language)
    }

    func cleanupCache() {
        CacheManager.shared.cleanupCache()
    }
    
    func onToggleSync(_ isOn: Bool) {
        if isOn {
            Preferences.shared.store.startSync()
            if case .available = Preferences.shared.syncStatus {
                Preferences.shared.commitSync()
            }
            updateSyncStatus()
        } else {
            Preferences.shared.icloudSyncEnabled = false
            updateSyncStatus()
        }
    }

    func onRetrySync() {
        Preferences.shared.retrySync()
        updateSyncStatus()
    }

    func updateSyncStatus() {
        if case .disabled = Preferences.shared.syncStatus {
            self.context.icloudSyncEnabled.onNext(false)
        } else {
            self.context.icloudSyncEnabled.onNext(true)
        }
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
