//
//  MPV.swift
//  CocoaShare
//
//  libmpv C API 的 Swift 风格封装
//  将 mpv_* C 函数封装为面向对象的 Swift 接口
//  参考 mpv 官方文档 (https://mpv.io/manual/stable/) 进行模块化设计
//

import Foundation
import Libmpv

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - MPV 事件类型

/// MPV 事件 ID
public enum MPVEventID: Int {
    case none = 0
    case shutdown = 1
    case logMessage = 2
    case getPropertyReply = 3
    case setPropertyReply = 4
    case commandReply = 5
    case startFile = 6
    case endFile = 7
    case fileLoaded = 8
    case idle = 11
    case tick = 14
    case clientMessage = 16
    case videoReconfig = 17
    case audioReconfig = 18
    case seek = 20
    case playbackRestart = 21
    case propertyChange = 22
    case queueOverflow = 24
    case hook = 25

    init(from rawValue: mpv_event_id) {
        self = MPVEventID(rawValue: Int(rawValue.rawValue)) ?? .none
    }
}

// MARK: - MPV 事件数据

/// MPV 事件包装器
public struct MPVEvent {
    public let id: MPVEventID
    public let propertyName: String?

    init(from event: UnsafeMutablePointer<mpv_event>) {
        self.id = MPVEventID(from: event.pointee.event_id)

        var name: String? = nil
        if self.id == .propertyChange, let data = event.pointee.data {
            let property = data.assumingMemoryBound(to: mpv_event_property.self).pointee
            name = String(cString: property.name)
        }
        self.propertyName = name
    }
}

// MARK: - MPV 属性

/// MPV 属性名称
public enum MPVProperty {
    // Playback
    case pause
    case cache
    case playbackTime

    // Time
    case timePos
    case timeStart
    case duration
    case remaining

    // Audio
    case audioId
    case audioDevice
    case volume
    case mute

    // Video
    case videoId
    case videoAspect
    case fullscreen
    case windowId
    case hwdec

    // Subtitle
    case subtitleId
    case secondarySubtitleId
    case subtitleDelay
    case subtitleMargin
    case subtitleFontSize
    case subtitleColor
    case subtitleBackColor
    case subtitleFont
    case subtitleFontsDir
    case subtitleAss
    case subtitleAssOverride
    case subtitleAuto
    case subtitleUseMargins

    // Track
    case trackList
    case trackType(Int)
    case trackId(Int)
    case trackTitle(Int)
    case trackLang(Int)

    // Screenshot
    case screenshotMode

    // VO
    case vo
    case gpuApi
    case gpuContext

    public var rawValue: String {
        switch self {
        case .pause: return "pause"
        case .cache: return "cache"
        case .playbackTime: return "playback-time"
        case .timePos: return "time-pos"
        case .timeStart: return "time-start"
        case .duration: return "duration"
        case .remaining: return "remaining"
        case .audioId: return "aid"
        case .audioDevice: return "audio-device"
        case .volume: return "volume"
        case .mute: return "mute"
        case .videoId: return "vid"
        case .videoAspect: return "video-aspect-override"
        case .fullscreen: return "fullscreen"
        case .windowId: return "wid"
        case .hwdec: return "hwdec"
        case .subtitleId: return "sid"
        case .secondarySubtitleId: return "secondary-sid"
        case .subtitleDelay: return "sub-delay"
        case .subtitleMargin: return "sub-margin"
        case .subtitleFontSize: return "sub-font-size"
        case .subtitleColor: return "sub-color"
        case .subtitleBackColor: return "sub-back-color"
        case .subtitleFont: return "sub-font"
        case .subtitleFontsDir: return "sub-fonts-dir"
        case .subtitleAss: return "sub-ass"
        case .subtitleAssOverride: return "sub-ass-override"
        case .subtitleAuto: return "sub-auto"
        case .subtitleUseMargins: return "sub-use-margins"
        case .trackList: return "track-list"
        case .trackType(let i): return "track-list/\(i)/type"
        case .trackId(let i): return "track-list/\(i)/id"
        case .trackTitle(let i): return "track-list/\(i)/title"
        case .trackLang(let i): return "track-list/\(i)/lang"
        case .screenshotMode: return "screenshot-mode"
        case .vo: return "vo"
        case .gpuApi: return "gpu-api"
        case .gpuContext: return "gpu-context"
        }
    }
}

