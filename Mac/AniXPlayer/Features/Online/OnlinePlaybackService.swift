//
//  OnlinePlaybackService.swift
//  AniXPlayer
//
//  macOS：在线观看的搜索编排与播放准备。
//

import ANXLog
import Foundation

final class OnlinePlaybackService {

    static let shared = OnlinePlaybackService()

    private let resolver = OnlineMediaResolver.shared
    private let store = OnlineSourceStore.shared

    private init() {}

    // MARK: - Sources

    func loadSources(forceRefresh: Bool = false, progress: ((String) -> Void)? = nil) async throws -> [OnlineMediaSource] {
        let result = try await loadSourceResult(forceRefresh: forceRefresh, progress: progress)
        return result.sources
    }

    func loadSourceResult(
        forceRefresh: Bool = false,
        progress: ((String) -> Void)? = nil
    ) async throws -> OnlineSourceLoadResult {
        return try await store.loadSources(forceRefresh: forceRefresh, progress: progress)
    }

    func enabledSources(from sources: [OnlineMediaSource], engine: OnlineSourceEngine? = nil) -> [OnlineMediaSource] {
        return sources.filter { source in
            if let engine, source.engine != engine {
                return false
            }
            return OnlineSourcePreferences.isSourceEnabled(source.id)
        }
    }

    // MARK: - Search

    private struct SourceSearchResult {
        let source: OnlineMediaSource
        let subjects: [OnlineSubject]
        let error: Error?
    }

    func search(
        keyword: String,
        sources: [OnlineMediaSource],
        engine: OnlineSourceEngine? = nil,
        onSourceFinished: ((Int, Int) -> Void)? = nil
    ) async throws -> OnlineSearchOutcome {
        let usable = enabledSources(from: sources, engine: engine)
        guard !usable.isEmpty else {
            throw OnlinePlaybackError.noSources
        }

        let value = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else {
            return OnlineSearchOutcome(subjects: [], failures: [:], sourceCount: usable.count)
        }

        let results: [SourceSearchResult] = await withTaskGroup(of: SourceSearchResult.self) { group in
            for source in usable {
                group.addTask { [resolver] in
                    do {
                        let subjects = try await resolver.search(source: source, keyword: value)
                        return SourceSearchResult(source: source, subjects: subjects, error: nil)
                    } catch {
                        return SourceSearchResult(source: source, subjects: [], error: error)
                    }
                }
            }

            var collected: [SourceSearchResult] = []
            var finished = 0
            for await result in group {
                finished += 1
                collected.append(result)
                onSourceFinished?(finished, usable.count)
            }
            return collected
        }

        let pinnedSourceIDs = Set(OnlineSourcePreferences.pinnedSourceIDs)
        let merged = results.map {
            OnlineSearchSourceResult(
                source: $0.source,
                subjects: $0.subjects,
                error: $0.error
            )
        }
        return OnlineSearchMerger.makeOutcome(
            results: merged,
            sourceCount: usable.count,
            pinnedSourceIDs: pinnedSourceIDs
        )
    }

    // MARK: - Episodes

    func loadEpisodes(source: OnlineMediaSource, subject: OnlineSubject) async throws -> [OnlineEpisode] {
        return try await resolver.loadEpisodes(source: source, subject: subject)
    }

    // MARK: - Playback

    /// 连续播放预取的后续集数（不含当前集）。
    static let continuousLookahead = 2

    /// 预取结果：当前集 + 已解析的后续集。
    struct OnlinePlaylistPreparation {
        let files: [OnlineEpisodeFile]
        /// 因解析失败被跳过的后续集数。
        let skippedCount: Int
        /// 已尝试过的最后一集下标，供播放器继续向后追加。
        let lastScannedIndex: Int
    }

