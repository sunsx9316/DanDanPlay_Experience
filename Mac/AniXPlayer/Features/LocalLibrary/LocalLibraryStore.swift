//
//  LocalLibraryStore.swift
//  AniXPlayer
//
//  macOS：本地媒体库 SQLite 持久化。
//  数据库默认位于 ~/Library/Application Support/AniXPlayer/LocalLibrary.sqlite；
//  App 启用沙盒时会自动落到容器内的同名 Application Support 目录。
//

import Foundation
import SQLite3

enum LocalLibraryStoreError: LocalizedError {
    case openDatabase(String)
    case database(String)
    case invalidPath(String)

    var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return String(format: NSLocalizedString("无法打开媒体库数据库：%@", comment: ""), message)
        case .database(let message):
            return String(format: NSLocalizedString("媒体库数据库错误：%@", comment: ""), message)
        case .invalidPath(let path):
            return String(format: NSLocalizedString("无效的媒体库路径：%@", comment: ""), path)
        }
    }
}

private let localLibrarySQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private let localLibraryFileColumns = """
    id, folderId, path, fileName, fileSize, modifiedAt, hash, \
    animeId, episodeId, animeTitle, episodeTitle, imageUrl, type, \
    isMatched, isMissing, lastScannedAt, duration, width, height
    """

final class LocalLibraryStore {

