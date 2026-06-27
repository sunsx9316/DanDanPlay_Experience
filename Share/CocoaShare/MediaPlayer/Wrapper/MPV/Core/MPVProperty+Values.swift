//
//  MPVProperty+Values.swift
//  CocoaShare
//
//  MPV.Property 类型安全的属性定义扩展
//

import Foundation

// MARK: - Bool 属性

extension MPV.Property where ValueType == Bool {
    public static let pause = Self("pause")
    public static let mute = Self("mute")
    public static let fullscreen = Self("fullscreen")
    public static let subtitleUseMargins = Self("sub-use-margins")
    public static let audioExclusive = Self("audio-exclusive")
    public static let endOfReached = Self("eof-reached")
}

// MARK: - Int64 属性

extension MPV.Property where ValueType == Int64 {
    public static let cache = Self("cache")
    public static let volume = Self("volume")
    public static let audioId = Self("aid")
    public static let videoId = Self("vid")
    public static let windowId = Self("wid")
    public static let subtitleId = Self("sid")
    public static let secondarySubtitleId = Self("secondary-sid")
    public static let subtitleYPosition = Self("sub-margin")
    public static let subtitleMarginY = Self("sub-margin-y")
    public static let subtitlePos = Self("sub-pos")
    public static let subtitleFontSize = Self("sub-font-size")

    public static func trackId(_ n: Int) -> MPV.Property<Int64> {
        Self("track-list/\(n)/id")
    }
}

// MARK: - Double 属性

extension MPV.Property where ValueType == Double {
    public static let playbackTime = Self("playback-time")
    public static let speed = Self("speed")
    public static let timePos = Self("time-pos")
    public static let timeStart = Self("time-start")
    public static let duration = Self("duration")
    public static let remaining = Self("remaining")
    public static let audioDelay = Self("audio-delay")
    public static let videoAspect = Self("video-aspect-override")
    public static let subtitleDelay = Self("sub-delay")
    public static let estimatedVFps = Self("estimated-vf-fps")
}

// MARK: - String 属性

extension MPV.Property where ValueType == String {
    public static let audioDevice = Self("audio-device")
    public static let audioSpdif = Self("audio-spdif")
    public static let audioChannels = Self("audio-channels")
    public static let hwdec = Self("hwdec")
    public static let subtitleColor = Self("sub-color")
    public static let subtitleBackColor = Self("sub-back-color")
    public static let subtitleFont = Self("sub-font")
    public static let subtitleFontsDir = Self("sub-fonts-dir")
    public static let subtitleAss = Self("sub-ass")
    public static let subtitleAssOverride = Self("sub-ass-override")
    public static let subtitleAuto = Self("sub-auto")
    public static let vo = Self("vo")
    public static let gpuApi = Self("gpu-api")
    public static let gpuContext = Self("gpu-context")

    public static func trackType(_ n: Int) -> MPV.Property<String> {
        Self("track-list/\(n)/type")
    }
    public static func trackTitle(_ n: Int) -> MPV.Property<String> {
        Self("track-list/\(n)/title")
    }
    public static func trackLang(_ n: Int) -> MPV.Property<String> {
        Self("track-list/\(n)/lang")
    }
}

// MARK: - ObservableOnly 属性（仅用于 observe，不可 get/set）

extension MPV.Property where ValueType == MPV.ObservableOnly {
    public static let trackList = Self("track-list")
    public static let protocolList = Self("protocol-list")
    public static let screenshotMode = Self("screenshot-mode")
}
