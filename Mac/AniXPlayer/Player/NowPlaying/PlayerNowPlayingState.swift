//
//  PlayerNowPlayingState.swift
//  AniXPlayer
//
//  macOS：顶栏「正在播放」卡片与系统 Now Playing 共用的轻量状态。
//  这里只放纯数据与节流逻辑，便于单元测试，不依赖播放器或 AppKit。
//

import Foundation

/// 当前播放媒体在顶栏与系统 Now Playing 中展示所需的快照。
struct PlayerNowPlayingState: Equatable {

    /// 主标题；空字符串表示没有正在播放的媒体。
    var title: String
    /// 副标题（剧集名/文件名）。
    var subtitle: String
    /// 封面地址；没有封面时为 nil。
    var artworkURL: URL?
    /// 总时长（秒）。
    var duration: TimeInterval
    /// 当前播放位置（秒）。
    var position: TimeInterval
    /// 是否正在播放。
    var isPlaying: Bool
    /// 是否存在可切换的下一项。
    var canGoNext: Bool
    /// 是否存在可切换的上一项。
    var canGoPrevious: Bool

    static let empty = PlayerNowPlayingState(
        title: "",
        subtitle: "",
        artworkURL: nil,
        duration: 0,
        position: 0,
        isPlaying: false,
        canGoNext: false,
        canGoPrevious: false
    )

    var hasMedia: Bool {
        return !title.isEmpty
    }

    /// 播放进度（0...1）；未知时长时为 0，避免卡片出现随机长度。
    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(max(position / duration, 0), 1)
    }
}

/// 播放时间上报节流：最多每秒推送一次；明显的进度跳变（拖动/跳转）立即推送。
struct PlayerNowPlayingTimeThrottle {

    let interval: TimeInterval
    let seekThreshold: TimeInterval

    private(set) var lastPublishedAt: TimeInterval?
    private(set) var lastPosition: TimeInterval = 0

    init(interval: TimeInterval = 1, seekThreshold: TimeInterval = 2) {
        self.interval = interval
        self.seekThreshold = seekThreshold
    }

    mutating func shouldPublish(position: TimeInterval, now: TimeInterval) -> Bool {
        guard let lastPublishedAt = lastPublishedAt else {
            self.lastPublishedAt = now
            self.lastPosition = position
            return true
        }

        let isSeek = abs(position - lastPosition) >= seekThreshold
        guard isSeek || now - lastPublishedAt >= interval else { return false }

        self.lastPublishedAt = now
        self.lastPosition = position
        return true
    }

    mutating func reset() {
        lastPublishedAt = nil
        lastPosition = 0
    }
}
