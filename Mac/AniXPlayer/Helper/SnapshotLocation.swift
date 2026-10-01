//
//  SnapshotLocation.swift
//  AniXPlayer
//

import Foundation

/// 截图保存位置
///
/// 沙盒环境下，默认目录用「图片」文件夹权限（entitlement）；
/// 用户自选目录通过 security-scoped bookmark 持久化访问权限。
enum SnapshotLocation {

    /// 默认目录名
    static let defaultDirectoryName = "AniXPlayer"

    // MARK: - 目录

    /// 默认目录「图片/AniXPlayer」
    static var defaultDirectoryURL: URL {
        let pictures = FileManager.default.urls(for: .picturesDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Pictures")
        return pictures.appendingPathComponent(defaultDirectoryName)
    }

    /// 当前截图目录（展示用，不申请权限、不创建）
    static var currentDirectoryURL: URL {
        return resolvedBookmarkURL() ?? defaultDirectoryURL
    }

    /// 展示用路径（~ 缩写）
    static var displayPath: String {
        return (currentDirectoryURL.path as NSString).abbreviatingWithTildeInPath
    }

    // MARK: - 自定义目录

    /// 保存用户选择的目录（生成 security-scoped bookmark）
    static func saveBookmark(for url: URL) {
        let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                             includingResourceValuesForKeys: nil,
                                             relativeTo: nil)
        Preferences.shared.snapshotDirectoryBookmark = bookmark
    }

    /// 清除自定义目录（恢复默认）
    static func clearBookmark() {
        Preferences.shared.snapshotDirectoryBookmark = nil
    }

    // MARK: - 写入

    /// 解析可写目录并确保存在
    /// - Returns: 目录 URL 及是否需要在使用后 `stopAccessingSecurityScopedResource`
    static func resolveAccessibleDirectory() throws -> (url: URL, needsStopAccess: Bool) {
        var needsStopAccess = false
        let directory: URL

        if let url = resolvedBookmarkURL() {
            needsStopAccess = url.startAccessingSecurityScopedResource()
            directory = url
        } else {
            directory = defaultDirectoryURL
        }

        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return (directory, needsStopAccess)
    }

    // MARK: - Private

    private static func resolvedBookmarkURL() -> URL? {
        guard let data = Preferences.shared.snapshotDirectoryBookmark else { return nil }

        var isStale = false
        guard let url = try? URL(resolvingBookmarkData: data,
                                 options: .withSecurityScope,
                                 relativeTo: nil,
                                 bookmarkDataIsStale: &isStale) else {
            return nil
        }

        if isStale,
           let bookmark = try? url.bookmarkData(options: .withSecurityScope,
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil) {
            Preferences.shared.snapshotDirectoryBookmark = bookmark
        }

        return url
    }
}
