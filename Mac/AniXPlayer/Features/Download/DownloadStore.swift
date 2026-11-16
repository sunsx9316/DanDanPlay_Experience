//
//  DownloadStore.swift
//  AniXPlayer
//
//  macOS：下载任务 SQLite 持久化。
//  数据库位于 ~/Library/Application Support/AniXPlayer/Downloads.sqlite。
//  与本地媒体库（LocalLibrary.sqlite）完全独立。
//

import Foundation
import SQLite3

enum DownloadStoreError: LocalizedError {
    case openDatabase(String)
    case database(String)
    case invalidTask(String)

    var errorDescription: String? {
        switch self {
        case .openDatabase(let message):
            return String(format: NSLocalizedString("无法打开下载数据库：%@", comment: ""), message)
        case .database(let message):
            return String(format: NSLocalizedString("下载数据库错误：%@", comment: ""), message)
        case .invalidTask(let message):
            return String(format: NSLocalizedString("下载任务无效：%@", comment: ""), message)
        }
    }
}

private let downloadSQLiteTransient = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

private let downloadTaskColumns = """
    id, kind, source, title, savePath, status, progress, \
    downloadedBytes, totalBytes, downloadSpeed, uploadSpeed, etaSeconds, \
    errorMessage, createdAt, updatedAt, engineTaskID, filePaths, \
    isStreaming, streamPath, savePathBookmark
    """

final class DownloadStore {

    static let defaultDatabaseURL: URL = {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? URL(fileURLWithPath: NSHomeDirectory()).appendingPathComponent("Library/Application Support")
        return base
            .appendingPathComponent("AniXPlayer", isDirectory: true)
            .appendingPathComponent("Downloads.sqlite", isDirectory: false)
    }()

    let databaseURL: URL

    private var database: OpaquePointer?
    private let lock = NSLock()

    init(databaseURL: URL? = nil) throws {
        let url = databaseURL ?? Self.defaultDatabaseURL
        self.databaseURL = url

        let directory = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: directory.path) {
            try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        }

        var db: OpaquePointer?
        let flags = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX
        let result = sqlite3_open_v2(url.path, &db, flags, nil)
        guard result == SQLITE_OK, let opened = db else {
            let message = db.flatMap { String(cString: sqlite3_errmsg($0)) } ?? "sqlite3_open_v2 failed (\(result))"
            if let db { sqlite3_close(db) }
            throw DownloadStoreError.openDatabase(message)
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
        try execute("PRAGMA journal_mode = WAL")
        try execute("PRAGMA synchronous = NORMAL")

        try execute("""
            CREATE TABLE IF NOT EXISTS tasks (
                id TEXT PRIMARY KEY,
                kind TEXT NOT NULL,
                source TEXT NOT NULL,
                title TEXT NOT NULL DEFAULT '',
                savePath TEXT NOT NULL,
                status TEXT NOT NULL,
                progress REAL NOT NULL DEFAULT 0,
                downloadedBytes INTEGER NOT NULL DEFAULT 0,
                totalBytes INTEGER NOT NULL DEFAULT 0,
                downloadSpeed INTEGER NOT NULL DEFAULT 0,
                uploadSpeed INTEGER NOT NULL DEFAULT 0,
                etaSeconds INTEGER,
                errorMessage TEXT,
                createdAt REAL NOT NULL,
                updatedAt REAL NOT NULL,
                engineTaskID TEXT,
                filePaths TEXT NOT NULL DEFAULT '[]',
                isStreaming INTEGER NOT NULL DEFAULT 0,
                streamPath TEXT,
                savePathBookmark BLOB
            )
            """)

        try execute("CREATE INDEX IF NOT EXISTS idx_download_tasks_status ON tasks(status)")
        try execute("CREATE INDEX IF NOT EXISTS idx_download_tasks_createdAt ON tasks(createdAt)")

        if try intValue("PRAGMA user_version") < 1 {
            try execute("PRAGMA user_version = 1")
        }
    }

    // MARK: - CRUD

