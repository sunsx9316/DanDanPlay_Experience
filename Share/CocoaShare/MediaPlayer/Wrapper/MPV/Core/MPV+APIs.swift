//
//  MPV+APIs.swift
//  CocoaShare
//
//  MPV 的模块化 API 外观类：Playback、Time、Audio、Video、Subtitle、Track
//

import Foundation
#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// MARK: - Playback API

public class PlaybackAPI {
    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 暂停/恢复播放
    public var isPaused: Bool {
        get { player?.getProperty(.pause) ?? false }
        set { player?.setProperty(.pause, newValue) }
    }

    /// 切换暂停状态
    public func togglePause() {
        player?.execute(.cycle, args: ["pause"])
    }

    /// 设置播放速度
    public func setSpeed(_ speed: Double) {
        player?.setProperty(.speed, speed)
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
        player?.getProperty(.timePos)
    }

    /// 媒体总时长（秒）
    public var duration: Double? {
        player?.getProperty(.duration)
    }

    /// 剩余播放时间（秒）
    public var remaining: Double? {
        player?.getProperty(.remaining)
    }

    /// 跳转到指定时间
    public func seek(to seconds: Double, absolute: Bool = true) {
        let type = absolute ? "absolute" : "relative"
        player?.execute(.seek, args: [String(seconds), type])
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
        get { player?.getProperty(.audioId) }
        set {
            if let id = newValue {
                player?.setProperty(.audioId, id)
            }
        }
    }

    /// 音量 (0-100)
    public var volume: Int64? {
        get { player?.getProperty(.volume) }
        set {
            if let vol = newValue {
                player?.setProperty(.volume, vol)
            }
        }
    }

    /// 静音状态
    public var isMuted: Bool {
        get { player?.getProperty(.mute) ?? false }
        set { player?.setProperty(.mute, newValue) }
    }

    /// 音频设备名称
    public var audioDevice: String? {
        player?.getProperty(.audioDevice)
    }

    /// 音频延迟（秒）
    public var delay: Double? {
        get { player?.getProperty(.audioDelay) }
        set {
            if let d = newValue {
                player?.setProperty(.audioDelay, d)
            }
        }
    }

    /// 切换静音状态
    public func toggleMute() {
        player?.execute(.cycle, args: ["mute"])
    }

    /// 增加音量
    public func addVolume(_ delta: Int64) {
        player?.execute(.add, args: ["volume", String(delta)])
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
        get { player?.getProperty(.videoId) }
        set {
            if let id = newValue {
                player?.setProperty(.videoId, id)
            }
        }
    }

    /// 宽高比 (nil = 自动, 0 = 自动, -1 = 禁用)
    public var aspectRatio: Double? {
        get { player?.getProperty(.videoAspect) }
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
        get { player?.getProperty(.fullscreen) ?? false }
        set { player?.setProperty(.fullscreen, newValue) }
    }

    /// 窗口 ID (用于嵌入)
    public var windowId: Int64? {
        get { player?.getProperty(.windowId) }
        set {
            if let id = newValue {
                player?.setProperty(.windowId, id)
            }
        }
    }

    /// 硬件解码模式
    public var hardwareDecoding: String? {
        get { player?.getProperty(.hwdec) }
        set { player?.setProperty(.hwdec, newValue ?? "no") }
    }
}

// MARK: - Subtitle API

public class SubtitleAPI {

    public enum AutoLoadMode: String {
        case no
        case exact //精确匹配 - 默认值)
        case fuzzy //模糊匹配
        case all //全部加载
    }

    public enum AssOverride: String {
        case no // 完全不覆盖。严格遵循字幕脚本（ASS/SSA）定义的样式进行渲染。
        case yes //     基础覆盖（默认值）。应用所有的 --sub-ass-* 样式覆盖选项。这可能会导致某些精细特效显示异常。
        case scale //缩放覆盖。类似于 yes，但额外应用 --sub-scale 属性进行缩放。
        case force // 强制全面覆盖。强制应用所有以 --sub-* 开头的通用字幕属性（如 sub-color, sub-font 等），会极大地破坏特效字幕的原始布局。
        case strip //    彻底剥离样式。将 ASS/SSA 字幕的所有标签和样式信息移除，直接作为纯文本渲染。
    }

    private weak var player: MPV?

    init(mpv: MPV) {
        self.player = mpv
    }

    /// 当前字幕轨道 ID
    public var subtitleId: Int64? {
        get { player?.getProperty(.subtitleId) }
        set {
            if let id = newValue {
                player?.setProperty(.subtitleId, id)
            }
        }
    }

    /// 副字幕轨道 ID
    public var secondarySubtitleId: Int64? {
        get { player?.getProperty(.secondarySubtitleId) }
        set {
            if let id = newValue {
                player?.setProperty(.secondarySubtitleId, id)
            }
        }
    }

    /// 字幕延迟（秒）
    public var delay: Double? {
        get { player?.getProperty(.subtitleDelay) }
        set {
            if let d = newValue {
                player?.setProperty(.subtitleDelay, d)
            }
        }
    }

    /// 字幕字体大小
    public var fontSize: Int64? {
        get { player?.getProperty(.subtitleFontSize) }
        set {
            if let size = newValue {
                player?.setProperty(.subtitleFontSize, size)
            }
        }
    }

    public var assOverride: AssOverride? {
        get {
            if let value = player?.getProperty(.subtitleAssOverride) {
                return AssOverride(rawValue: value)
            }
            return nil
        }

        set {
            if let value = newValue {
                player?.setProperty(.subtitleAssOverride, value.rawValue)
            }
        }
    }

    public var position: Int64 {
        get {
            player?.getProperty(.subtitlePos) ?? 0
        }

        set {
            player?.setProperty(.subtitlePos, newValue)
        }
    }

    public var marginY: Int64 {
        get {
            player?.getProperty(.subtitleMarginY) ?? 0
        }

        set {
            player?.setProperty(.subtitleMarginY, newValue)
        }
    }

    public var autoLoad: AutoLoadMode? {
        get {
            if let value = player?.getProperty(.subtitleAuto) {
                return AutoLoadMode(rawValue: value)
            }
            return nil
        }

        set {
            if let value = newValue {
                player?.setProperty(.subtitleAuto, value.rawValue)
            }
        }
    }


    /// 字幕颜色
    public var color: MPVColor? {
        get {
            guard let hex = player?.getProperty(.subtitleColor) else { return nil }
            return MPVColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setProperty(.subtitleColor, color.hexString)
            } else {
                player?.setProperty(.subtitleColor, "")
            }
        }
    }

    /// 字幕后景色
    public var backColor: MPVColor? {
        get {
            guard let hex = player?.getProperty(.subtitleBackColor) else { return nil }
            return MPVColor(hex: hex)
        }
        set {
            if let color = newValue {
                player?.setProperty(.subtitleBackColor, color.hexString + "80")
            } else {
                player?.setProperty(.subtitleBackColor, "")
            }
        }
    }

    /// 添加外部字幕文件
    public func addExternal(path: String, select: Bool = true) {
        let action = select ? "select" : "auto"
        player?.execute(.subAdd, args: [path, action])
    }

    /// 移除外部字幕
    public func removeExternal(path: String) {
        player?.execute(.subRemove, args: [path])
    }
}

// MARK: - Track 类型

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

// MARK: - Track API

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
            guard let typeStr = player?.getProperty(.trackType(index)), !typeStr.isEmpty else {
                break
            }

            let id = player?.getProperty(.trackId(index)) ?? 0
            let title = player?.getProperty(.trackTitle(index))
            let lang = player?.getProperty(.trackLang(index))

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
