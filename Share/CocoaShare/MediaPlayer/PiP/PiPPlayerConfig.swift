//
//  PiPPlayerConfig.swift
//  CocoaShare
//
//  PiP 播放器通用配置，主播放器 → PiP 播放器同步用
//

import Foundation

class PiPPlayerConfig {

    // MARK: - 通用配置

    /// 播放速度
    var speed: Double = 1.0

    /// 字幕字体目录路径
    var subtitleFontsDir: String?

    /// 字幕字体名称
    var subtitleFont: String?

    /// 是否强制 ASS 样式
    var subtitleOverride: Bool = true

    /// 字幕延迟（秒），正值延后
    var subtitleDelay: Double = 0

    /// 字幕字体大小
    var subtitleFontSize: Float?

    /// 字幕颜色
    var subtitleColor: ANXColor?

    /// 字幕 Y 轴位置（0-100，0=底部 100=顶部）
    var subtitleYPosition: Float?

    /// 音量
    var volume: Int = 100

    // MARK: - 后端特有参数

    /// 起始播放位置（秒）
    var startPosition: Double = 0

    /// 是否以暂停状态启动
    var startPaused: Bool = false

    /// 当前字幕（内嵌轨道或外挂文件），nil = 无字幕
    var currentSubtitle: (any SubtitleProtocol)?

    /// 当前音频轨道，nil = 不改变
    var currentAudioChannel: (any AudioChannelProtocol)?

    /// 额外配置（例如 mpv: ["hwdec": "no"], vlc: ["hw-decoder": "disable"]）
    var extra: [String: Any] = [:]

    // MARK: - 工厂方法

    /// 从主播放器提取当前配置（含播放状态快照）
    static func extract(from player: MediaPlayerProtocol) -> PiPPlayerConfig {
        let config = PiPPlayerConfig()
        config.speed = player.speed
        config.subtitleOverride = player.subtitleStyle
        config.subtitleDelay = player.subtitleOffsetTime
        config.subtitleFontSize = player.fontSize
        config.subtitleYPosition = player.subtitleYPosition
        config.subtitleColor = player.fontColor
        config.volume = player.volume
        config.startPosition = player.currentTime
        config.startPaused = !player.isPlaying
        return config
    }
}
