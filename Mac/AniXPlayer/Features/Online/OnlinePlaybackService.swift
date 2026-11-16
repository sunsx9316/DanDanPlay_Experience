//
//  OnlinePlaybackService.swift
//  AniXPlayer
//
//  macOS：在线观看的搜索编排与播放准备。
//

import Foundation

final class OnlinePlaybackService {

    static let shared = OnlinePlaybackService()

    private let resolver = OnlineMediaResolver.shared
    private let store = OnlineSourceStore.shared

    private init() {}

    // MARK: - Sources

    func loadSources(forceRefresh: Bool = false, progress: ((String) -> Void)? = nil) async throws -> [OnlineMediaSource] {
        let result = try await store.loadSources(forceRefresh: forceRefresh, progress: progress)
        return result.sources
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

        var failures: [String: String] = [:]
        var subjects: [OnlineSubject] = []
        var seen = Set<String>()

        for result in results.sorted(by: { lhs, rhs in
            if lhs.source.tier != rhs.source.tier {
                return lhs.source.tier < rhs.source.tier
            }
            if lhs.source.name != rhs.source.name {
                return lhs.source.name.localizedStandardCompare(rhs.source.name) == .orderedAscending
            }
            return false
        }) {
            if let error = result.error {
                failures[result.source.name] = error.localizedDescription
                continue
            }
            for subject in result.subjects {
                guard seen.insert(subject.url.absoluteString).inserted else { continue }
                subjects.append(subject)
            }
        }

        return OnlineSearchOutcome(
            subjects: Array(subjects.prefix(200)),
            failures: failures,
            sourceCount: usable.count
        )
    }

    // MARK: - Episodes

    func loadEpisodes(source: OnlineMediaSource, subject: OnlineSubject) async throws -> [OnlineEpisode] {
        return try await resolver.loadEpisodes(source: source, subject: subject)
    }

    // MARK: - Playback

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
                    sort: episode.sort
                )
                let match = try await resolveMedia(source: source, episode: candidate, progress: progress)
                progress?(NSLocalizedString("正在验证视频源…", comment: ""))
                try await validateStream(match)
                resolvedMatch = match
                break
            } catch {
                lastError = error
            }
        }

        guard let match = resolvedMatch else {
            throw lastError ?? OnlinePlaybackError.videoNotFound(episode.url)
        }

        let displayName = "\(subject.title) \(episode.title)"
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return OnlineEpisodeFile(
            streamURL: match.url,
            displayName: displayName.isEmpty ? episode.title : displayName,
            headers: match.headers,
            pageURL: episode.url,
            sourceName: source.name
        )
    }

    /// 播放前做一次 Range 探测，避免把 401/403 的防盗链地址交给播放器后黑屏。
    private func validateStream(_ match: OnlineMediaMatch) async throws {
        var request = URLRequest(url: match.url)
        request.httpMethod = "GET"
        request.timeoutInterval = 12
        request.setValue("bytes=0-1023", forHTTPHeaderField: "Range")
        for (key, value) in match.headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return }
            if http.statusCode == 401 || http.statusCode == 403 {
                throw OnlinePlaybackError.streamUnavailable(http.statusCode, match.url)
            }
            guard (200..<400).contains(http.statusCode) else {
                throw OnlinePlaybackError.streamUnavailable(http.statusCode, match.url)
            }
        } catch let error as OnlinePlaybackError {
            throw error
        } catch {
            throw OnlinePlaybackError.streamUnavailable(-1, match.url)
        }
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
