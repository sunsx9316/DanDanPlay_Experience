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
    /// 由 AVFoundation 在后台探测；不支持的编码保持 nil。
    var duration: Double?
    var pixelWidth: Int?
    var pixelHeight: Int?

    var fileURL: URL {
        URL(fileURLWithPath: path)
    }

    var mediaMetadata: LocalLibraryMediaMetadata {
        LocalLibraryMediaMetadata(duration: duration, width: pixelWidth, height: pixelHeight)
    }

    /// 文件名、大小、修改时间和哈希都未变化时，重扫应保留匹配结果。
    /// 哈希计算失败（nil）不视为内容变化：宁可保留旧匹配，也不要因网络卷/临时错误丢元数据。
    func hasSameScannedContent(
        fileSize: Int64,
        modifiedAt: Date,
        hash: String?,
        tolerance: TimeInterval = 1
    ) -> Bool {
        guard self.fileSize == fileSize else { return false }
        guard abs(self.modifiedAt.timeIntervalSince1970 - modifiedAt.timeIntervalSince1970) <= tolerance else {
            return false
        }
        guard let hash else { return true }
        guard let existingHash = self.hash else { return true }
        return existingHash == hash
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
        existing: LocalLibraryFile?,
        now: Date
    ) -> LocalLibraryFile {
        let keepsMatch = existing?.hasSameScannedContent(
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            hash: hash
        ) ?? false
        // 哈希计算失败但大小/mtime 未变时保留旧哈希，避免下次扫描丢失匹配依据。
        let resolvedHash = (keepsMatch && hash == nil) ? existing?.hash : hash

        return LocalLibraryFile(
            id: existing?.id ?? 0,
            // 同一路径可能同时落在父/子文件夹的扫描范围里；保留首次入库的归属，
            // 避免嵌套文件夹互相覆盖导致计数和移除行为不稳定。
            folderId: existing?.folderId ?? folderId,
            path: path,
            fileName: fileName,
            fileSize: fileSize,
            modifiedAt: modifiedAt,
            hash: resolvedHash,
            animeId: keepsMatch ? existing?.animeId : nil,
            episodeId: keepsMatch ? existing?.episodeId : nil,
            animeTitle: keepsMatch ? existing?.animeTitle : nil,
            episodeTitle: keepsMatch ? existing?.episodeTitle : nil,
            imageUrl: keepsMatch ? existing?.imageUrl : nil,
            type: keepsMatch ? existing?.type : nil,
            isMatched: keepsMatch ? (existing?.isMatched ?? false) : false,
            isMissing: false,
            lastScannedAt: now,
            duration: keepsMatch ? existing?.duration : nil,
            pixelWidth: keepsMatch ? existing?.pixelWidth : nil,
            pixelHeight: keepsMatch ? existing?.pixelHeight : nil
        )
    }
}

// MARK: - Query

enum LocalLibraryFilter: String, CaseIterable {
    case all
    case matched
    case unmatched
    case missing