    func allTasks() throws -> [DownloadTask] {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("""
            SELECT \(downloadTaskColumns) FROM tasks
            ORDER BY createdAt DESC, updatedAt DESC
            """)
        defer { sqlite3_finalize(statement) }
        return try readTasks(statement)
    }

    func tasks(status: DownloadTaskStatus) throws -> [DownloadTask] {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("""
            SELECT \(downloadTaskColumns) FROM tasks
            WHERE status = ?
            ORDER BY createdAt DESC, updatedAt DESC
            """)
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, status.rawValue)
        return try readTasks(statement)
    }

    func task(id: UUID) throws -> DownloadTask? {
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("SELECT \(downloadTaskColumns) FROM tasks WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id.uuidString)
        if sqlite3_step(statement) == SQLITE_ROW {
            return try readTask(statement)
        }
        return nil
    }

    @discardableResult
    func save(_ task: DownloadTask) throws -> DownloadTask {
        lock.lock()
        defer { lock.unlock() }
        try saveUnlocked(task)
        return try taskUnlocked(id: task.id) ?? task
    }

    func save(_ tasks: [DownloadTask]) throws {
        guard !tasks.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        try execute("BEGIN IMMEDIATE")
        do {
            for task in tasks {
                try saveUnlocked(task)
            }
            try execute("COMMIT")
        } catch {
            try? execute("ROLLBACK")
            throw error
        }
    }

    func delete(id: UUID) throws {
        try delete(ids: [id])
    }

    func delete(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        let statement = try prepare("DELETE FROM tasks WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        for id in ids {
            sqlite3_reset(statement)
            sqlite3_clear_bindings(statement)
            bind(statement, 1, id.uuidString)
            try stepDone(statement)
        }
    }

    func count() throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        return try intValue("SELECT COUNT(*) FROM tasks")
    }

    // MARK: - Unlocked

    private func saveUnlocked(_ task: DownloadTask) throws {
        guard !task.id.uuidString.isEmpty else {
            throw DownloadStoreError.invalidTask("missing id")
        }
        let filePathsData = try JSONEncoder().encode(task.filePaths)
        let filePaths = String(data: filePathsData, encoding: .utf8) ?? "[]"

        let statement = try prepare("""
            INSERT OR REPLACE INTO tasks(
                id, kind, source, title, savePath, status, progress,
                downloadedBytes, totalBytes, downloadSpeed, uploadSpeed, etaSeconds,
                errorMessage, createdAt, updatedAt, engineTaskID, filePaths,
                isStreaming, streamPath, savePathBookmark
            ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
            """)
        defer { sqlite3_finalize(statement) }

        var index: Int32 = 1
        bind(statement, index, task.id.uuidString); index += 1
        bind(statement, index, task.kind.rawValue); index += 1
        bind(statement, index, task.source); index += 1
        bind(statement, index, task.title); index += 1
        bind(statement, index, task.savePath); index += 1
        bind(statement, index, task.status.rawValue); index += 1
        bind(statement, index, task.normalizedProgress); index += 1
        bind(statement, index, max(0, task.downloadedBytes)); index += 1
        bind(statement, index, max(0, task.totalBytes)); index += 1
        bind(statement, index, max(0, task.downloadSpeed)); index += 1
        bind(statement, index, max(0, task.uploadSpeed)); index += 1
        bind(statement, index, task.etaSeconds.map { Int64($0) }); index += 1
        bind(statement, index, task.errorMessage); index += 1
        bind(statement, index, task.createdAt.timeIntervalSince1970); index += 1
        bind(statement, index, task.updatedAt.timeIntervalSince1970); index += 1
        bind(statement, index, task.engineTaskID); index += 1
        bind(statement, index, filePaths); index += 1
        bind(statement, index, Int64(task.isStreaming ? 1 : 0)); index += 1
        bind(statement, index, task.streamPath); index += 1
        bind(statement, index, task.savePathBookmark)

        try stepDone(statement)
    }

    private func taskUnlocked(id: UUID) throws -> DownloadTask? {
        let statement = try prepare("SELECT \(downloadTaskColumns) FROM tasks WHERE id = ?")
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, id.uuidString)
        if sqlite3_step(statement) == SQLITE_ROW {
            return try readTask(statement)
        }
        return nil
    }

    private func readTasks(_ statement: OpaquePointer) throws -> [DownloadTask] {
        var tasks: [DownloadTask] = []
        while sqlite3_step(statement) == SQLITE_ROW {
            tasks.append(try readTask(statement))
        }
        return tasks
    }

    private func readTask(_ statement: OpaquePointer) throws -> DownloadTask {
        let idString = string(statement, 0) ?? ""
        guard let id = UUID(uuidString: idString) else {
            throw DownloadStoreError.invalidTask("bad id \(idString)")
        }

        let kind = DownloadTaskKind(rawValue: string(statement, 1) ?? "") ?? .http
        let status = DownloadTaskStatus(rawValue: string(statement, 5) ?? "") ?? .failed
        let filePathsString = string(statement, 16) ?? "[]"
        var filePaths: [String] = []
        if let data = filePathsString.data(using: .utf8) {
            filePaths = (try? JSONDecoder().decode([String].self, from: data)) ?? []
        }

        return DownloadTask(
            id: id,
            kind: kind,
            source: string(statement, 2) ?? "",
            title: string(statement, 3) ?? "",
            savePath: string(statement, 4) ?? "",
            status: status,
            progress: min(max(sqlite3_column_double(statement, 6), 0), 1),
            downloadedBytes: sqlite3_column_int64(statement, 7),
            totalBytes: sqlite3_column_int64(statement, 8),
            downloadSpeed: sqlite3_column_int64(statement, 9),
            uploadSpeed: sqlite3_column_int64(statement, 10),
            etaSeconds: optionalInt(statement, 11),
            errorMessage: string(statement, 12),
            createdAt: date(statement, 13),
            updatedAt: date(statement, 14),
            engineTaskID: string(statement, 15),
            filePaths: filePaths,
            isStreaming: sqlite3_column_int(statement, 17) != 0,
            streamPath: string(statement, 18),
            savePathBookmark: data(statement, 19)
        )
    }

    // MARK: - SQLite helpers

    private func databaseOrThrow() -> OpaquePointer {
        guard let database else {
            fatalError("DownloadStore database is closed")
        }
        return database
    }

    private func prepare(_ sql: String) throws -> OpaquePointer {
        var statement: OpaquePointer?
        let result = sqlite3_prepare_v2(databaseOrThrow(), sql, -1, &statement, nil)
        guard result == SQLITE_OK, let statement else {
            throw DownloadStoreError.database(lastErrorMessage())
        }
        return statement
    }

    private func execute(_ sql: String) throws {
        var errorPointer: UnsafeMutablePointer<CChar>?
        let result = sqlite3_exec(databaseOrThrow(), sql, nil, nil, &errorPointer)
        guard result == SQLITE_OK else {
            let message = errorPointer.map { String(cString: $0) } ?? lastErrorMessage()
            sqlite3_free(errorPointer)
            throw DownloadStoreError.database(message)
        }
    }

    private func stepDone(_ statement: OpaquePointer) throws {
        let result = sqlite3_step(statement)
        guard result == SQLITE_DONE || result == SQLITE_ROW else {
            throw DownloadStoreError.database(lastErrorMessage())
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

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: String?) {
        if let value {
            sqlite3_bind_text(statement, index, value, -1, downloadSQLiteTransient)
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

    private func bind(_ statement: OpaquePointer, _ index: Int32, _ value: Data?) {
        guard let value, !value.isEmpty else {
            sqlite3_bind_null(statement, index)
            return
        }
        value.withUnsafeBytes { buffer in
            _ = sqlite3_bind_blob(
                statement,
                index,
                buffer.baseAddress,
                Int32(buffer.count),
                downloadSQLiteTransient
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
        Date(timeIntervalSince1970: sqlite3_column_double(statement, index))
    }
}