// MARK: - MPV 命令

/// MPV 命令
public enum MPVCommand {
    // File
    case loadFile
    case stop

    // Seek
    case seek
    case revertSeek

    // Track
    case trackSelect
    case subAdd
    case subRemove
    case audioAdd
    case audioRemove

    // Subtitle
    case subSeek

    // Property
    case set
    case add
    case multiply
    case cycle
    case cycleValues

    // Screenshot
    case screenshot
    case screenshotToFile

    // OSD
    case showText
    case overlayAdd
    case overlayRemove

    public var rawValue: String {
        switch self {
        case .loadFile: return "loadfile"
        case .stop: return "stop"
        case .seek: return "seek"
        case .revertSeek: return "revert-seek"
        case .trackSelect: return "track-select"
        case .subAdd: return "sub-add"
        case .subRemove: return "sub-remove"
        case .audioAdd: return "audio-add"
        case .audioRemove: return "audio-remove"
        case .subSeek: return "sub-seek"
        case .set: return "set"
        case .add: return "add"
        case .multiply: return "multiply"
        case .cycle: return "cycle"
        case .cycleValues: return "cycle-values"
        case .screenshot: return "screenshot"
        case .screenshotToFile: return "screenshot-to-file"
        case .showText: return "show-text"
        case .overlayAdd: return "overlay-add"
        case .overlayRemove: return "overlay-remove"
        }
    }
}

// MARK: - 辅助方法扩展

extension MPV {
    /// 执行 mpv 命令
    func executeCommand(_ args: [String]) {
        guard let mpv = mpv else { return }

        var cargs: [UnsafePointer<CChar>?] = args.map { UnsafePointer(strdup($0)) }
        cargs.append(nil)

        _ = cargs.withUnsafeMutableBufferPointer { buffer in
            mpv_command(mpv, buffer.baseAddress)
        }

        for ptr in cargs {
            if let p = ptr {
                free(UnsafeMutablePointer(mutating: p))
            }
        }
    }

    /// 转换颜色为十六进制字符串
    #if os(iOS)
    static func colorToHex(_ color: UIColor) -> String {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        color.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
    #elseif os(macOS)
    static func colorToHex(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else { return "#FFFFFF" }
        return String(format: "#%02X%02X%02X",
                      Int(rgb.redComponent * 255),
                      Int(rgb.greenComponent * 255),
                      Int(rgb.blueComponent * 255))
    }
    #endif
}

// MARK: - MPV 主类

public class MPV {

    // MARK: - 私有属性

    private var mpv: OpaquePointer?

    // MARK: - 类型安全的 API (lazy 存储)

    public lazy var playback = PlaybackAPI(mpv: self)
    public lazy var time = TimeAPI(mpv: self)
    public lazy var audio = AudioAPI(mpv: self)
    public lazy var video = VideoAPI(mpv: self)
    public lazy var subtitle = SubtitleAPI(mpv: self)
    public lazy var track = TrackAPI(mpv: self)
    public lazy var screenshot = ScreenshotAPI(mpv: self)

    // MARK: - 初始化

    public init?() {
        guard let handle = mpv_create() else {
            return nil
        }
        self.mpv = handle
    }

    deinit {
        if let mpv = mpv {
            mpv_terminate_destroy(mpv)
        }
    }

    // MARK: - 选项设置

    /// 设置字符串选项
    public func setOptionString(_ property: MPVProperty, _ value: String) {
        guard let mpv = mpv else { return }
        mpv_set_option_string(mpv, property.rawValue, value)
    }

    /// 设置整数属性
    public func setProperty(_ property: MPVProperty, _ value: Int64) {
        guard let mpv = mpv else { return }
        var data = value
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_INT64, &data)
    }

