//
//  PlayerNowPlayingCenter.swift
//  AniXPlayer
//
//  macOS：正在播放状态中心。
//  PlayerViewController 上报媒体/播放/时间变化，顶栏卡片与系统 Now Playing 通过通知观察；
//  顶栏不持有播放器，播放器关闭后清空系统媒体信息。
//

import Cocoa
import MediaPlayer
@preconcurrency import Kingfisher
import ANXLog

extension Notification.Name {
    /// 正在播放状态发生变化；通知在主线程发送。
    static let playerNowPlayingDidChange = Notification.Name("AniXPlayer.PlayerNowPlayingDidChange")
}

final class PlayerNowPlayingCenter {

    /// 播放器注册的远程控制动作；全部以 weak 方式回指播放器。
    struct Actions {
        var play: () -> Void
        var pause: () -> Void
        var togglePlay: () -> Void
        var seek: (Double) -> Void
        var next: (() -> Void)?
        var previous: (() -> Void)?
        var focus: () -> Void
    }

    static let shared = PlayerNowPlayingCenter()

    private(set) var state = PlayerNowPlayingState.empty

    private var actions: Actions?
    private weak var actionOwner: AnyObject?

    private var timeThrottle = PlayerNowPlayingTimeThrottle()
    private var artwork: NSImage?
    private var artworkToken = UUID()

    private let infoCenter = MPNowPlayingInfoCenter.default()
    private let commandCenter = MPRemoteCommandCenter.shared()

    private init() {
        configureRemoteCommands()
        updateRemoteCommandAvailability()
    }

    // MARK: - 播放器上报

    func activate(owner: AnyObject, actions: Actions) {
        onMain { [weak self] in
            guard let self = self else { return }
            self.actionOwner = owner
            self.actions = actions
            self.updateRemoteCommandAvailability()
        }
    }

    func deactivate(owner: AnyObject) {
        onMain { [weak self] in
            guard let self = self, self.actionOwner === owner else { return }
            self.actions = nil
            self.actionOwner = nil
            self.resetState()
        }
    }

    func updateMedia(
        title: String,
        subtitle: String,
        artworkURL: URL?,
        duration: TimeInterval,
        position: TimeInterval,
        isPlaying: Bool,
        canGoNext: Bool,
        canGoPrevious: Bool
    ) {
        onMain { [weak self] in
            guard let self = self else { return }

            let artworkChanged = self.state.artworkURL != artworkURL
            self.state = PlayerNowPlayingState(
                title: title,
                subtitle: subtitle,
                artworkURL: artworkURL,
                duration: max(duration, 0),
                position: max(position, 0),
                isPlaying: isPlaying,
                canGoNext: canGoNext,
                canGoPrevious: canGoPrevious
            )
            self.timeThrottle.reset()

            if artworkChanged {
                self.reloadArtwork(for: artworkURL)
            } else {
                self.refreshNowPlayingInfo()
            }

            self.notifyStateChanged()
            self.updateRemoteCommandAvailability()
        }
    }

    func updatePlayback(isPlaying: Bool) {
        onMain { [weak self] in
            guard let self = self, self.state.hasMedia else { return }
            guard self.state.isPlaying != isPlaying else { return }

            self.state.isPlaying = isPlaying
            self.refreshNowPlayingInfo()
            self.notifyStateChanged()
            self.updateRemoteCommandAvailability()
        }
    }

    func updateTime(position: TimeInterval, duration: TimeInterval) {
        onMain { [weak self] in
            guard let self = self, self.state.hasMedia else { return }

            // 时长从 0 变成真实值时即使节流也立即刷新，避免系统媒体面板一直显示未知时长。
            let durationChanged = abs(duration - self.state.duration) >= 0.5
            let now = ProcessInfo.processInfo.systemUptime
            let shouldPublish = self.timeThrottle.shouldPublish(position: position, now: now)
            guard durationChanged || shouldPublish else { return }

            self.state.position = max(position, 0)
            self.state.duration = max(duration, 0)
            self.refreshNowPlayingInfo()
            self.notifyStateChanged()
            // 时长从 0 变为真实值时，需要重新启用系统「拖动进度」命令。
            self.updateRemoteCommandAvailability()
        }
    }

    /// 播放器关闭时清空顶栏与系统 Now Playing，避免媒体键继续控制已关闭的播放器。
    func clear() {
        onMain { [weak self] in
            self?.resetState()
        }
    }

    private func resetState() {
        state = .empty
        timeThrottle.reset()
        artwork = nil
        artworkToken = UUID()

        infoCenter.nowPlayingInfo = nil
        infoCenter.playbackState = .stopped

        notifyStateChanged()
        updateRemoteCommandAvailability()
    }

