//
//  LocalLibraryModels.swift
//  AniXPlayer
//
//  macOS：本地媒体库的数据模型与纯逻辑。
//  文件放在 Mac target；测试 target 直接编译本文件，不依赖 AppKit。
//

import Foundation

// MARK: - Folder

struct LocalLibraryFolder: Equatable {
    var id: Int64
    var path: String
    var bookmark: Data?
    var addedAt: Date

    var name: String {
        let last = (path as NSString).lastPathComponent
        return last.isEmpty ? path : last
    }

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }
}

// MARK: - File

struct LocalLibraryFile: Equatable {
    var id: Int64
    var folderId: Int64
    var path: String
    var fileName: String
    var fileSize: Int64
    var modifiedAt: Date
    var hash: String?
    var animeId: Int?
    var episodeId: Int?
    var animeTitle: String?
    var episodeTitle: String?
    var imageUrl: String?
    var type: String?
    var isMatched: Bool
    var isMissing: Bool
    var lastScannedAt: Date

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }

    var fileExtension: String {
        (path as NSString).pathExtension.uppercased()
    }

    var displayTitle: String {
        if isMatched, let animeTitle, !animeTitle.isEmpty {
            return animeTitle
        }
        return fileName
    }

    var displayEpisodeTitle: String {
        if isMatched, let episodeTitle, !episodeTitle.isEmpty {
            return episodeTitle
        }
        return fileExtension.isEmpty ? NSLocalizedString("视频文件", comment: "") : fileExtension
    }

    var displayImageURL: URL? {
        guard let imageUrl, !imageUrl.isEmpty, imageUrl != "Unknown" else { return nil }
        return URL(string: imageUrl)
    }

    var sizeText: String {
        LocalLibraryFormatting.fileSize(fileSize)
    }

    var matchStatusText: String {
        isMatched
            ? NSLocalizedString("已匹配", comment: "")
            : NSLocalizedString("未匹配", comment: "")
    }

    static func makeScanned(
        folderId: Int64,
        path: String,
        fileName: String,
        fileSize: Int64,
        modifiedAt: Date,
        hash: String?,
        existingId: Int64?,
        now: Date
    ) -> LocalLibraryFile {
        LocalLibraryFile(
            id: existingId ?? 0,
            folderId: folderId,
            path: path,
            fileName: fileName,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            hash: hash,
            animeId: nil,
            episodeId: nil,
            animeTitle: nil,
            episodeTitle: nil,
            imageUrl: nil,
            type: nil,
            isMatched: false,
            isMissing: false,
            lastScannedAt: now
        )
    }
}

// MARK: - Query

enum LocalLibraryFilter: String, CaseIterable {
    case all
    case matched
    case unmatched

    var displayName: String {
        switch self {
        case .all: return NSLocalizedString("全部", comment: "")
        case .matched: return NSLocalizedString("已匹配", comment: "")
        case .unmatched: return NSLocalizedString("未匹配", comment: "")
        }
    }
}

enum LocalLibrarySort: String, CaseIterable {
    case title
    case fileName
    case fileSize
    case path

    var displayName: String {
        switch self {
        case .title: return NSLocalizedString("按标题", comment: "")
        case .fileName: return NSLocalizedString("按文件名", comment: "")
        case .fileSize: return NSLocalizedString("按大小", comment: "")
        case .path: return NSLocalizedString("按路径", comment: "")
        }
    }
}

struct LocalLibraryQuery: Equatable {
    var searchText: String = ""
    var filter: LocalLibraryFilter = .all
    var folderId: Int64?
    var sort: LocalLibrarySort = .title
    var includesMissing: Bool = false

    var trimmedSearchText: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 纯查询逻辑：搜索/筛选/排序。
/// SQLiteStore 的 SQL 查询尽量保持同样语义；这里的实现同时供单元测试使用。
enum LocalLibraryQueryLogic {