    /// 设置浮点数属性
    public func setProperty(_ property: MPVProperty, _ value: Double) {
        guard let mpv = mpv else { return }
        var data = value
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_DOUBLE, &data)
    }

    /// 设置布尔属性
    public func setProperty(_ property: MPVProperty, _ value: Bool) {
        guard let mpv = mpv else { return }
        var data: Int = value ? 1 : 0
        mpv_set_property(mpv, property.rawValue, MPV_FORMAT_FLAG, &data)
    }

    // MARK: - 属性获取

    /// 获取整数属性
    public func getPropertyInt64(_ property: MPVProperty) -> Int64? {
        guard let mpv = mpv else { return nil }
        var data = Int64()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_INT64, &data)
        return ret >= 0 ? data : nil
    }

    /// 获取浮点数属性
    public func getPropertyDouble(_ property: MPVProperty) -> Double? {
        guard let mpv = mpv else { return nil }
        var data = Double()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_DOUBLE, &data)
        return ret >= 0 ? data : nil
    }

    /// 获取布尔属性
    public func getPropertyFlag(_ property: MPVProperty) -> Bool? {
        guard let mpv = mpv else { return nil }
        var data = Int64()
        let ret = mpv_get_property(mpv, property.rawValue, MPV_FORMAT_FLAG, &data)
        return ret >= 0 ? data > 0 : nil
    }

    /// 获取字符串属性
    public func getPropertyString(_ property: MPVProperty) -> String? {
        guard let mpv = mpv else { return nil }
        let cstr = mpv_get_property_string(mpv, property.rawValue)
        defer { mpv_free(cstr) }
        return cstr == nil ? nil : String(cString: cstr!)
    }

    // MARK: - 初始化

    /// 初始化 mpv 实例
    public func initialize() -> Int32 {
        guard let mpv = mpv else { return -1 }
        return mpv_initialize(mpv)
    }

    // MARK: - 属性观察

    /// 观察属性变化
    public func observeProperty(_ property: MPVProperty) {
        guard let mpv = mpv else { return }
        mpv_observe_property(mpv, 0, property.rawValue, MPV_FORMAT_NONE)
    }

    // MARK: - 事件

    /// 等待事件
    public func waitEvent(_ timeout: Double) -> MPVEvent? {
        guard let mpv = mpv else { return nil }
        guard let event = mpv_wait_event(mpv, timeout) else { return nil }
        return MPVEvent(from: event)
    }

    // MARK: - 文件操作

    /// 加载文件
    public func loadFile(_ path: String, replace: Bool = true) {
        let action = replace ? "replace" : "append"
        executeCommand(["loadfile", path, action])
    }

    /// 停止播放
    public func stop() {
        executeCommand(["stop"])
    }

    // MARK: - 终止

    /// 终止 mpv 实例
    public func terminate() {
        guard let mpv = mpv else { return }
        mpv_terminate_destroy(mpv)
    }
}

// MARK: - Playback API

public class PlaybackAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 暂停/恢复播放
    public var isPaused: Bool {
        get { player?.getPropertyFlag(.pause) ?? false }
        set { player?.setProperty(.pause, newValue) }
    }

    /// 切换暂停状态
    public func togglePause() {
        player?.executeCommand(["cycle", "pause"])
    }

    /// 设置播放速度
    public func setSpeed(_ speed: Double) {
        player?.setProperty(.playbackTime, speed)
    }
}

// MARK: - Time API

public class TimeAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前播放位置（秒）
    public var position: Double? {
        player?.getPropertyDouble(.timePos)
    }

    /// 媒体总时长（秒）
    public var duration: Double? {
        player?.getPropertyDouble(.duration)
    }

    /// 剩余播放时间（秒）
    public var remaining: Double? {
        player?.getPropertyDouble(.remaining)
    }

    /// 跳转到指定时间
    public func seek(to seconds: Double, absolute: Bool = true) {
        let type = absolute ? "absolute" : "relative"
        player?.executeCommand(["seek", String(seconds), type])
    }
}

// MARK: - Audio API

