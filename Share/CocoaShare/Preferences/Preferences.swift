//
//  Preferences.swift
//  Runner
//
//  Created by JimHuang on 2020/3/12.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
import DanmakuRender

class Preferences {
    
    /// 偏好设置
    enum KeyName: String {
        /// 是否开启快速匹配
        case fastMatch
        /// 防挡字幕
        case subtitleSafeArea
        /// 弹幕缓存时间
        case danmakuCacheDay
        /// 弹幕字体大小
        case danmakuFontSize
        /// 弹幕速度
        case danmakuSpeed
        /// 弹幕透明度
        case danmakuAlpha
        
        /// 弹幕在屏幕中的展示区域
        case danmakuArea
        
        /// 展示首页提示
        case showHomePageTips
        
        /// 播放速度
        case playerSpeed
        
        /// 播放模式 单曲循环等
        case playerMode
        
        /// 是否检查更新
        case checkUpdate
        
        /// 发送的弹幕类型
        case sendDanmakuType
        
        /// 发送的弹幕颜色
        case sendDanmakuColor

        /// 发送弹幕颜色列表
        case sendDanmakuColors
        
        /// 弹幕开关
        case showDanmaku
        
        /// 是否自动加载本地弹幕
        case autoLoadCustomDanmaku
        
        /// 是否自动加载本地字幕
        case autoLoadCustomSubtitle
        
        /// 弹幕偏移时间
        case danmakuOffsetTime
        
        /// 弹幕偏移时间
        case subtitleOffsetTime

        /// smb登录信息
        case smbLoginInfo = "smbLoginInfo_v2"

        /// webdav登录信息
        case webDavLoginInfo = "webDavLoginInfo_v2"

        /// ftp登录信息
        case ftpLoginInfo = "ftpLoginInfo_v2"

        /// 电脑端登录信息
        case pcLoginInfo = "pcLoginInfo_v2"

        /// Emby 登录信息
        case embyLoginInfo = "embyLoginInfo_v2"

        /// Jellyfin 登录信息
        case jellyfinLoginInfo = "jellyfinLoginInfo_v2"

        /// 字幕加载顺序关键字
        case subtitleLoadOrder
        
        /// 弹幕密度
        case danmakuDensity = "danmakuDensity_v2"
        
        /// 域名
        case host
        
        /// 上次更新的版本号
        case lastUpdateVersion
        
        /// 合并重复弹幕
        case mergeSameDanmaku
        
        /// 自动跳过片头片尾
        case autoJumpTitleEnding
        
        /// 自动跳过片头时长
        case jumpTitleDuration
        
        /// 自动跳过片尾时长
        case jumpEndingDuration
        
        /// 登录信息
        case loginInfo
        
        /// 字幕Y位置百分比
        case subtitleYPosition
        
        /// 字幕字体大小
        case subtitleFontSize
        
        /// 字幕字体名
        case subtitleFontName
        
        /// 音频偏移
        case audioOffsetTime
        
        /// 屏蔽弹幕
        case filterDanmaku = "filterDanmaku_v2"

        /// 边缘样式
        case danmakuEffectStyle
        
        /// 主题色
        case mainColor = "mainColor_v2"
        
        /// 弹幕随机颜色
        case openDanmakuRandomColor
        
        /// 长宽比
        case aspectRatio

        /// 播放器内核
        case playerCore

        /// 应用语言 0=系统默认 1=中文 2=英文
        case appLanguage

        /// 字幕颜色
        case subtitleColor

        /// 字幕样式开关
        case subtitleStyle

        /// 自定义域名列表
        case customHosts

        /// 备用域名缓存
        case backupHosts

        /// 画中画
        case playerPiP

        /// 文件浏览器排序选项
        case fileBrowserSortOption

        /// 迷你进度条显示
        case miniProgressBar

        /// 硬件解码开关
        case hwdecEnabled

        /// 文件浏览器排序升降序
        case fileBrowserSortAscending

        /// iCloud 同步开关
        case icloudSyncEnabled

        /// 播放进度历史
        case watchTimeHistory = "DDPWatchTimeHistory"

        /// 最后观看时间历史
        case lastWatchDateHistory = "DDPLatWatchDateHistory"

        var storeKey: String {
            return self.rawValue
        }
    }
    
    static let shared = Preferences()