    var displayName: String {
        switch self {
        case .all: return NSLocalizedString("全部", comment: "")
        case .matched: return NSLocalizedString("已匹配", comment: "")
        case .unmatched: return NSLocalizedString("未匹配", comment: "")
        case .missing: return NSLocalizedString("缺失", comment: "")
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
        if query.filter == .missing {
            guard file.isMissing else { return false }
        } else if !query.includesMissing && file.isMissing {
            return false
        }
        if let folderId = query.folderId, file.folderId != folderId {
            return false
        }
        switch query.filter {
        case .all, .missing:
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

struct LocalLibraryScanFailure: Equatable {
    var folderId: Int64
    var folderPath: String
    var message: String
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
    var folderFailures: [LocalLibraryScanFailure] = []
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
        // 首次哈希失败（nil）时下次扫描重试，避免永久无法匹配。
        if existing.hash == nil { return true }
        if existing.fileSize != fileSize { return true }
        if abs(existing.modifiedAt.timeIntervalSince1970 - modifiedAt.timeIntervalSince1970) > tolerance {
            return true
        }
        return false
    }

    /// 递归枚举视频文件；跳过隐藏文件、包内容和非常规文件。
    /// `shouldCancel` 会在每个目录项之间检查；取消时抛出 `CancellationError`，
    /// 让调用方不要把“用户取消”误判为“文件夹为空”。
    static func enumerateVideoFiles(
        in root: URL,
        fileManager: FileManager = .default,
        shouldCancel: (() -> Bool)? = nil
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
            if shouldCancel?() == true {
                throw CancellationError()
            }
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

        if shouldCancel?() == true {
            throw CancellationError()
        }

        // 完全没有可读文件且枚举过程中出现过错误时，向上报告；
        // 避免把“没有权限”误判成“文件夹已清空”并把所有记录标为 missing。
        if result.isEmpty, let enumerationError {
            throw enumerationError
        }

        return result.sorted { $0.path.localizedStandardCompare($1.path) == .orderedAscending }
    }
}

// MARK: - Folder relationships

/// 新添加的媒体库文件夹与既有文件夹的包含关系。
enum LocalLibraryFolderRelationship: Equatable {
    case none
    case same
    /// 新文件夹是既有文件夹的父目录（包含既有文件夹）。
    case newIsAncestor
    /// 新文件夹位于既有文件夹内部。
    case newIsDescendant
}

enum LocalLibraryFolderRules {

    static func relationship(newPath: String, existingPath: String) -> LocalLibraryFolderRelationship {
        let new = normalized(newPath)
        let existing = normalized(existingPath)
        guard !new.isEmpty, !existing.isEmpty else { return .none }
        if new == existing { return .same }
        if isDescendant(existing, of: new) { return .newIsAncestor }
        if isDescendant(new, of: existing) { return .newIsDescendant }
        return .none
    }

    /// 返回所有重叠的既有路径及关系；空数组表示没有重叠。
    static func overlaps(
        newPath: String,
        existingPaths: [String]
    ) -> [(path: String, relationship: LocalLibraryFolderRelationship)] {
        existingPaths.compactMap { existing in
            let relationship = relationship(newPath: newPath, existingPath: existing)
            guard relationship != .none else { return nil }
            return (existing, relationship)
        }
    }

    static func normalized(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private static func isDescendant(_ path: String, of ancestor: String) -> Bool {
        if ancestor == "/" {
            return path != "/" && path.hasPrefix("/")
        }
        return path.hasPrefix(ancestor + "/")
    }
}

// MARK: - Episode grouping

struct LocalLibraryAnimeGroup: Equatable {
    var animeId: Int
    var animeTitle: String
    var imageUrl: String?
    var type: String?
    /// 已按集数/标题排序。
    var files: [LocalLibraryFile]

    var episodeCount: Int { files.count }
    var missingCount: Int { files.filter(\.isMissing).count }
    var totalSize: Int64 { files.reduce(0) { $0 + $1.fileSize } }
    var sizeText: String { LocalLibraryFormatting.fileSize(totalSize) }

    var primaryFile: LocalLibraryFile? {
        files.first(where: { !$0.isMissing }) ?? files.first
    }

    var mediaMetadata: LocalLibraryMediaMetadata {
        primaryFile?.mediaMetadata ?? LocalLibraryMediaMetadata()
    }

    var displayImageURL: URL? {
        if let imageUrl, !imageUrl.isEmpty, imageUrl != "Unknown", let url = URL(string: imageUrl) {
            return url
        }
        return files.compactMap(\.displayImageURL).first
    }
}

enum LocalLibraryCard: Equatable {
    case group(LocalLibraryAnimeGroup)
    case file(LocalLibraryFile)

    var id: String {
        switch self {
        case .group(let group):
            return "anime-\(group.animeId)"
        case .file(let file):
            return "file-\(file.id)"
        }
    }

    var files: [LocalLibraryFile] {
        switch self {
        case .group(let group): return group.files
        case .file(let file): return [file]
        }
    }

    var primaryFile: LocalLibraryFile? {
        files.first
    }

    var sortTitle: String {
        switch self {
        case .group(let group): return group.animeTitle
        case .file(let file): return file.displayTitle
        }
    }

    var isMissing: Bool {
        files.allSatisfy(\.isMissing)
    }
}

enum LocalLibraryGrouping {

    /// 已匹配且 animeId 相同的文件合并为一张卡；未匹配文件保持独立。
    static func cards(from files: [LocalLibraryFile], sort: LocalLibrarySort) -> [LocalLibraryCard] {
        var grouped: [Int: [LocalLibraryFile]] = [:]
        var individuals: [LocalLibraryFile] = []

        for file in files {
            if file.isMatched, let animeId = file.animeId, animeId > 0 {
                grouped[animeId, default: []].append(file)
            } else {
                individuals.append(file)
            }
        }

        var cards: [LocalLibraryCard] = []
        for (animeId, groupFiles) in grouped {
            let ordered = orderedEpisodes(groupFiles)
            let first = ordered[0]
            let title = groupFiles
                .compactMap(\.animeTitle)
                .first(where: { !$0.isEmpty }) ?? first.displayTitle
            let imageUrl = groupFiles
                .compactMap(\.imageUrl)
                .first(where: { !$0.isEmpty && $0 != "Unknown" })
            let type = groupFiles.compactMap(\.type).first(where: { !$0.isEmpty })
            cards.append(
                .group(
                    LocalLibraryAnimeGroup(
                        animeId: animeId,
                        animeTitle: title,
                        imageUrl: imageUrl,
                        type: type,
                        files: ordered
                    )
                )
            )
        }
        cards.append(contentsOf: individuals.map { .file($0) })
        return sortedCards(cards, by: sort)
    }

    /// 第2话应排在第10话之前；无法解析集数时退回标题/路径排序。
    static func orderedEpisodes(_ files: [LocalLibraryFile]) -> [LocalLibraryFile] {
        var numbers: [String: Double?] = [:]
        for file in files {
            numbers[file.path] = episodeNumber(from: file.episodeTitle ?? file.fileName)
        }
        return files.sorted { lhs, rhs in
            let lhsNumber = numbers[lhs.path] ?? nil
            let rhsNumber = numbers[rhs.path] ?? nil

            switch (lhsNumber, rhsNumber) {
            case let (lhsNumber?, rhsNumber?) where lhsNumber != rhsNumber:
                return lhsNumber < rhsNumber
            case (nil, .some):
                return false
            case (.some, nil):
                return true
            default:
                break
            }

            let lhsTitle = (lhs.episodeTitle.flatMap { $0.isEmpty ? nil : $0 }) ?? lhs.fileName
            let rhsTitle = (rhs.episodeTitle.flatMap { $0.isEmpty ? nil : $0 }) ?? rhs.fileName
            let result = lhsTitle.localizedStandardCompare(rhsTitle)
            if result != .orderedSame {
                return result == .orderedAscending
            }
            return lhs.path.localizedStandardCompare(rhs.path) == .orderedAscending
        }
    }

    private static let episodePatterns: [NSRegularExpression] = [
        #"(?i)\bS\d+\s*E(\d+(?:\.\d+)?)\b"#,
        #"第\s*(\d+(?:\.\d+)?)\s*[话話集]"#,
        #"(?i)\b(?:EP|E)\s*(\d+(?:\.\d+)?)\b"#,
        #"(\d+(?:\.\d+)?)"#,
    ].compactMap { try? NSRegularExpression(pattern: $0) }

    /// 支持「第12话」「EP03」「S02E05」以及纯数字；解析失败返回 nil。
    static func episodeNumber(from text: String) -> Double? {
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        for regex in episodePatterns {
            guard let match = regex.firstMatch(in: text, range: range), match.numberOfRanges > 1,
                  let valueRange = Range(match.range(at: 1), in: text) else {
                continue
            }
            if let value = Double(text[valueRange]) {
                return value
            }
        }
        return nil
    }

    static func sortedCards(_ cards: [LocalLibraryCard], by sort: LocalLibrarySort) -> [LocalLibraryCard] {
        cards.sorted { lhs, rhs in
            switch sort {
            case .title:
                let result = lhs.sortTitle.localizedStandardCompare(rhs.sortTitle)
                if result != .orderedSame { return result == .orderedAscending }
            case .fileName:
                let leftName = lhs.primaryFile?.fileName ?? ""
                let rightName = rhs.primaryFile?.fileName ?? ""
                let result = leftName.localizedStandardCompare(rightName)
                if result != .orderedSame { return result == .orderedAscending }
            case .fileSize:
                if lhs.files.reduce(0, { $0 + $1.fileSize }) != rhs.files.reduce(0, { $0 + $1.fileSize }) {
                    return lhs.files.reduce(0, { $0 + $1.fileSize }) > rhs.files.reduce(0, { $0 + $1.fileSize })
                }
            case .path:
                let leftPath = lhs.primaryFile?.path ?? ""
                let rightPath = rhs.primaryFile?.path ?? ""
                let result = leftPath.localizedStandardCompare(rightPath)
                if result != .orderedSame { return result == .orderedAscending }
            }
            return lhs.id.localizedStandardCompare(rhs.id) == .orderedAscending
        }
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

// MARK: - Media metadata

struct LocalLibraryMediaMetadata: Equatable {
    var duration: Double?
    var width: Int?
    var height: Int?

    var isEmpty: Bool {
        durationText == nil && resolutionText == nil
    }

    var displayText: String {
        [durationText, resolutionText]
            .compactMap { $0 }
            .joined(separator: " · ")
    }

    var durationText: String? {
        guard let duration, duration.isFinite, duration > 0 else { return nil }
        return LocalLibraryFormatting.duration(duration)
    }

    var resolutionText: String? {
        guard let width, let height, width > 0, height > 0 else { return nil }
        let shortSide = min(width, height)
        let longSide = max(width, height)
        if shortSide >= 2000 { return "4K" }
        if shortSide >= 1000 { return "1080p" }
        if shortSide >= 700 { return "720p" }
        return "\(width)×\(height)"
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

    static func duration(_ seconds: Double) -> String {
        let total = max(0, Int(seconds.rounded()))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%d:%02d", minutes, secs)
    }
}