public class AudioAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前音频轨道 ID
    public var audioId: Int64? {
        get { player?.getPropertyInt64(.audioId) }
        set {
            if let id = newValue {
                player?.setProperty(.audioId, id)
            }
        }
    }

    /// 音量 (0-100)
    public var volume: Int64? {
        get { player?.getPropertyInt64(.volume) }
        set {
            if let vol = newValue {
                player?.setProperty(.volume, vol)
            }
        }
    }

    /// 静音状态
    public var isMuted: Bool {
        get { player?.getPropertyFlag(.mute) ?? false }
        set { player?.setProperty(.mute, newValue) }
    }

    /// 音频设备名称
    public var audioDevice: String? {
        player?.getPropertyString(.audioDevice)
    }

    /// 切换静音状态
    public func toggleMute() {
        player?.executeCommand(["cycle", "mute"])
    }

    /// 增加音量
    public func addVolume(_ delta: Int64) {
        player?.executeCommand(["add", "volume", String(delta)])
    }
}

// MARK: - Video API

public class VideoAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前视频轨道 ID
    public var videoId: Int64? {
        get { player?.getPropertyInt64(.videoId) }
        set {
            if let id = newValue {
                player?.setProperty(.videoId, id)
            }
        }
    }

    /// 宽高比 (nil = 自动, 0 = 自动, -1 = 禁用)
    public var aspectRatio: Double? {
        get { player?.getPropertyDouble(.videoAspect) }
        set {
            if let ratio = newValue {
                player?.setProperty(.videoAspect, ratio)
            }
        }
    }

    /// 禁用宽高比覆盖，恢复视频原始比例
    public func resetAspectRatio() {
        player?.setProperty(.videoAspect, -1.0)
    }

    /// 全屏状态
    public var isFullscreen: Bool {
        get { player?.getPropertyFlag(.fullscreen) ?? false }
        set { player?.setProperty(.fullscreen, newValue) }
    }

    /// 窗口 ID (用于嵌入)
    public var windowId: Int64? {
        get { player?.getPropertyInt64(.windowId) }
        set {
            if let id = newValue {
                player?.setProperty(.windowId, id)
            }
        }
    }

    /// 硬件解码模式
    public var hardwareDecoding: String? {
        get { player?.getPropertyString(.hwdec) }
        set { player?.setOptionString(.hwdec, newValue ?? "no") }
    }
}

// MARK: - Subtitle API

public class SubtitleAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前字幕轨道 ID
    public var subtitleId: Int64? {
        get { player?.getPropertyInt64(.subtitleId) }
        set {
            if let id = newValue {
                player?.setProperty(.subtitleId, id)
            }
        }
    }

    /// 副字幕轨道 ID
    public var secondarySubtitleId: Int64? {
        get { player?.getPropertyInt64(.secondarySubtitleId) }
        set {
            if let id = newValue {
                player?.setProperty(.secondarySubtitleId, id)
            }
        }
    }

    /// 字幕延迟（秒）
    public var delay: Double? {
        get { player?.getPropertyDouble(.subtitleDelay) }
        set {
            if let d = newValue {
                player?.setProperty(.subtitleDelay, d)
            }
        }
    }

    /// 字幕字体大小
    public var fontSize: Int64? {
        get { player?.getPropertyInt64(.subtitleFontSize) }
        set {
            if let size = newValue {
                player?.setOptionString(.subtitleFontSize, "\(size)")
            }
        }
    }

    #if os(iOS)
    /// 字幕颜色
    public var color: UIColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleColor) else { return nil }
            return UIColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleColor, MPV.colorToHex(color))
            }
        }
    }

    /// 字幕后景色
    public var backColor: UIColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleBackColor) else { return nil }
            return UIColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleBackColor, MPV.colorToHex(color) + "80")
            }
        }
    }
    #elseif os(macOS)
    /// 字幕颜色
    public var color: NSColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleColor) else { return nil }
            return NSColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleColor, MPV.colorToHex(color))
            }
        }
    }

    /// 字幕后景色
    public var backColor: NSColor? {
        get {
            guard let hex = player?.getPropertyString(.subtitleBackColor) else { return nil }
            return NSColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setOptionString(.subtitleBackColor, MPV.colorToHex(color) + "80")
            }
        }
    }
    #endif

    /// 添加外部字幕文件
    public func addExternal(path: String, select: Bool = true) {
        let action = select ? "select" : "auto"
        player?.executeCommand(["sub-add", path, action])
    }

    /// 移除外部字幕
    public func removeExternal(path: String) {
        player?.executeCommand(["sub-remove", path])
    }
}

