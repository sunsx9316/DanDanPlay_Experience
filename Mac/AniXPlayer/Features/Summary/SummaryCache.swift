//
//  SummaryCache.swift
//  AniXPlayer
//
//  macOS only：AI 视频总结的本地缓存与文件 hash。
//

import Foundation
import CryptoKit

struct SummaryCacheEntry: Codable, Equatable {
    let response: SummaryVideoResponse
    let createdAt: Date
    let fileName: String?
    let videoTitle: String?
}

enum SummaryCacheError: LocalizedError {
    case invalidHash

    var errorDescription: String? {
        switch self {
        case .invalidHash:
            return NSLocalizedString("视频文件校验值无效，无法使用缓存", comment: "")
        }
    }
}

/// 缓存路径：`<Caches>/AniXPlayer/AISummary/<fileHash>.json`。
struct SummaryCache {
    static var defaultDirectoryURL: URL {
        let caches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return caches.appendingPathComponent("AniXPlayer/AISummary", isDirectory: true)
    }

    let directoryURL: URL
    private let fileManager: FileManager

    init(directoryURL: URL = SummaryCache.defaultDirectoryURL, fileManager: FileManager = .default) {
        self.directoryURL = directoryURL
        self.fileManager = fileManager
    }

    /// 只接受 16 进制字符串，避免 hash 被构造成路径穿越。
    static func sanitizedHash(_ hash: String) -> String? {
        let trimmed = hash.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 64 else { return nil }
        guard trimmed.range(of: "^[0-9A-Fa-f]+$", options: .regularExpression) != nil else { return nil }
        return trimmed
    }

    static func fileName(forHash hash: String) -> String? {
        guard let sanitized = sanitizedHash(hash) else { return nil }
        return sanitized.uppercased() + ".json"
    }

    func url(forHash hash: String) -> URL? {
        guard let fileName = Self.fileName(forHash: hash) else { return nil }
        return directoryURL.appendingPathComponent(fileName)
    }

    func load(hash: String) -> SummaryCacheEntry? {
        guard let url = url(forHash: hash),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return try? JSONDecoder().decode(SummaryCacheEntry.self, from: data)
    }

    @discardableResult
    func save(
        _ response: SummaryVideoResponse,
        hash: String,
        fileName: String? = nil,
        videoTitle: String? = nil,
        createdAt: Date = Date()
    ) throws -> URL {
        guard let url = url(forHash: hash) else {
            throw SummaryCacheError.invalidHash
        }

        let entry = SummaryCacheEntry(
            response: response,
            createdAt: createdAt,
            fileName: fileName,
            videoTitle: videoTitle
        )
        let data = try JSONEncoder().encode(entry)
        try fileManager.createDirectory(at: directoryURL, withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
        return url
    }
}

/// 计算视频前 16MB 的 MD5，与 Windows 客户端的 fileHash 口径一致。
enum SummaryFileHash {
    static let prefixByteCount = 16 * 1024 * 1024

    static func md5Prefix(of url: URL) -> String? {
        do {
            let handle = try FileHandle(forReadingFrom: url)
            defer { try? handle.close() }
            let data = try handle.read(upToCount: prefixByteCount) ?? Data()
            let digest = Insecure.MD5.hash(data: data)
            return digest.map { String(format: "%02X", $0) }.joined()
        } catch {
            return nil
        }
    }
}