    static let defaultDatabaseURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("LocalLibrary.sqlite", isDirectory: false)
    }()

    let databaseURL: URL

    private var database: OpaquePointer?
    private let lock = NSLock()

    init(databaseURL: URL? = nil) throws {
        let url = databaseURL ?? Self.defaultDatabaseURL
        self.databaseURL = url

        if !FileManager.default.fileExists(atPath: url.deletingLastPathComponent().path) {
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &db, flags, nil)
        guard result == SQLITE_OK, let opened = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 failed (\(result))"
            if let db { sqlite3_close(db) }
            throw LocalLibraryStoreError.openDatabase(message)
        }
        self.database = opened
        sqlite3_busy_timeout(opened, 3000)

        do {
            try migrate()
        } catch {
            sqlite3_close(opened)
            self.database = nil
            throw error
        }
    }

    deinit {
        if let database {
            sqlite3_close(database)
        }
    }

    // MARK: - Schema

    private func migrate() throws {
        try execute("PRAGMA foreign_keys = ON")
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")

        // v1：基础表。使用 IF NOT EXISTS，重复打开/重复迁移都是幂等的。
        try execute("""
            CREATE TABLE IF NOT EXISTS folders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT NOT NULL UNIQUE,
                bookmark BLOB,
                addedAt REAL NOT NULL
            )
            """)

        try execute("""
            CREATE TABLE IF NOT EXISTS files (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                folderId INTEGER NOT NULL REFERENCES folders(id) ON DELETE CASCADE,
                path TEXT NOT NULL UNIQUE,
                fileName TEXT NOT NULL,
                fileSize INTEGER NOT NULL DEFAULT 0,
                modifiedAt REAL NOT NULL DEFAULT 0,
                hash TEXT,
                animeId INTEGER,
                episodeId INTEGER,
                animeTitle TEXT,
                episodeTitle TEXT,
                imageUrl TEXT,
                type TEXT,
                isMatched INTEGER NOT NULL DEFAULT 0,
                isMissing INTEGER NOT NULL DEFAULT 0,
                lastScannedAt REAL NOT NULL DEFAULT 0,
                duration REAL,
                width INTEGER,
                height INTEGER
            )
            """)

        try execute("CREATE UNIQUE INDEX IF NOT EXISTS idx_local_library_files_path ON files(path)")
        try execute("CREATE INDEX IF NOT EXISTS idx_local_library_files_folder ON files(folderId)")
        try execute("CREATE INDEX IF NOT EXISTS idx_local_library_files_matched ON files(isMatched)")
        try execute("CREATE INDEX IF NOT EXISTS idx_local_library_files_missing ON files(isMissing)")

        // 兼容早期内部测试库：缺少列时补齐。
        if !hasColumn(table: "files", column: "isMissing") {
            try execute("ALTER TABLE files ADD COLUMN isMissing INTEGER NOT NULL DEFAULT 0")
        }
        if !hasColumn(table: "files", column: "duration") {
            try execute("ALTER TABLE files ADD COLUMN duration REAL")
        }
        if !hasColumn(table: "files", column: "width") {
            try execute("ALTER TABLE files ADD COLUMN width INTEGER")
        }
        if !hasColumn(table: "files", column: "height") {
            try execute("ALTER TABLE files ADD COLUMN height INTEGER")
        }

        if try intValue("PRAGMA user_version") < 2 {
            try execute("PRAGMA user_version = 2")
        }
    }

    private func hasColumn(table: String, column: String) -> Bool {
        guard let statement = try? prepare("PRAGMA table_info(\(table))") else { return false }
        defer { sqlite3_finalize(statement) }
        while sqlite3_step(statement) == SQLITE_ROW {
            if let text = sqlite3_column_text(statement, 1) {
                if String(cString: text) == column {
                    return true
                }
            }
        }
        return false
    }

    // MARK: - Folders

    func folders() throws -> [LocalLibraryFolder] {
        lock.lock()
        defer { lock.unlock() }
        return try foldersUnlocked()
    }

    @discardableResult
    func addFolder(path: String, bookmark: Data?, addedAt: Date = Date()) throws -> LocalLibraryFolder {
        let normalized = try normalizedPath(path)
        lock.lock()
        defer { lock.unlock() }

        if let existing = try folderUnlocked(path: normalized) {
            if let bookmark, bookmark != existing.bookmark {
                try updateFolderBookmarkUnlocked(id: existing.id, bookmark: bookmark)
                return try folderUnlocked(id: existing.id) ?? existing
            }
            return existing
        }

        let statement = try prepare("INSERT INTO folders(path, bookmark, addedAt) VALUES (?, ?, ?)")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, normalized)
        bind(statement, 2, bookmark)
        bind(statement, 3, addedAt.timeIntervalSince1970)
        try stepDone(statement)

        let id = sqlite3_last_insert_rowid(databaseOrThrow())
        return LocalLibraryFolder(id: id, path: normalized, bookmark: bookmark, addedAt: addedAt)
    }

    func folder(id: Int64) throws -> LocalLibraryFolder? {
        lock.lock()
        defer { lock.unlock() }
        return try folderUnlocked(id: id)
    }

    func folder(path: String) throws -> LocalLibraryFolder? {
        let normalized = try normalizedPath(path)
        lock.lock()
        defer { lock.unlock() }
        return try folderUnlocked(path: normalized)
    }

    func updateFolderBookmark(id: Int64, bookmark: Data?) throws {
        lock.lock()
        defer { lock.unlock() }
        try updateFolderBookmarkUnlocked(id: id, bookmark: bookmark)
    }

    /// 移除根文件夹，并级联删除其索引记录；不会删除磁盘文件。
    @discardableResult
    func removeFolder(id: Int64) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let count = try intValue("SELECT COUNT(*) FROM files WHERE folderId = \(id)")
        let statement = try prepare("DELETE FROM folders WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id)
        try stepDone(statement)
        return count
    }

    // MARK: - Files

    /// 按 path upsert：路径唯一，返回数据库中实际保存的行（包含自增 id）。
    @discardableResult
    func saveFile(_ file: LocalLibraryFile) throws -> LocalLibraryFile {
        lock.lock()
        defer { lock.unlock() }

        let normalized = try normalizedPath(file.path)
        var value = file
        value.path = normalized
        value.fileName = (normalized as NSString).lastPathComponent

        let existing = try fileUnlocked(path: normalized)
        if value.id == 0, let existing {
            value.id = existing.id
        }
        // 同一路径可能被父/子文件夹同时扫描；folderId 只认首次归属。
        if let existing {
            value.folderId = existing.folderId
        }

        if value.id == 0 {
            let statement = try prepare("""
                INSERT INTO files(
                    folderId, path, fileName, fileSize, modifiedAt, hash,
                    animeId, episodeId, animeTitle, episodeTitle, imageUrl, type,
                    isMatched, isMissing, lastScannedAt, duration, width, height
                ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
                """)
            defer { sqlite3_finalize(statement) }
            bindFileValues(statement, file: value, startIndex: 1)
            try stepDone(statement)
            value.id = sqlite3_last_insert_rowid(databaseOrThrow())
        } else {
            let statement = try prepare("""
                UPDATE files SET
                    folderId = ?, path = ?, fileName = ?, fileSize = ?, modifiedAt = ?, hash = ?,
                    animeId = ?, episodeId = ?, animeTitle = ?, episodeTitle = ?, imageUrl = ?, type = ?,
                    isMatched = ?, isMissing = ?, lastScannedAt = ?, duration = ?, width = ?, height = ?
                WHERE id = ?
                """)
            defer { sqlite3_finalize(statement) }
            bindFileValues(statement, file: value, startIndex: 1)
            bind(statement, 19, value.id)
            try stepDone(statement)
        }

        return try fileUnlocked(path: normalized) ?? value
    }

    func file(path: String) throws -> LocalLibraryFile? {
        let normalized = try normalizedPath(path)
        lock.lock()
        defer { lock.unlock() }
        return try fileUnlocked(path: normalized)
    }

    func file(id: Int64) throws -> LocalLibraryFile? {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("SELECT \(localLibraryFileColumns) FROM files WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readFile(statement)
        }
        return nil
    }

    func files(folderId: Int64) throws -> [LocalLibraryFile] {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("""
            SELECT \(localLibraryFileColumns) FROM files
            WHERE folderId = ? AND isMissing = 0
            ORDER BY fileName COLLATE NOCASE
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, folderId)
        return readFiles(statement)
    }

    /// 只读查询：某部番剧下所有已匹配且未缺失的文件。
    /// 供详情页显示本地播放入口；不会触发扫描，也不会改写匹配数据。
    func matchedFiles(animeId: Int) throws -> [LocalLibraryFile] {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("""
            SELECT \(localLibraryFileColumns) FROM files
            WHERE isMatched = 1 AND isMissing = 0 AND animeId = ?
            ORDER BY episodeId ASC, fileName COLLATE NOCASE ASC, path COLLATE NOCASE ASC
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, Int64(animeId))
        return readFiles(statement)
    }

    /// 只读查询：指定番剧 + 剧集下所有已匹配且未缺失的文件。
    func matchedFiles(animeId: Int, episodeId: Int) throws -> [LocalLibraryFile] {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("""
            SELECT \(localLibraryFileColumns) FROM files
            WHERE isMatched = 1 AND isMissing = 0 AND animeId = ? AND episodeId = ?
            ORDER BY fileName COLLATE NOCASE ASC, path COLLATE NOCASE ASC
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, Int64(animeId))
        bind(statement, 2, Int64(episodeId))
        return readFiles(statement)
    }

    /// 搜索 / 筛选 / 排序查询（SQL 版本）。
    func files(query: LocalLibraryQuery) throws -> [LocalLibraryFile] {
        lock.lock()
        defer { lock.unlock() }

        var conditions: [String] = []
        var bindings: [SQLiteValue] = []

        switch query.filter {
        case .missing:
            conditions.append("isMissing = 1")
        case .all, .matched, .unmatched:
            if !query.includesMissing {
                conditions.append("isMissing = 0")
            }
        }
        if let folderId = query.folderId {
            conditions.append("folderId = ?")
            bindings.append(.int64(folderId))
        }
        switch query.filter {
        case .all, .missing:
            break
        case .matched:
            conditions.append("isMatched = 1")
        case .unmatched:
            conditions.append("isMatched = 0")
        }

        let keyword = query.trimmedSearchText
        if !keyword.isEmpty {
            let pattern = "%\(escapeLike(keyword))%"
            conditions.append("""
                (fileName LIKE ? ESCAPE '\\' OR \
                COALESCE(animeTitle, '') LIKE ? ESCAPE '\\' OR \
                COALESCE(episodeTitle, '') LIKE ? ESCAPE '\\' OR \
                path LIKE ? ESCAPE '\\')
                """)
            bindings.append(.string(pattern))
            bindings.append(.string(pattern))
            bindings.append(.string(pattern))
            bindings.append(.string(pattern))
        }

        let whereClause = conditions.isEmpty ? "" : "WHERE " + conditions.joined(separator: " AND ")
        let statement = try prepare("""
            SELECT \(localLibraryFileColumns) FROM files
            \(whereClause)
            ORDER BY \(orderClause(for: query.sort))
            """)
        defer { sqlite3_finalize(statement) }
        try bind(statement, values: bindings)
        return readFiles(statement)
    }

    func unmatchedFiles(limit: Int? = nil) throws -> [LocalLibraryFile] {
        lock.lock()
        defer { lock.unlock() }
        var sql = """
            SELECT \(localLibraryFileColumns) FROM files
            WHERE isMissing = 0 AND isMatched = 0
            ORDER BY fileName COLLATE NOCASE
            """
        if let limit {
            sql += " LIMIT \(max(0, limit))"
        }
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        return readFiles(statement)
    }

    @discardableResult
    func updateMatch(fileId: Int64, outcome: LocalLibraryMatchOutcome) throws -> LocalLibraryFile? {
        lock.lock()
        defer { lock.unlock() }

        if case .matched(let info) = outcome {
            return try applyMatchUnlocked(fileId: fileId, info: info)
        }
        return try clearMatchUnlocked(fileId: fileId)
    }

    /// 手动匹配：直接写入用户选择的番剧/剧集。
    @discardableResult
    func applyManualMatch(fileId: Int64, info: LocalLibraryMatchInfo) throws -> LocalLibraryFile? {
        lock.lock()
        defer { lock.unlock() }
        return try applyMatchUnlocked(fileId: fileId, info: info)
    }

    /// 取消匹配：清空番剧/剧集/标题/图片/类型。
    @discardableResult
    func clearMatch(fileId: Int64) throws -> LocalLibraryFile? {
        lock.lock()
        defer { lock.unlock() }
        return try clearMatchUnlocked(fileId: fileId)
    }

    private func applyMatchUnlocked(fileId: Int64, info: LocalLibraryMatchInfo) throws -> LocalLibraryFile? {
        let statement = try prepare("""
            UPDATE files SET isMatched = 1, animeId = ?, episodeId = ?, animeTitle = ?,
                episodeTitle = ?, imageUrl = ?, type = ?
            WHERE id = ?
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, Int64(info.animeId))
        bind(statement, 2, Int64(info.episodeId))
        bind(statement, 3, info.animeTitle)
        bind(statement, 4, info.episodeTitle)
        bind(statement, 5, info.imageUrl)
        bind(statement, 6, info.type)
        bind(statement, 7, fileId)
        try stepDone(statement)
        return try fileUnlocked(id: fileId)
    }

    private func clearMatchUnlocked(fileId: Int64) throws -> LocalLibraryFile? {
        let statement = try prepare("""
            UPDATE files SET isMatched = 0, animeId = NULL, episodeId = NULL, animeTitle = NULL,
                episodeTitle = NULL, imageUrl = NULL, type = NULL
            WHERE id = ?
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, fileId)
        try stepDone(statement)
        return try fileUnlocked(id: fileId)
    }

    /// 写入后台探测到的时长/分辨率；nil 表示该项探测失败。
    @discardableResult
    func updateMediaMetadata(
        fileId: Int64,
        duration: Double?,
        width: Int?,
        height: Int?
    ) throws -> LocalLibraryFile? {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("UPDATE files SET duration = ?, width = ?, height = ? WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, duration)
        bind(statement, 2, width.map { Int64($0) })
        bind(statement, 3, height.map { Int64($0) })
        bind(statement, 4, fileId)
        try stepDone(statement)
        return try fileUnlocked(id: fileId)
    }

    @discardableResult
    func setMissing(fileId: Int64, isMissing: Bool) throws -> LocalLibraryFile? {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("UPDATE files SET isMissing = ? WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, Int64(isMissing ? 1 : 0))
        bind(statement, 2, fileId)
        try stepDone(statement)
        return try fileUnlocked(id: fileId)
    }

    /// 标记磁盘上已不存在的文件；不会删除记录，便于以后恢复。
    @discardableResult
    func markMissing(folderId: Int64, keepingPaths: Set<String>, scannedAt: Date = Date()) throws -> Int {
        lock.lock()
        defer { lock.unlock() }

        let statement = try prepare("SELECT id, path FROM files WHERE folderId = ?")
        var missingIds: [Int64] = []
        do {
            defer { sqlite3_finalize(statement) }
            bind(statement, 1, folderId)
            while sqlite3_step(statement) == SQLITE_ROW {
                let id = sqlite3_column_int64(statement, 0)
                let path = string(statement, 1) ?? ""
                if !keepingPaths.contains(path) {
                    missingIds.append(id)
                }
            }
        }
        guard !missingIds.isEmpty else { return 0 }

        try execute("BEGIN IMMEDIATE")
        do {
            let update = try prepare("UPDATE files SET isMissing = 1, lastScannedAt = ? WHERE id = ?")
            defer { sqlite3_finalize(update) }
            for id in missingIds {
                sqlite3_reset(update)
                sqlite3_clear_bindings(update)
                bind(update, 1, scannedAt.timeIntervalSince1970)
                bind(update, 2, id)
                try stepDone(update)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
        return missingIds.count
    }

    @discardableResult
    func deleteFiles(folderId: Int64) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let count = try intValue("SELECT COUNT(*) FROM files WHERE folderId = \(folderId)")
        let statement = try prepare("DELETE FROM files WHERE folderId = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, folderId)
        try stepDone(statement)
        return count
    }

    /// 从索引中移除指定记录，不删除磁盘文件。
    @discardableResult
    func deleteFiles(ids: [Int64]) throws -> Int {
        guard !ids.isEmpty else { return 0 }
        lock.lock()
        defer { lock.unlock() }
        // Int64 由本模块生成，直接拼接占位值可同时用于 COUNT 和 DELETE。
        let placeholders = ids.map(String.init).joined(separator: ",")
        let count = try intValue("SELECT COUNT(*) FROM files WHERE id IN (\(placeholders))")
        let statement = try prepare("DELETE FROM files WHERE id IN (\(placeholders))")
        defer { sqlite3_finalize(statement) }
        try stepDone(statement)
        return count
    }

    /// 只删除缺失记录；folderId 为 nil 时清理整个媒体库。
    @discardableResult
    func deleteMissingFiles(folderId: Int64? = nil) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        let whereClause = folderId == nil ? "isMissing = 1" : "isMissing = 1 AND folderId = ?"
        let count: Int
        let delete: OpaquePointer
        if let folderId {
            count = try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 1 AND folderId = \(folderId)")
            delete = try prepare("DELETE FROM files WHERE \(whereClause)")
            bind(delete, 1, folderId)
        } else {
            count = try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 1")
            delete = try prepare("DELETE FROM files WHERE \(whereClause)")
        }
        defer { sqlite3_finalize(delete) }
        try stepDone(delete)
        return count
    }

    func missingCount(folderId: Int64? = nil) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        if let folderId {
            return try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 1 AND folderId = \(folderId)")
        }
        return try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 1")
    }

    // MARK: - Statistics

    func fileCounts() throws -> [Int64: Int] {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("""
            SELECT folderId, COUNT(*) FROM files
            WHERE isMissing = 0
            GROUP BY folderId
            """)
        defer { sqlite3_finalize(statement) }

        var result: [Int64: Int] = [:]
        while sqlite3_step(statement) == SQLITE_ROW {
            result[sqlite3_column_int64(statement, 0)] = Int(sqlite3_column_int64(statement, 1))
        }
        return result
    }

    func statistics() throws -> LocalLibraryStatistics {
        lock.lock()
        defer { lock.unlock() }
        var stats = LocalLibraryStatistics()
        stats.totalCount = try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 0")
        stats.matchedCount = try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 0 AND isMatched = 1")
        stats.unmatchedCount = max(0, stats.totalCount - stats.matchedCount)
        stats.missingCount = try intValue("SELECT COUNT(*) FROM files WHERE isMissing = 1")
        stats.folderCount = try intValue("SELECT COUNT(*) FROM folders")
        return stats
    }

    // MARK: - Unlocked helpers

    private func foldersUnlocked() throws -> [LocalLibraryFolder] {
        let statement = try prepare("SELECT id, path, bookmark, addedAt FROM folders ORDER BY addedAt, id")
        defer { sqlite3_finalize(statement) }

        var folders: [LocalLibraryFolder] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            folders.append(readFolder(statement))
        }
        return folders
    }

    private func folderUnlocked(id: Int64) throws -> LocalLibraryFolder? {
        let statement = try prepare("SELECT id, path, bookmark, addedAt FROM folders WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readFolder(statement)
        }
        return nil
    }

    private func folderUnlocked(path: String) throws -> LocalLibraryFolder? {
        let statement = try prepare("SELECT id, path, bookmark, addedAt FROM folders WHERE path = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, path)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readFolder(statement)
        }
        return nil
    }

    private func readFolder(_ statement: OpaquePointer) -> LocalLibraryFolder {
        LocalLibraryFolder(
            id: sqlite3_column_int64(statement, 0),
            path: string(statement, 1) ?? "",
            bookmark: data(statement, 2),
            addedAt: date(statement, 3)
        )
    }

    private func updateFolderBookmarkUnlocked(id: Int64, bookmark: Data?) throws {
        let statement = try prepare("UPDATE folders SET bookmark = ? WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, bookmark)
        bind(statement, 2, id)
        try stepDone(statement)
    }

    private func fileUnlocked(path: String) throws -> LocalLibraryFile? {
        let statement = try prepare("SELECT \(localLibraryFileColumns) FROM files WHERE path = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, path)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readFile(statement)
        }
        return nil
    }

    private func fileUnlocked(id: Int64) throws -> LocalLibraryFile? {
        let statement = try prepare("SELECT \(localLibraryFileColumns) FROM files WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id)
        if sqlite3_step(statement) == SQLITE_ROW {
            return readFile(statement)
        }
        return nil
    }

    private func readFiles(_ statement: OpaquePointer) -> [LocalLibraryFile] {
        var files: [LocalLibraryFile] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            files.append(readFile(statement))
        }
        return files
    }

    private func readFile(_ statement: OpaquePointer) -> LocalLibraryFile {
        LocalLibraryFile(
            id: sqlite3_column_int64(statement, 0),
            folderId: sqlite3_column_int64(statement, 1),
            path: string(statement, 2) ?? "",
            fileName: string(statement, 3) ?? "",
            fileSize: sqlite3_column_int64(statement, 4),
            modifiedAt: date(statement, 5),
            hash: string(statement, 6),
            animeId: optionalInt(statement, 7),
            episodeId: optionalInt(statement, 8),
            animeTitle: string(statement, 9),
            episodeTitle: string(statement, 10),
            imageUrl: string(statement, 11),
            type: string(statement, 12),
            isMatched: sqlite3_column_int(statement, 13) != 0,
            isMissing: sqlite3_column_int(statement, 14) != 0,
            lastScannedAt: date(statement, 15),
            duration: sqlite3_column_type(statement, 16) != SQLITE_NULL
                ? sqlite3_column_double(statement, 16)
                : nil,
            pixelWidth: optionalInt(statement, 17),
            pixelHeight: optionalInt(statement, 18)
        )
    }

    private func bindFileValues(_ statement: OpaquePointer, file: LocalLibraryFile, startIndex: Int32) {
        var index = startIndex
        bind(statement, index, file.folderId); index += 1
        bind(statement, index, file.path); index += 1
        bind(statement, index, file.fileName); index += 1
        bind(statement, index, file.fileSize); index += 1
        bind(statement, index, file.modifiedAt.timeIntervalSince1970); index += 1
        bind(statement, index, file.hash); index += 1
        bind(statement, index, file.animeId.map { Int64($0) }); index += 1
        bind(statement, index, file.episodeId.map { Int64($0) }); index += 1
        bind(statement, index, file.animeTitle); index += 1
        bind(statement, index, file.episodeTitle); index += 1
        bind(statement, index, file.imageUrl); index += 1
        bind(statement, index, file.type); index += 1
        bind(statement, index, Int64(file.isMatched ? 1 : 0)); index += 1
        bind(statement, index, Int64(file.isMissing ? 1 : 0)); index += 1
        bind(statement, index, file.lastScannedAt.timeIntervalSince1970); index += 1
        bind(statement, index, file.duration); index += 1
        bind(statement, index, file.pixelWidth.map { Int64($0) }); index += 1
        bind(statement, index, file.pixelHeight.map { Int64($0) })
    }

    private func orderClause(for sort: LocalLibrarySort) -> String {
        switch sort {
        case .title:
            return """
                COALESCE(NULLIF(animeTitle, ''), fileName) COLLATE NOCASE ASC,
                fileName COLLATE NOCASE ASC, path COLLATE NOCASE ASC
                """
        case .fileName:
            return "fileName COLLATE NOCASE ASC, path COLLATE NOCASE ASC"
        case .fileSize:
            return "fileSize DESC, fileName COLLATE NOCASE ASC"
        case .path:
            return "path COLLATE NOCASE ASC"
        }
    }

    private func normalizedPath(_ path: String) throws -> String {
        guard !path.isEmpty else {
            throw LocalLibraryStoreError.invalidPath(path)
        }
        return URL(fileURLWithPath: path).standardizedFileURL.path
    }

    private func escapeLike(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "%", with: "\\%")
            .replacingOccurrences(of: "_", with: "\\_")
    }

    // MARK: - SQLite helpers

    private enum SQLiteValue {
        case string(String)
        case int64(Int64)
    }

    private func databaseOrThrow() -> OpaquePointer {
        guard let database else {
            fatalError("LocalLibraryStore database is closed")
        }
        return database
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(databaseOrThrow(), sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw LocalLibraryStoreError.database(lastErrorMessage())
        }
        return statement
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(databaseOrThrow(), sql, nil, nil, &errorPointer)
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorPointer)
            throw LocalLibraryStoreError.database(message)
        }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw LocalLibraryStoreError.database(lastErrorMessage())
        }
    }

    private func intValue(_ sql: String) throws -> Int {
        let statement = try prepare(sql)
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return Int(sqlite3_column_int64(statement, 0))
    }

    private func lastErrorMessage() -> String {
        guard let database else { return "database is closed" }
        return String(cString: sqlite3_errmsg(database))
    }

    private func bind(_ statement: OpaquePointer, values: [SQLiteValue]) throws {
        var index: Int32 = 1
        for value in values {
            switch value {
            case .string(let string):
                bind(statement, index, string)
            case .int64(let int):
                bind(statement, index, int)
            }
            index += 1
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, localLibrarySQLiteTransient)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Int64) {
        sqlite3_bind_int64(statement, index, value)
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Int64?) {
        if let value {
            sqlite3_bind_int64(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Double) {
        sqlite3_bind_double(statement, index, value)
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Double?) {
        if let value {
            sqlite3_bind_double(statement, index, value)
        } else {
            sqlite3_bind_null(statement, index)
        }
    }

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Data?) {
        guard let value, !value.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }
        value.withUnsafeBytes { buffer in
            sqlite3_bind_blob(
                statement,
                index,
                buffer.baseAddress,
                Int32(buffer.count),
                localLibrarySQLiteTransient
            )
        }
    }

    private func string(_ statement: OpaquePointer, _ index: Int32) -> String? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let text = sqlite3_column_text(statement, index) else {
            return nil
        }
        return String(cString: text)
    }

    private func optionalInt(_ statement: OpaquePointer, _ index: Int32) -> Int? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL else { return nil }
        return Int(sqlite3_column_int64(statement, index))
    }

    private func data(_ statement: OpaquePointer, _ index: Int32) -> Data? {
        guard sqlite3_column_type(statement, index) != SQLITE_NULL,
              let bytes = sqlite3_column_blob(statement, index) else {
            return nil
        }
        let count = Int(sqlite3_column_bytes(statement, index))
        guard count > 0 else { return Data() }
        return Data(bytes: bytes, count: count)
    }

    private func date(_ statement: OpaquePointer, _ index: Int32) -> Date {
        dateFromUnix(sqlite3_column_double(statement, index))
    }

    private func dateFromUnix(_ value: Double) -> Date {
        Date(timeIntervalSince1970: value)
    }
}