// MARK: - Track API

/// 轨道类型
public enum TrackType {
    case audio
    case subtitle
    case video
}

/// 轨道信息基类
public class TrackInfo {
    public let id: Int64
    public let title: String?
    public let lang: String?
    public let type: TrackType

    public var displayName: String {
        title ?? lang ?? "\(type) \(id)"
    }

    init(id: Int64, title: String?, lang: String?, type: TrackType) {
        self.id = id
        self.title = title
        self.lang = lang
        self.type = type
    }
}

/// 音频轨道
public class AudioTrack: TrackInfo {
    public init(id: Int64, title: String?, lang: String?) {
        super.init(id: id, title: title, lang: lang, type: .audio)
    }
}

/// 字幕轨道
public class SubtitleTrack: TrackInfo {
    public init(id: Int64, title: String?, lang: String?) {
        super.init(id: id, title: title, lang: lang, type: .subtitle)
    }
}

/// 视频轨道
public class VideoTrack: TrackInfo {
    public init(id: Int64, title: String?, lang: String?) {
        super.init(id: id, title: title, lang: lang, type: .video)
    }
}

public class TrackAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 所有轨道
    public var allTracks: [TrackInfo] {
        var tracks: [TrackInfo] = []
        var index = 0
        while true {
            guard let typeStr = player?.getPropertyString(.trackType(index)), !typeStr.isEmpty else {
                break
            }

            let id = player?.getPropertyInt64(.trackId(index)) ?? 0
            let title = player?.getPropertyString(.trackTitle(index))
            let lang = player?.getPropertyString(.trackLang(index))

            switch typeStr {
            case "audio":
                tracks.append(AudioTrack(id: id, title: title, lang: lang))
            case "sub":
                tracks.append(SubtitleTrack(id: id, title: title, lang: lang))
            case "video":
                tracks.append(VideoTrack(id: id, title: title, lang: lang))
            default:
                break
            }

            index += 1
        }
        return tracks
    }

    /// 音频轨道
    public var audioTracks: [AudioTrack] {
        allTracks.compactMap { $0 as? AudioTrack }
    }

    /// 字幕轨道
    public var subtitleTracks: [SubtitleTrack] {
        allTracks.compactMap { $0 as? SubtitleTrack }
    }

    /// 视频轨道
    public var videoTracks: [VideoTrack] {
        allTracks.compactMap { $0 as? VideoTrack }
    }
}

// MARK: - Screenshot API

public class ScreenshotAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 截图（包含字幕）
    public func capture() {
        player?.executeCommand(["screenshot"])
    }

    /// 截图（不包含字幕）
    public func captureWithoutSubtitle() {
        player?.executeCommand(["screenshot", "video"])
    }

    /// 截图（包含窗口元素，如 OSD）
    public func captureWithOSD() {
        player?.executeCommand(["screenshot", "window"])
    }

    /// 保存截图到指定文件
    public func saveToFile(path: String, format: String = "png") {
        player?.executeCommand(["screenshot-to-file", path, format])
    }
}

// MARK: - 颜色扩展

#if os(iOS)
extension UIColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(red: r, green: g, blue: b, alpha: 1.0)
    }
}
#elseif os(macOS)
extension NSColor {
    convenience init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)

        let r = CGFloat((rgb & 0xFF0000) >> 16) / 255.0
        let g = CGFloat((rgb & 0x00FF00) >> 8) / 255.0
        let b = CGFloat(rgb & 0x0000FF) / 255.0

        self.init(srgbRed: r, green: g, blue: b, alpha: 1.0)
    }
}
#endif
