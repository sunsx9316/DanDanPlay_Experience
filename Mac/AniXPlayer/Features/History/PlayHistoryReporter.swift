//
//  PlayHistoryReporter.swift
//  AniXPlayer
//
//  macOS：播放 30 秒后上报服务端播放历史；只上报一次，失败退避重试。
//

import Foundation

@MainActor
final class PlayHistoryReporter {
    static let threshold: TimeInterval = 30
    private static let retryInterval: TimeInterval = 60

    private var reportedEpisodeIds = Set<Int>()
    private var lastAttempt: [Int: Date] = [:]
    private var inFlightEpisodeIds = Set<Int>()

    func reset() {
        reportedEpisodeIds.removeAll()
        lastAttempt.removeAll()
        inFlightEpisodeIds.removeAll()
    }

    func reportIfNeeded(episodeId: Int, currentTime: TimeInterval) {
        guard episodeId > 0, currentTime >= Self.threshold else { return }
        guard !reportedEpisodeIds.contains(episodeId), !inFlightEpisodeIds.contains(episodeId) else { return }
        if let last = lastAttempt[episodeId], Date().timeIntervalSince(last) < Self.retryInterval {
            return
        }

        inFlightEpisodeIds.insert(episodeId)
        lastAttempt[episodeId] = Date()

        Task { @MainActor [weak self] in
            guard let self else { return }
            let isLoggedIn = await SessionStore.shared.isLoggedIn()
            guard isLoggedIn else {
                self.inFlightEpisodeIds.remove(episodeId)
                return
            }

            do {
                try await PlayHistoryNetworkHandle.report(episodeId: episodeId)
                self.reportedEpisodeIds.insert(episodeId)
            } catch {
                // 失败保留 lastAttempt，下一次 60 秒后再试。
            }
            self.inFlightEpisodeIds.remove(episodeId)
        }
    }
}