    /// 内部多后端存储，仅被 Preferences 使用
    let store = Store()

    private init() {
        migrateOldFormatKeys()
        // 不在 init 时自动恢复同步，避免在无 KVS entitlement 的设备上
        // 访问 NSUbiquitousKeyValueStore 导致 EXC_BREAKPOINT。
        // 同步恢复由用户手动打开开关触发 onToggleSync → startSync()
    }

    /// 迁移旧格式 [LoginInfo]/[FilterDanmaku] 直接 JSON 编码 → 新格式 via Array<Storeable> 双层编码
    /// TODO: 2026 Q3 后删除
    private func migrateOldFormatKeys() {
        let loginInfoMigrations: [(old: String, new: KeyName)] = [
            ("pcLoginInfo", .pcLoginInfo),
            ("embyLoginInfo", .embyLoginInfo),
            ("jellyfinLoginInfo", .jellyfinLoginInfo),
            ("smbLoginInfo", .smbLoginInfo),
            ("webDavLoginInfo", .webDavLoginInfo),
            ("ftpLoginInfo", .ftpLoginInfo),
        ]

        for (oldKey, newKey) in loginInfoMigrations {
            guard store.contains(oldKey), !store.contains(newKey.storeKey) else { continue }
            if let oldData: Data = store.value(forKey: oldKey),
               let oldValues = try? JSONDecoder().decode([LoginInfo].self, from: oldData) {
                store.set(oldValues, forKey: newKey.storeKey)
            }
        }

        // FilterDanmaku 同理
        let oldFilterKey = "filterDanmaku"
        if store.contains(oldFilterKey), !store.contains(KeyName.filterDanmaku.storeKey),
           let oldData: Data = store.value(forKey: oldFilterKey),
           let oldValues = try? JSONDecoder().decode([FilterDanmaku].self, from: oldData) {
            store.set(oldValues, forKey: KeyName.filterDanmaku.storeKey)
        }
    }

    @StoreWrapper(defaultValue: PlayerAspectRatio.default, key: .aspectRatio)
    var aspectRatio: PlayerAspectRatio