    // MARK: - 顶栏动作

    func focusPlayer() {
        let action = actions?.focus
        onMain { action?() }
    }

    func togglePlayback() {
        let action = actions?.togglePlay
        onMain { action?() }
    }

    // MARK: - 系统 Now Playing

    private func configureRemoteCommands() {
        commandCenter.playCommand.removeTarget(nil)
        commandCenter.pauseCommand.removeTarget(nil)
        commandCenter.togglePlayPauseCommand.removeTarget(nil)
        commandCenter.changePlaybackPositionCommand.removeTarget(nil)
        commandCenter.nextTrackCommand.removeTarget(nil)
        commandCenter.previousTrackCommand.removeTarget(nil)

        commandCenter.playCommand.addTarget { [weak self] _ in
            guard let self = self, let action = self.actions?.play else { return .noSuchContent }
            self.onMain { action() }
            return .success
        }

        commandCenter.pauseCommand.addTarget { [weak self] _ in
            guard let self = self, let action = self.actions?.pause else { return .noSuchContent }
            self.onMain { action() }
            return .success
        }

        commandCenter.togglePlayPauseCommand.addTarget { [weak self] _ in
            guard let self = self, let action = self.actions?.togglePlay else { return .noSuchContent }
            self.onMain { action() }
            return .success
        }

        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self = self,
                  let action = self.actions?.seek,
                  let event = event as? MPChangePlaybackPositionCommandEvent,
                  self.state.duration > 0 else {
                return .noSuchContent
            }
            let progress = min(max(event.positionTime / self.state.duration, 0), 1)
            self.onMain { action(progress) }
            return .success
        }

        commandCenter.nextTrackCommand.addTarget { [weak self] _ in
            guard let self = self, let action = self.actions?.next else { return .noSuchContent }
            self.onMain { action() }
            return .success
        }

        commandCenter.previousTrackCommand.addTarget { [weak self] _ in
            guard let self = self, let action = self.actions?.previous else { return .noSuchContent }
            self.onMain { action() }
            return .success
        }
    }

    private func updateRemoteCommandAvailability() {
        let hasMedia = state.hasMedia && actions != nil

        commandCenter.playCommand.isEnabled = hasMedia
        commandCenter.pauseCommand.isEnabled = hasMedia
        commandCenter.togglePlayPauseCommand.isEnabled = hasMedia
        commandCenter.changePlaybackPositionCommand.isEnabled = hasMedia && state.duration > 0
        commandCenter.nextTrackCommand.isEnabled = hasMedia && state.canGoNext && actions?.next != nil
        commandCenter.previousTrackCommand.isEnabled = hasMedia && state.canGoPrevious && actions?.previous != nil
    }

    private func refreshNowPlayingInfo() {
        guard state.hasMedia else {
            infoCenter.nowPlayingInfo = nil
            infoCenter.playbackState = .stopped
            return
        }

        var info: [String: Any] = [
            MPMediaItemPropertyTitle: state.title,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: max(state.position, 0),
            MPNowPlayingInfoPropertyPlaybackRate: state.isPlaying ? 1.0 : 0.0,
        ]

        if !state.subtitle.isEmpty {
            info[MPMediaItemPropertyArtist] = state.subtitle
        }
        if state.duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = state.duration
        }
        if let artwork = artwork {
            info[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in
                return artwork
            }
        }

        infoCenter.nowPlayingInfo = info
        infoCenter.playbackState = state.isPlaying ? .playing : .paused
    }

    private func reloadArtwork(for url: URL?) {
        let token = UUID()
        artworkToken = token
        artwork = nil

        guard let url = url else {
            refreshNowPlayingInfo()
            return
        }

        if url.isFileURL {
            artwork = NSImage(contentsOf: url)
            refreshNowPlayingInfo()
            return
        }

        KingfisherManager.shared.retrieveImage(with: url) { result in
            guard case .success(let value) = result else { return }
            let image = value.image
            DispatchQueue.main.async {
                PlayerNowPlayingCenter.shared.applyArtwork(image, token: token)
            }
        }
    }

    private func applyArtwork(_ image: NSImage, token: UUID) {
        guard artworkToken == token else { return }
        artwork = image
        refreshNowPlayingInfo()
    }

    // MARK: - Helpers

    private func notifyStateChanged() {
        NotificationCenter.default.post(name: .playerNowPlayingDidChange, object: self)
    }

    private func onMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block)
        }
    }
}