    static func matches(_ file: LocalLibraryFile, query: LocalLibraryQuery) -> Bool {
        if !query.includesMissing && file.isMissing {
            return false
        }
        if let folderId = query.folderId, file.folderId != folderId {
            return false
        }
        switch query.filter {
        case .all:
            break
        case .matched:
            guard file.isMatched else { return false }
        case .unmatched:
            guard !file.isMatched else { return false }
        }

        let keyword = query.trimmedSearchText
        guard !keyword.isEmpty else { return true }

        let candidates = [
            file.fileName,
            file.animeTitle ?? "",
            file.episodeTitle ?? "",
            file.path,
        ]
        return candidates.contains {
            $0.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive],
                range: nil,
                locale: .current
            ) != nil
        }
    }

    static func sorted(_ files: [LocalLibraryFile], by sort: LocalLibrarySort) -> [LocalLibraryFile] {
        files.sorted { lhs, rhs in
            switch sort {
            case .title:
                return compareText(lhs.displayTitle, rhs.displayTitle, lhs: lhs, rhs: rhs)
            case .fileName:
                return compareText(lhs.fileName, rhs.fileName, lhs: lhs, rhs: rhs)
            case .fileSize:
                if lhs.fileSize != rhs.fileSize { return lhs.fileSize > rhs.fileSize }
                return compareText(lhs.fileName, rhs.fileName, lhs: lhs, rhs: rhs)
            case .path:
                return compareText(lhs.path, rhs.path, lhs: lhs, rhs: rhs)
            }
        }
    }

    static func apply(_ files: [LocalLibraryFile], query: LocalLibraryQuery) -> [LocalLibraryFile] {
        sorted(files.filter { matches($0, query: query) }, by: query.sort)
    }

    private static func compareText(
        _ lhsText: String,
        _ rhsText: String,
        lhs: LocalLibraryFile,
        rhs: LocalLibraryFile
    ) -> Bool {
        let result = lhsText.localizedStandardCompare(rhsText)
        if result != .orderedSame {
            return result == .orderedAscending
        }
        return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
    }
}

// MARK: - Statistics

struct LocalLibraryStatistics: Equatable {
    var totalCount: Int = 0
    var matchedCount: Int = 0
    var unmatchedCount: Int = 0
    var missingCount: Int = 0
    var folderCount: Int = 0
}

// MARK: - Scan

struct LocalLibraryScanProgress: Equatable {
    var scanned: Int
    var total: Int
    var currentFileName: String

    var fraction: Double {
        guard total > 0 else { return 0 }
        return min(max(Double(scanned) / Double(total), 0), 1)
    }
}

struct LocalLibraryScanSummary: Equatable {
    var added: Int = 0
    var updated: Int = 0
    var unchanged: Int = 0
    var markedMissing: Int = 0
    var hashed: Int = 0
    var failed: Int = 0
    var cancelled: Bool = false
    var errorMessage: String?
}

struct LocalLibraryScanItem: Equatable {
    var path: String
    var fileName: String
    var fileSize: Int64
    var modifiedAt: Date
}

enum LocalLibraryScanError: LocalizedError {
    case unreadableFolder(String)

    var errorDescription: String? {
        switch self {
        case .unreadableFolder(let path):
            return String(format: NSLocalizedString("无法读取文件夹：%@", comment: ""), path)
        }
    }
}

/// 扫描规则（纯函数，便于测试）。
enum LocalLibraryScanRules {

    /// 与 Windows 媒体库一致，额外包含常见 TS/M2TS/WMV。
    static let videoExtensions: Set<String> = [
        "mkv", "mp4", "avi", "mov", "rmvb", "webm", "flv", "ts", "m2ts", "wmv",
    ]

    static func isVideoFileName(_ fileName: String) -> Bool {
        let ext = (fileName as NSString).pathExtension.lowercased()
        return videoExtensions.contains(ext)
    }

    static func isHiddenFileName(_ fileName: String) -> Bool {
        fileName.hasPrefix(".")
    }

    /// 同一路径 + size + mtime 未变化时可以跳过。
    /// mtime 使用 1 秒容差，避免不同文件系统/序列化精度造成重复哈希。
    static func needsUpdate(
        existing: LocalLibraryFile?,
        fileSize: Int64,
        modifiedAt: Date,
        tolerance: TimeInterval = 1
    ) -> Bool {
        guard let existing else { return true }
        if existing.isMissing { return true }
        if existing.fileSize != fileSize { return true }
        if abs(existing.modifiedAt.timeIntervalSince1970 - modifiedAt.timeIntervalSince1970) > tolerance {
            return true
        }
        return false
    }

