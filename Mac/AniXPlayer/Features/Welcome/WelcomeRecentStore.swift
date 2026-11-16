//
//  WelcomeRecentStore.swift
//  AniXPlayer
//
//  macOS：欢迎页“继续播放”的本地最近播放存储。
//  只保存本地文件；使用 security-scoped bookmark，沙盒重启后仍可打开。
//

import Foundation
import UniformTypeIdentifiers

extension Notification.Name {
    static let welcomeRecentPlaybackDidChange = Notification.Name("WelcomeRecentPlaybackDidChange")
}

/// 轻量的最近播放存储（UserDefaults + JSON，不引入数据库）。
final class WelcomeRecentStore {

    static let shared = WelcomeRecentStore()

    private let defaultsKey = "AniXPlayer.Welcome.RecentPlaybacks"
    private let maximumCount = 10
    private var heldScopedPaths = Set<String>()

    private init() {}

    var items: [WelcomeRecentItem] {
        return loadItems()
    }

    func record(file: File, progress: Double? = nil, position: Double? = nil, duration: Double? = nil) {
        guard file is LocalFile else { return }
        guard file.url.isFileURL, file.type == .file else { return }
        guard !file.url.isSubtitleFile, !file.url.isDanmakuFile else { return }
        guard isPlayableMedia(file) else { return }

        // 解析软链后再去重：同一视频可能通过 worktree/sample 软链或真实路径打开。
        let url = file.url.resolvingSymlinksInPath().standardizedFileURL
        let path = url.path
        var currentItems = loadItems()
        let existing = currentItems.first(where: { $0.path == path })

        let bookmark = try? url.bookmarkData(
            options: .withSecurityScope,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        )

        let item = WelcomeRecentItem(
            path: path,
            lastOpened: Date().timeIntervalSince1970,
            progress: progress ?? existing?.progress,
            bookmark: bookmark ?? existing?.bookmark,
            position: position ?? existing?.position,
            duration: duration ?? existing?.duration
        )

        currentItems.removeAll(where: { $0.path == path })
        currentItems.insert(item, at: 0)
        if currentItems.count > maximumCount {
            currentItems = Array(currentItems.prefix(maximumCount))
        }

        persist(currentItems)
        NotificationCenter.default.post(name: .welcomeRecentPlaybackDidChange, object: nil)
    }

    func remove(path: String) {
        var currentItems = loadItems()
        currentItems.removeAll(where: { $0.path == path })
        persist(currentItems)
        NotificationCenter.default.post(name: .welcomeRecentPlaybackDidChange, object: nil)
    }

    func clear() {
        UserDefaults.standard.removeObject(forKey: defaultsKey)
        NotificationCenter.default.post(name: .welcomeRecentPlaybackDidChange, object: nil)
    }

    func resolveURL(for item: WelcomeRecentItem) -> URL? {
        var resolvedURL: URL?

        if let bookmark = item.bookmark {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: bookmark,
                options: .withSecurityScope,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                resolvedURL = url
                holdSecurityScope(for: url)
            }
        }

        if resolvedURL == nil {
            let url = URL(fileURLWithPath: item.path)
            if FileManager.default.fileExists(atPath: url.path) {
                resolvedURL = url
            }
        }

        guard let url = resolvedURL,
              FileManager.default.fileExists(atPath: url.path) else {
            return nil
        }
        return url
    }

    private func holdSecurityScope(for url: URL) {
        let path = url.path
        guard !heldScopedPaths.contains(path) else { return }
        if url.startAccessingSecurityScopedResource() {
            heldScopedPaths.insert(path)
        }
    }

    private func isPlayableMedia(_ file: File) -> Bool {
        return Self.isPlayablePath(file.url.path)
    }

    private static func isPlayablePath(_ path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        if ext == "mkv" {
            return true
        }
        guard let type = UTType(filenameExtension: ext) else { return false }
        return type.conforms(to: .audiovisualContent)
    }

    private func loadItems() -> [WelcomeRecentItem] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let items = try? JSONDecoder().decode([WelcomeRecentItem].self, from: data) else {
            return []
        }
        var seen = Set<String>()
        return items
            .filter { Self.isPlayablePath($0.path) }
            .sorted { $0.lastOpened > $1.lastOpened }
            .filter { item in
                let resolved = URL(fileURLWithPath: item.path)
                    .resolvingSymlinksInPath()
                    .standardizedFileURL
                    .path
                return seen.insert(resolved).inserted
            }
    }

    private func persist(_ items: [WelcomeRecentItem]) {
        guard let data = try? JSONEncoder().encode(items) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }
}