    /// 解析当前集以及后续 1...lookahead 集。
    ///
    /// - 当前集失败会抛错（由调用方提示）。
    /// - 后续集失败会跳过并继续更后面的剧集，不伪造地址。
    /// - 只有 `lookahead > 0` 时才会启用播放中的继续追加。
    func preparePlaylist(
        source: OnlineMediaSource,
        subject: OnlineSubject,
        episodes: [OnlineEpisode],
        startIndex: Int,
        lookahead: Int,
        progress: ((String) -> Void)? = nil
    ) async throws -> OnlinePlaylistPreparation {
        guard startIndex >= 0, startIndex < episodes.count else {
            throw OnlinePlaybackError.unsupportedRule(
                NSLocalizedString("没有可播放的剧集。", comment: "")
            )
        }

        await OnlinePlaybackSession.shared.end()

        let currentFile = try await preparePlayback(
            source: source,
            subject: subject,
            episode: episodes[startIndex],
            progress: progress
        )

        var files = [currentFile]
        var skipped = 0
        var lastScanned = startIndex
        let additional = max(0, min(lookahead, 3))
        var index = startIndex + 1
        // 跳过失败剧集也要有上限，避免首次播放被整季失败拖住。
        var scanBudget = additional + 3

        while additional > 0,
              files.count <= additional,
              index < episodes.count,
              scanBudget > 0 {
            try Task.checkCancellation()
            scanBudget -= 1
            let episode = episodes[index]
            progress?(String(
                format: NSLocalizedString("正在准备连续播放 %d/%d：%@", comment: ""),
                files.count + 1,
                additional + 1,
                episode.title
            ))
            do {
                let file = try await preparePlayback(
                    source: source,
                    subject: subject,
                    episode: episode,
                    progress: nil
                )
                files.append(file)
            } catch {
                skipped += 1
                ANX.logInfo(.player, "[Online] 跳过无法解析的后续剧集：\(episode.title) \(error.localizedDescription)")
            }
            lastScanned = index
            index += 1
        }

        if additional > 0 {
            try Task.checkCancellation()
            await OnlinePlaybackSession.shared.begin(
                source: source,
                subject: subject,
                episodes: episodes,
                lastScannedIndex: lastScanned
            )
        }

        return OnlinePlaylistPreparation(
            files: files,
            skippedCount: skipped,
            lastScannedIndex: lastScanned
        )
    }

    func preparePlayback(
        source: OnlineMediaSource,
        subject: OnlineSubject,
        episode: OnlineEpisode,
        progress: ((String) -> Void)? = nil
    ) async throws -> OnlineEpisodeFile {
        let pageURLs = [episode.url] + episode.alternateURLs
        var lastError: Error?
        var resolvedMatch: OnlineMediaMatch?

        for (index, pageURL) in pageURLs.enumerated() {
            if index > 0 {
                progress?(String(
                    format: NSLocalizedString("主线路不可用，正在尝试备用线路 %d/%d…", comment: ""),
                    index + 1,
                    pageURLs.count
                ))
            }
            do {
                let candidate = OnlineEpisode(
                    title: episode.title,
                    url: pageURL,
                    sort: episode.sort,
                    roadName: episode.roadName
                )
                let match = try await resolveMedia(source: source, episode: candidate, progress: progress)
                progress?(NSLocalizedString("正在验证视频源…", comment: ""))
                try await validateStream(url: match.url, headers: match.headers)
                resolvedMatch = match
                break
            } catch {
                lastError = error
            }
        }

        guard let match = resolvedMatch else {
            throw lastError ?? OnlinePlaybackError.videoNotFound(episode.url)
        }

        let displayName = OnlineDanmakuMatchQuery.keyword(
            subjectTitle: subject.title,
            episodeTitle: episode.title
        )
        return OnlineEpisodeFile(
            streamURL: match.url,
            displayName: displayName.isEmpty ? episode.title : displayName,
            headers: match.headers,
            pageURL: episode.url,
            sourceName: source.name
        )
    }

    /// 播放前做一次 Range 探测，避免把 401/403 的防盗链地址交给播放器后黑屏。
    /// 独立「媒体嗅探」窗口也复用此验证。
    func validateStream(url: URL, headers: [String: String]) async throws {
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw OnlinePlaybackError.streamUnavailable(http.statusCode, url)
            }
            guard (200..<400).contains(http.statusCode) else {
                throw OnlinePlaybackError.streamUnavailable(http.statusCode, url)
            }
        } catch let error as OnlinePlaybackError {
            throw error
        } catch {
            throw OnlinePlaybackError.streamUnavailable(-1, url)
        }
    }

    /// 嗅探窗口默认请求头：UA + 页面同源 Referer。
    static func defaultStreamHeaders(pageURL: URL) -> [String: String] {
        var headers: [String: String] = [
            "User-Agent": OnlineHTTPClient.defaultUserAgent
        ]
        if let scheme = pageURL.scheme, let host = pageURL.host {
            headers["Referer"] = "\(scheme)://\(host)/"
        }
        return headers
    }

    /// 先走 HTTP + 规则解析（快）；失败后再用 WKWebView 嗅探动态播放页。
    private func resolveMedia(
        source: OnlineMediaSource,
        episode: OnlineEpisode,
        progress: ((String) -> Void)?
    ) async throws -> OnlineMediaMatch {
        do {
            progress?(NSLocalizedString("正在解析视频地址…", comment: ""))
            return try await resolver.resolveMedia(source: source, episode: episode)
        } catch {
            progress?(NSLocalizedString("正在嗅探动态播放页…", comment: ""))
            if let match = await OnlineStreamSniffer.shared.sniff(
                pageURL: episode.url,
                source: source
            ) {
                return match
            }
            throw error
        }
    }
}
