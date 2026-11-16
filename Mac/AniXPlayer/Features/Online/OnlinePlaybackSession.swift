//
//  OnlinePlaybackSession.swift
//  AniXPlayer
//
//  macOS：在线连续播放的队列状态。
//
//  在线页只预取当前集 + 后续 2 集；播放器切换媒体时通知本单例，
//  接近队尾时再解析并追加后续剧集，避免一次性解析整季。
//  解析失败的剧集直接跳过，不伪造地址；当前集失败仍由调用方提示。
//

import ANXLog
import Foundation

@MainActor
final class OnlinePlaybackSession {

    static let shared = OnlinePlaybackSession()

    private struct Context {
        let source: OnlineMediaSource
        let subject: OnlineSubject
        let episodes: [OnlineEpisode]
        /// 已尝试解析过的最后一集下标（包含失败后跳过的剧集）。
        var lastScannedIndex: Int
    }

    private var context: Context?
    private weak var player: PlayerViewController?
    private var appendTask: Task<Void, Never>?
    private var generation = UUID()

    private init() {}

    // MARK: - Lifecycle

    /// 一次在线播放开始时登记队列；`lastScannedIndex` 是已预取到的位置。
    func begin(
        source: OnlineMediaSource,
        subject: OnlineSubject,
        episodes: [OnlineEpisode],
        lastScannedIndex: Int
    ) {
        appendTask?.cancel()
        appendTask = nil
        generation = UUID()
        player = nil
        context = Context(
            source: source,
            subject: subject,
            episodes: episodes,
            lastScannedIndex: lastScannedIndex
        )
    }

    /// 结束/取消当前在线队列（切到本地文件或重新解析时调用）。
    func end() {
        appendTask?.cancel()
        appendTask = nil
        generation = UUID()
        context = nil
        player = nil
    }

    // MARK: - Playback hook

    /// 由 `PlayerViewController` 在媒体变化时调用。
    func playerDidChange(file: File?, player: PlayerViewController) {
        guard let file else { return }
        guard let onlineFile = file as? OnlineEpisodeFile else {
            // 播放器切到本地/其他媒体后，不再为旧在线队列追加。
            end()
            return
        }
        guard var current = context else { return }
        self.player = player

        guard let pageURL = onlineFile.pageURL,
              let index = current.episodes.firstIndex(where: { $0.url == pageURL }) else {
            return
        }

        // 距队尾不足 2 集时继续解析；appendTask 保证同一时间只有一批。
        if index >= current.lastScannedIndex - 2 {
            current.lastScannedIndex = max(current.lastScannedIndex, index)
            context = current
            startAppending()
        }
    }

    // MARK: - Append

    private func startAppending() {
        guard appendTask == nil,
              let context,
              context.lastScannedIndex + 1 < context.episodes.count,
              player != nil else {
            return
        }
        let generation = self.generation
        appendTask = Task { @MainActor [weak self] in
            await self?.appendMore(generation: generation)
        }
    }

    private func appendMore(generation: UUID) async {
        defer {
            if self.generation == generation {
                appendTask = nil
            }
        }

        // 每次最多补 2 集，扫描失败剧集也有上限。
        var added = 0
        var attempts = 0
        while added < 2, attempts < 6 {
            guard !Task.isCancelled else { return }
            attempts += 1
            guard self.generation == generation,
                  let context,
                  let player = self.player else {
                return
            }
            let nextIndex = context.lastScannedIndex + 1
            guard nextIndex < context.episodes.count else { return }

            let episode = context.episodes[nextIndex]
            do {
                let file = try await OnlinePlaybackService.shared.preparePlayback(
                    source: context.source,
                    subject: context.subject,
                    episode: episode,
                    progress: nil
                )
                guard self.generation == generation, self.player === player else { return }
                self.context?.lastScannedIndex = nextIndex
                player.appendFiles([file])
                added += 1
            } catch {
                guard self.generation == generation else { return }
                // 后续集失败：跳过并继续尝试更后面的剧集。
                self.context?.lastScannedIndex = nextIndex
                ANX.logInfo(
                    .player,
                    "[Online] 连续播放跳过剧集：\(episode.title) \(error.localizedDescription)"
                )
            }
        }
    }
}