    @StoreWrapper(defaultValueGetter: {
#if os(iOS) || os(tvOS)
        if #available(iOS 14, tvOS 14, *) {
            return .mpv
        } else {
            return .vlc
        }
#else
        return .mpv
#endif
    }, key: .playerCore)
    var playerCore: MediaPlayer.CoreType

    /// 应用语言
    @StoreWrapper(defaultValue: .followSystem, key: .appLanguage)
    var appLanguage: AppLanguage

    /// 字幕颜色（nil 表示使用默认颜色）
    @StoreWrapper(defaultValue: nil, key: .subtitleColor)
    var subtitleColor: ANXColor?

    /// 字幕样式开关
    @StoreWrapper(defaultValue: true, key: .subtitleStyle, syncToCloud: true)
    var subtitleStyle: Bool

    /// 画中画
    @StoreWrapper(defaultValue: false, key: .playerPiP)
    var playerPiP: Bool

    /// 迷你进度条显示
    @StoreWrapper(defaultValue: true, key: .miniProgressBar)
    var miniProgressBar: Bool

    /// 硬件解码开关（仅 MPV，默认开启）
    @StoreWrapper(defaultValue: true, key: .hwdecEnabled)
    var hwdecEnabled: Bool

    /// iCloud 同步开关（开关状态不同步到 iCloud）
    @StoreWrapper(defaultValue: false, key: .icloudSyncEnabled)
    var icloudSyncEnabled: Bool {
        didSet {
            if !icloudSyncEnabled {
                store.stopSync()
            }
        }
    }

    /// 文件浏览器排序选项
    @StoreWrapper(defaultValue: FileSortOption.default, key: .fileBrowserSortOption, syncToCloud: true)
    var fileBrowserSortOption: FileSortOption

    /// 文件浏览器排序升降序
    @StoreWrapper(defaultValue: true, key: .fileBrowserSortAscending, syncToCloud: true)
    var fileBrowserSortAscending: Bool

    @StoreWrapper(defaultValue: ANXColor.defaultMainColor, key: .mainColor)
    var mainColor: ANXColor
    
    @StoreWrapper(defaultValue: "0", key: .lastUpdateVersion)
    var lastUpdateVersion: String
    
    @StoreWrapper(defaultValue: 0, key: .danmakuOffsetTime, syncToCloud: true)
    var danmakuOffsetTime: Int
    
    @StoreWrapper(defaultValue: 0, key: .subtitleOffsetTime, syncToCloud: true)
    var subtitleOffsetTime: Int
    
    @StoreWrapper(defaultValue: 0, key: .audioOffsetTime)
    var audioOffsetTime: Int
    
    @StoreWrapper(defaultValue: true, key: .autoLoadCustomDanmaku, syncToCloud: true)
    var autoLoadCustomDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .autoLoadCustomSubtitle, syncToCloud: true)
    var autoLoadCustomSubtitle: Bool
    
    @StoreWrapper(defaultValue: true, key: .showDanmaku, syncToCloud: true)
    var isShowDanmaku: Bool
    
    @StoreWrapper(defaultValue: true, key: .checkUpdate, syncToCloud: true)
    var checkUpdate: Bool
    
    @StoreWrapper(defaultValue: DefaultHost, key: .host, syncToCloud: true)
    var host: String
    
    @StoreWrapper(defaultValue: true, key: .mergeSameDanmaku, syncToCloud: true)
    var isMergeSameDanmaku: Bool
    
    @StoreWrapper(defaultValue: false, key: .autoJumpTitleEnding, syncToCloud: true)
    var autoJumpTitleEnding: Bool
    
    @StoreWrapper(defaultValue: 0.0, key: .jumpTitleDuration, syncToCloud: true)
    var jumpTitleDuration: Double
    
    @StoreWrapper(defaultValue: 0.0, key: .jumpEndingDuration, syncToCloud: true)
    var jumpEndingDuration: Double
    
    @StoreWrapper(defaultValue: 0, key: .subtitleYPosition)
    var subtitleYPosition: Float
    
    @StoreWrapper(defaultValueGetter: {
        #if os(tvOS)
        return 35
        #else
        return 20
        #endif
    }, key: .subtitleFontSize)
    var subtitleFontSize: Float
    
    @StoreWrapper(defaultValue: "", key: .subtitleFontName)
    var subtitleFontName: String
    
    @StoreWrapper(defaultValue: false, key: .openDanmakuRandomColor, syncToCloud: true)
    var openDanmakuRandomColor: Bool
    
    @StoreWrapper(defaultValue: nil, key: .loginInfo)
    var loginInfo: AnixLoginInfo? {
        didSet {
            NotificationCenter.default.post(name: .AnixUserLoginStateDidChange, object: nil)
        }
    }
    
    
    @StoreWrapper(defaultValue: Comment.Mode.normal, key: .sendDanmakuType, syncToCloud: true)
    var sendDanmakuType: Comment.Mode
    
    @StoreWrapper(defaultValue: ANXColor.white, key: .sendDanmakuColor, syncToCloud: true)
    var sendDanmakuColor: ANXColor

    static let defaultSendDanmakuColors: [ANXColor] = [
        ANXColor(anxRgb: 0xFFFFFF),
        ANXColor(anxRgb: 0xFF0000),
        ANXColor(anxRgb: 0x00FF00),
        ANXColor(anxRgb: 0x0000FF),
        ANXColor(anxRgb: 0xFFFF00),
        ANXColor(anxRgb: 0xFF00FF),
    ]

    @StoreWrapper(defaultValue: Preferences.defaultSendDanmakuColors, key: .sendDanmakuColors, syncToCloud: true)
    var sendDanmakuColors: [ANXColor]
    
    @StoreWrapper(defaultValue: PlayerMode.autoPlayNext, key: .playerMode, syncToCloud: true)
    var playerMode: PlayerMode
    
    @StoreWrapper(defaultValue: 1, key: .playerSpeed, syncToCloud: true)
    var playerSpeed: Double
    
    @StoreWrapper(defaultValue: true, key: .showHomePageTips)
    var showHomePageTips: Bool
    
    @StoreWrapper(defaultValue: DanmakuAreaType.area_1_1, key: .danmakuArea, syncToCloud: true)
    var danmakuArea: DanmakuAreaType
    
    @StoreWrapper(defaultValue: 1, key: .danmakuAlpha, syncToCloud: true)
    var danmakuAlpha: Double
    
    @StoreWrapper(defaultValue: true, key: .fastMatch, syncToCloud: true)
    var fastMatch: Bool
    
    @StoreWrapper(defaultValue: true, key: .subtitleSafeArea, syncToCloud: true)
    var subtitleSafeArea: Bool
    
    @StoreWrapper(defaultValue: 7, key: .danmakuCacheDay, syncToCloud: true)
    var danmakuCacheDay: Int
    
    @StoreWrapper(defaultValueGetter: {
        #if os(tvOS)
        return 30.0
        #else
        return 20.0
        #endif
    }, key: .danmakuFontSize)
    var danmakuFontSize: Double
    
    @StoreWrapper(defaultValue: 1, key: .danmakuSpeed, syncToCloud: true)
    var danmakuSpeed: Double
    
    /// 弹幕密度 取值 1 ~ 10
    @StoreWrapper(defaultValue: 10, key: .danmakuDensity, syncToCloud: true)
    var danmakuDensity: Float
    
    /// 弹幕边缘样式
    @StoreWrapper(defaultValue: DanmakuEffectStyle.stroke, key: .danmakuEffectStyle, syncToCloud: true)
    var danmakuEffectStyle: DanmakuEffectStyle
    
    @StoreWrapper(defaultValue: nil, key: .pcLoginInfo)
    var pcLoginInfos: [LoginInfo]?

    @StoreWrapper(defaultValue: nil, key: .embyLoginInfo)
    var embyLoginInfos: [LoginInfo]?

    @StoreWrapper(defaultValue: nil, key: .jellyfinLoginInfo)
    var jellyfinLoginInfos: [LoginInfo]?

    @StoreWrapper(defaultValue: nil, key: .smbLoginInfo)
    var smbLoginInfos: [LoginInfo]?

    @StoreWrapper(defaultValue: nil, key: .webDavLoginInfo)
    var webDavLoginInfos: [LoginInfo]?

    @StoreWrapper(defaultValue: nil, key: .ftpLoginInfo)
    var ftpLoginInfos: [LoginInfo]?
    
    @StoreWrapper(defaultValue: nil, key: .subtitleLoadOrder, syncToCloud: true)
    var subtitleLoadOrder: [String]?
    
    @StoreWrapper(defaultValue: nil, key: .filterDanmaku, syncToCloud: true)
    var filterDanmakus: [FilterDanmaku]?

    @StoreWrapper(defaultValue: nil, key: .customHosts, syncToCloud: true)
    var customHosts: [String]?

    @StoreWrapper(defaultValue: nil, key: .backupHosts, syncToCloud: true)
    var backupHosts: [String]?

    @StoreWrapper(defaultValue: nil, key: .watchTimeHistory, syncToCloud: true)
    var watchTimeHistory: [String: TimeInterval]?

    @StoreWrapper(defaultValue: nil, key: .lastWatchDateHistory, syncToCloud: true)
    var lastWatchDateHistory: [String: TimeInterval]?

}

