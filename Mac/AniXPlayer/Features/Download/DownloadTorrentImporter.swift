//
//  DownloadTorrentImporter.swift
//  AniXPlayer
//
//  macOS：把系统交给 App 的 .torrent 文件安全复制到 App 自己的目录，
//  避免沙盒临时授权在添加 sheet 关闭后失效。
//

import CryptoKit
import Foundation

enum DownloadTorrentImportError: LocalizedError {
    case notTorrent(String)
    case unreadable(String)
    case writeFailed(String)

    var errorDescription: String? {
        switch self {
        case .notTorrent(let path):
            return String(format: NSLocalizedString("不是有效的种子文件：%@", comment: ""), path)
        case .unreadable(let path):
            return String(format: NSLocalizedString("无法读取种子文件：%@", comment: ""), path)
        case .writeFailed(let message):
            return String(format: NSLocalizedString("无法保存种子文件：%@", comment: ""), message)
        }
    }
}

enum DownloadTorrentImporter {

    static var importDirectory: URL {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? URL(fileURLWithPath: NSHomeDirectory())
            .appendingPathComponent("Library/Application Support", isDirectory: true)

        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("ImportedTorrents", isDirectory: true)
    }

    /// 从系统入口/Finder 拖入的种子复制到 App 目录，返回可长期引用的路径。
    static func importTorrent(at url: URL) throws -> String {
        guard url.isFileURL, url.pathExtension.lowercased() == "torrent" else {
            throw DownloadTorrentImportError.notTorrent(url.path)
        }

        let standardized = url.standardizedFileURL
        if standardized.path.hasPrefix(importDirectory.standardizedFileURL.path + "/") {
            return standardized.path
        }

        let accessed = standardized.startAccessingSecurityScopedResource()
        defer {
            if accessed {
                standardized.stopAccessingSecurityScopedResource()
            }
        }

        guard let data = try? Data(contentsOf: standardized), !data.isEmpty else {
            throw DownloadTorrentImportError.unreadable(standardized.path)
        }

        let digest = SHA256.hash(data: data)
            .map { String(format: "%02x", $0) }
            .joined()
        let baseName = DownloadFileName.sanitize(standardized.lastPathComponent)
        let folder = importDirectory.appendingPathComponent(
            String(digest.prefix(24)),
            isDirectory: true
        )
        let destination = folder.appendingPathComponent(baseName, isDirectory: false)

        if FileManager.default.fileExists(atPath: destination.path) {
            return destination.path
        }

        do {
            try FileManager.default.createDirectory(
                at: folder,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: 0o700]
            )
            try data.write(to: destination, options: .atomic)
            try? FileManager.default.setAttributes(
                [.posixPermissions: 0o600],
                ofItemAtPath: destination.path
            )
            return destination.path
        } catch {
            throw DownloadTorrentImportError.writeFailed(error.localizedDescription)
        }
    }

    static func isImportedTorrent(_ path: String) -> Bool {
        let directory = importDirectory.standardizedFileURL.path + "/"
        return URL(fileURLWithPath: path).standardizedFileURL.path.hasPrefix(directory)
    }

    static func removeImportedTorrent(_ path: String) {
        guard isImportedTorrent(path), FileManager.default.fileExists(atPath: path) else {
            return
        }
        try? FileManager.default.removeItem(atPath: path)

        let parent = URL(fileURLWithPath: path).deletingLastPathComponent()
        if parent.path != importDirectory.standardizedFileURL.path,
           let contents = try? FileManager.default.contentsOfDirectory(atPath: parent.path),
           contents.isEmpty {
            try? FileManager.default.removeItem(at: parent)
        }
    }

    /// 拖拽/剪贴板里可能是 `file:///...torrent` 或裸路径。
    static func torrentPath(from value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if let url = URL(string: trimmed), url.isFileURL {
            return url.pathExtension.lowercased() == "torrent" ? url.path : nil
        }
        if trimmed.lowercased().hasSuffix(".torrent"),
           FileManager.default.fileExists(atPath: trimmed) {
            return trimmed
        }
        return nil
    }
}