    /// 递归枚举视频文件；跳过隐藏文件、包内容和非常规文件。
    static func enumerateVideoFiles(
        in root: URL,
        fileManager: FileManager = .default
    ) throws -> [LocalLibraryScanItem] {
        let keys: [URLResourceKey] = [
            .isRegularFileKey, .isHiddenKey, .isPackageKey,
            .fileSizeKey, .contentModificationDateKey,
        ]
        var enumerationError: Error?
        guard let enumerator = fileManager.enumerator(
            at: root,
            includingPropertiesForKeys: keys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants],
            errorHandler: { _, error in
                enumerationError = error
                return true
            }
        ) else {
            throw LocalLibraryScanError.unreadableFolder(root.path)
        }

        var result: [LocalLibraryScanItem] = []
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: Set(keys))
            if values?.isRegularFile != true { continue }
            if values?.isHidden == true { continue }
            if values?.isPackage == true { continue }

            let fileName = url.lastPathComponent
            guard isVideoFileName(fileName) else { continue }
            guard !isHiddenFileName(fileName) else { continue }

            result.append(
                LocalLibraryScanItem(
                    path: url.standardizedFileURL.path,
                    fileName: fileName,
                    fileSize: Int64(values?.fileSize ?? 0),
                    modifiedAt: values?.contentModificationDate ?? Date()
                )
            )
        }

        // 完全没有可读文件且枚举过程中出现过错误时，向上报告；
        // 避免把“没有权限”误判成“文件夹已清空”并把所有记录标为 missing。
        if result.isEmpty, let enumerationError {
            throw enumerationError
        }

        return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}

// MARK: - Match

struct LocalLibraryMatchInfo: Equatable {
    var animeId: Int
    var episodeId: Int
    var animeTitle: String
    var episodeTitle: String
    var imageUrl: String?
    var type: String?
}

enum LocalLibraryMatchOutcome: Equatable {
    case matched(LocalLibraryMatchInfo)
    case notMatched
    case multipleResults(Int)
    case noResult

    var isMatched: Bool {
        if case .matched = self { return true }
        return false
    }

    var failureDescription: String {
        switch self {
        case .matched:
            return ""
        case .notMatched:
            return NSLocalizedString("未精确匹配", comment: "")
        case .multipleResults(let count):
            return String(format: NSLocalizedString("匹配到 %d 条结果，需要手动确认", comment: ""), count)
        case .noResult:
            return NSLocalizedString("未找到匹配结果", comment: "")
        }
    }
}

/// 把 `/match` 的响应转换为媒体库可保存的结果。
/// 只接受 isMatched == true 且恰好一条结果，避免把模糊匹配写进媒体库。
enum LocalLibraryMatchEvaluator {

    static func evaluate(_ collection: MatchCollection?) -> LocalLibraryMatchOutcome {
        guard let collection else { return .noResult }
        let matches = collection.collection

        if collection.isMatched && matches.count == 1 {
            let match = matches[0]
            guard match.animeId > 0, match.episodeId > 0 else {
                return .notMatched
            }
            return .matched(
                LocalLibraryMatchInfo(
                    animeId: match.animeId,
                    episodeId: match.episodeId,
                    animeTitle: Self.normalized(match.animeTitle),
                    episodeTitle: Self.normalized(match.episodeTitle),
                    imageUrl: (match.imageUrl.isEmpty || match.imageUrl == "Unknown") ? nil : match.imageUrl,
                    type: match.type.rawValue
                )
            )
        }

        if matches.isEmpty {
            return .noResult
        }
        if matches.count > 1 {
            return .multipleResults(matches.count)
        }
        return .notMatched
    }

    private static func normalized(_ value: String) -> String {
        value == "Unknown" ? "" : value
    }
}

// MARK: - Formatting

enum LocalLibraryFormatting {

    static func fileSize(_ bytes: Int64) -> String {
        ByteCountFormatter.string(fromByteCount: bytes, countStyle: .file)
    }

    static func folderName(for path: String) -> String {
        let last = (path as NSString).lastPathComponent
        return last.isEmpty ? path : last
    }
}