extension Preferences {
    @propertyWrapper
    struct StoreWrapper<Value: Storeable> {

        private var value: Value
        let key: KeyName
        let syncToCloud: Bool

        init(defaultValue: Value, key: KeyName, syncToCloud: Bool = false) {
            self.value = defaultValue
            self.key = key
            self.syncToCloud = syncToCloud
            Store.registry.append((key.storeKey, syncToCloud))
        }

        init(defaultValueGetter: () -> Value, key: KeyName, syncToCloud: Bool = false) {
            self.value = defaultValueGetter()
            self.key = key
            self.syncToCloud = syncToCloud
            Store.registry.append((key.storeKey, syncToCloud))
        }

        /// $propertyName 可读取 syncToCloud、key 等 wrapper 元信息
        var projectedValue: StoreWrapper {
            return self
        }

        var wrappedValue: Value {
            get {
                return Preferences.shared.store.value(forKey: key.storeKey) ?? self.value
            }
            set {
                // 检测 Optional 类型的 nil 值，避免 Store.set 中 double-wrap 导致强制解包崩溃
                if let nilable = newValue as? _OptionalNilable, nilable._isNil {
                    Preferences.shared.store.remove(key.storeKey)
                } else {
                    Preferences.shared.store.set(newValue, forKey: key.storeKey)
                }
            }
        }
    }
}
