import XCTest
import SQLite3

final class LocalLibraryTests: XCTestCase {

    private var databaseDirectory: URL!
    private var databaseURL: URL!
    private var store: LocalLibraryStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        databaseDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalLibraryTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: databaseDirectory, withIntermediateDirectories: true)
        databaseURL = databaseDirectory.appendingPathComponent("LocalLibrary.sqlite")
        store = try LocalLibraryStore(databaseURL: databaseURL)
    }

    override func tearDownWithError() throws {
        store = nil
        if let databaseDirectory {
            try? FileManager.default.removeItem(at: databaseDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeFile(
        path: String,
        folderId: Int64,
        size: Int64 = 1_024,
        modifiedAt: Date = Date(timeIntervalSince1970: 1_000),
        matched: Bool = false
    ) -> LocalLibraryFile {
        LocalLibraryFile(
            id: 0,
            folderId: folderId,
            path: path,
            fileName: (path as NSString).lastPathComponent,
            fileSize: size,
            modifiedAt: modifiedAt,
            hash: "hash",
            animeId: matched ? 100 : nil,
            episodeId: matched ? 200 : nil,
            animeTitle: matched ? "测试番剧" : nil,
            episodeTitle: matched ? "第1话" : nil,
            imageUrl: matched ? "https://example.com/a.jpg" : nil,
            type: matched ? "tvseries" : nil,
            isMatched: matched,
            isMissing: false,
            lastScannedAt: Date(timeIntervalSince1970: 2_000),
            duration: nil,
            pixelWidth: nil,
            pixelHeight: nil
        )
    }

    // MARK: - Store CRUD

    func testFolderAndFileCRUD() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: Data([1, 2, 3]))
        XCTAssertGreaterThan(folder.id, 0)
        XCTAssertEqual(try store.folders().count, 1)

        let file = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id))
        XCTAssertGreaterThan(file.id, 0)
        XCTAssertEqual(file.fileName, "01.mkv")
        XCTAssertFalse(file.isMatched)

        let fetched = try XCTUnwrap(store.file(path: "/tmp/LocalLibrary/Anime/01.mkv"))
        XCTAssertEqual(fetched.id, file.id)
        XCTAssertEqual(fetched.fileSize, 1_024)

        var stats = try store.statistics()
        XCTAssertEqual(stats.totalCount, 1)
        XCTAssertEqual(stats.matchedCount, 0)
        XCTAssertEqual(stats.unmatchedCount, 1)
        XCTAssertEqual(stats.folderCount, 1)

        _ = try store.updateMatch(
            fileId: file.id,
            outcome: .matched(
                LocalLibraryMatchInfo(
                    animeId: 10,
                    episodeId: 20,
                    animeTitle: "番剧",
                    episodeTitle: "第1话",
                    imageUrl: "https://example.com/p.jpg",
                    type: "tvseries"
                )
            )
        )

        let matched = try XCTUnwrap(store.file(id: file.id))
        XCTAssertTrue(matched.isMatched)
        XCTAssertEqual(matched.animeId, 10)
        XCTAssertEqual(matched.episodeId, 20)
        XCTAssertEqual(matched.animeTitle, "番剧")
        XCTAssertEqual(matched.imageUrl, "https://example.com/p.jpg")

        stats = try store.statistics()
        XCTAssertEqual(stats.matchedCount, 1)
        XCTAssertEqual(stats.unmatchedCount, 0)
    }

    func testPathIsUniqueAndUpsertPreservesID() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let first = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id))
        let second = try store.saveFile(
            makeFile(
                path: "/tmp/LocalLibrary/Anime/01.mkv",
                folderId: folder.id,
                size: 9_999,
                modifiedAt: Date(timeIntervalSince1970: 3_000)
            )
        )

        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(second.fileSize, 9_999)
        XCTAssertEqual(try store.files(query: LocalLibraryQuery()).count, 1)
    }

    func testDeletingFolderCascadesFilesAndDoesNotDeleteDisk() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id))
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/02.mkv", folderId: folder.id))

        XCTAssertEqual(try store.fileCounts()[folder.id], 2)
        let removedCount = try store.removeFolder(id: folder.id)
        XCTAssertEqual(removedCount, 2)
        XCTAssertTrue(try store.folders().isEmpty)
        XCTAssertNil(try store.file(path: "/tmp/LocalLibrary/Anime/01.mkv"))
        XCTAssertNil(try store.fileCounts()[folder.id])
    }

    func testDuplicateFolderPathUpdatesBookmark() throws {
        let first = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: Data([1]))
        let second = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: Data([2, 3]))
        XCTAssertEqual(first.id, second.id)
        XCTAssertEqual(try store.folders().count, 1)
        XCTAssertEqual(try store.folder(id: first.id)?.bookmark, Data([2, 3]))
    }

    func testMarkMissingAndRescanRestoresFile() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let file = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id))

        let marked = try store.markMissing(folderId: folder.id, keepingPaths: [])
        XCTAssertEqual(marked, 1)
        XCTAssertEqual(try store.statistics().missingCount, 1)
        XCTAssertTrue(try store.files(query: LocalLibraryQuery()).isEmpty)

        var scanned = makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id)
        scanned.id = file.id
        scanned.isMissing = false
        _ = try store.saveFile(scanned)

        XCTAssertEqual(try store.statistics().missingCount, 0)
        XCTAssertEqual(try store.files(query: LocalLibraryQuery()).count, 1)
    }

    func testReopenDatabaseIsIdempotent() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: Data([7]))
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id))

        store = nil
        let reopened = try LocalLibraryStore(databaseURL: databaseURL)
        store = reopened

        XCTAssertEqual(try reopened.folders().count, 1)
        XCTAssertEqual(try reopened.files(query: LocalLibraryQuery()).count, 1)
        XCTAssertEqual(try reopened.folder(id: folder.id)?.path, folder.path)
    }

    func testFailedMatchClearsPreviousMatchFields() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let file = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id, matched: true))

        _ = try store.updateMatch(fileId: file.id, outcome: .noResult)
        let updated = try XCTUnwrap(store.file(id: file.id))
        XCTAssertFalse(updated.isMatched)
        XCTAssertNil(updated.animeId)
        XCTAssertNil(updated.animeTitle)
        XCTAssertEqual(try store.unmatchedFiles().map(\.id), [file.id])
    }

    func testStoreSearchFilterAndFolderQuery() throws {
        let folderA = try store.addFolder(path: "/tmp/LocalLibrary/A", bookmark: nil)
        let folderB = try store.addFolder(path: "/tmp/LocalLibrary/B", bookmark: nil)

        var matched = makeFile(path: "/tmp/LocalLibrary/A/进击的巨人 第1话.mkv", folderId: folderA.id, matched: true)
        matched.animeTitle = "进击的巨人"
        matched.episodeTitle = "第1话"
        _ = try store.saveFile(matched)
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/A/Movie_1080p.mp4", folderId: folderA.id))
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/B/Other.mkv", folderId: folderB.id))

        var query = LocalLibraryQuery()
        query.searchText = "巨人"
        var result = try store.files(query: query)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.animeTitle, "进击的巨人")

        query = LocalLibraryQuery()
        query.searchText = "movie"
        result = try store.files(query: query)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.fileName, "Movie_1080p.mp4")

        query = LocalLibraryQuery()
        query.filter = .unmatched
        result = try store.files(query: query)
        XCTAssertEqual(result.count, 2)

        query = LocalLibraryQuery()
        query.folderId = folderB.id
        result = try store.files(query: query)
        XCTAssertEqual(result.count, 1)
        XCTAssertEqual(result.first?.folderId, folderB.id)
    }

    // MARK: - Query logic (pure)

    func testQueryLogicSearchFilterAndSort() {
        let folderId: Int64 = 1
        var matched = makeFile(path: "/tmp/B/进击的巨人 第1话.mkv", folderId: folderId, matched: true)
        matched.id = 2
        matched.animeTitle = "进击的巨人"
        matched.episodeTitle = "第1话"

        var unmatched = makeFile(path: "/tmp/A/Movie.MKV", folderId: folderId)
        unmatched.id = 1
        unmatched.fileSize = 5_000

        var otherFolder = makeFile(path: "/tmp/C/Other.mp4", folderId: 2)
        otherFolder.id = 3

        let files = [matched, unmatched, otherFolder]

        var query = LocalLibraryQuery()
        query.searchText = "巨人"
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [2])

        query = LocalLibraryQuery()
        query.searchText = "movie"
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [1])

        query = LocalLibraryQuery()
        query.filter = .unmatched
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [1, 3])

        query = LocalLibraryQuery()
        query.folderId = 1
        query.filter = .matched
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [2])

        query = LocalLibraryQuery()
        query.sort = .fileSize
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [1, 2, 3])
    }

    // MARK: - Scan rules

    func testVideoExtensionFiltering() {
        XCTAssertTrue(LocalLibraryScanRules.isVideoFileName("01.mkv"))
        XCTAssertTrue(LocalLibraryScanRules.isVideoFileName("02.MP4"))
        XCTAssertTrue(LocalLibraryScanRules.isVideoFileName("03.m2ts"))
        XCTAssertTrue(LocalLibraryScanRules.isVideoFileName("04.RMVB"))
        XCTAssertFalse(LocalLibraryScanRules.isVideoFileName("readme.txt"))
        XCTAssertFalse(LocalLibraryScanRules.isVideoFileName("cover.jpg"))
        XCTAssertFalse(LocalLibraryScanRules.isVideoFileName("video"))
        XCTAssertTrue(LocalLibraryScanRules.isHiddenFileName(".hidden.mp4"))
        XCTAssertFalse(LocalLibraryScanRules.isHiddenFileName("visible.mp4"))
    }

    func testIncrementalDecision() {
        let existing = makeFile(
            path: "/tmp/a.mkv",
            folderId: 1,
            size: 100,
            modifiedAt: Date(timeIntervalSince1970: 1_000)
        )
        XCTAssertFalse(
            LocalLibraryScanRules.needsUpdate(
                existing: existing,
                fileSize: 100,
                modifiedAt: Date(timeIntervalSince1970: 1_000.5)
            )
        )
        XCTAssertTrue(
            LocalLibraryScanRules.needsUpdate(
                existing: existing,
                fileSize: 101,
                modifiedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
        XCTAssertTrue(
            LocalLibraryScanRules.needsUpdate(
                existing: existing,
                fileSize: 100,
                modifiedAt: Date(timeIntervalSince1970: 1_002)
            )
        )
        XCTAssertTrue(
            LocalLibraryScanRules.needsUpdate(
                existing: nil,
                fileSize: 100,
                modifiedAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        var missing = existing
        missing.isMissing = true
        XCTAssertTrue(
            LocalLibraryScanRules.needsUpdate(
                existing: missing,
                fileSize: 100,
                modifiedAt: Date(timeIntervalSince1970: 1_000)
            )
        )

        var hashFailed = existing
        hashFailed.hash = nil
        XCTAssertTrue(
            LocalLibraryScanRules.needsUpdate(
                existing: hashFailed,
                fileSize: 100,
                modifiedAt: Date(timeIntervalSince1970: 1_000)
            )
        )
    }

    func testEnumerationSkipsHiddenFilesAndPackages() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalLibraryScan-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }

        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Sub", isDirectory: true),
            withIntermediateDirectories: true
        )
        try FileManager.default.createDirectory(
            at: root.appendingPathComponent("Fake.app", isDirectory: true),
            withIntermediateDirectories: true
        )

        try Data("a".utf8).write(to: root.appendingPathComponent("01.mp4"))
        try Data("b".utf8).write(to: root.appendingPathComponent("Sub/02.MKV"))
        try Data("c".utf8).write(to: root.appendingPathComponent("readme.txt"))
        try Data("d".utf8).write(to: root.appendingPathComponent(".hidden.mp4"))
        try Data("e".utf8).write(to: root.appendingPathComponent("Sub/.hidden.mkv"))
        try Data("f".utf8).write(to: root.appendingPathComponent("Fake.app/inside.mp4"))

        let items = try LocalLibraryScanRules.enumerateVideoFiles(in: root)
        let names = Set(items.map(\.fileName))
        XCTAssertEqual(names, Set(["01.mp4", "02.MKV"]))
        XCTAssertTrue(items.allSatisfy { $0.fileSize > 0 })
    }

    // MARK: - Match decoding/evaluation

    func testMatchDecodingAndEvaluationForExactMatch() throws {
        let json = """
        {
          "isMatched": true,
          "matches": [
            {
              "episodeId": 456,
              "animeId": 123,
              "animeTitle": "测试番剧",
              "episodeTitle": "第1话",
              "type": "tvseries",
              "typeDescription": "TV",
              "shift": 0,
              "imageUrl": "https://example.com/poster.jpg"
            }
          ]
        }
        """.data(using: .utf8)!

        let collection = try JSONDecoder().decode(MatchCollection.self, from: json)
        let outcome = LocalLibraryMatchEvaluator.evaluate(collection)
        guard case .matched(let info) = outcome else {
            return XCTFail("应接受唯一的精确匹配")
        }
        XCTAssertEqual(info.animeId, 123)
        XCTAssertEqual(info.episodeId, 456)
        XCTAssertEqual(info.animeTitle, "测试番剧")
        XCTAssertEqual(info.episodeTitle, "第1话")
        XCTAssertEqual(info.imageUrl, "https://example.com/poster.jpg")
        XCTAssertEqual(info.type, "tvseries")
    }

    func testMatchEvaluationRejectsNotMatchedAndMultipleResults() throws {
        let notMatchedJSON = """
        {"isMatched": false, "matches": [{"episodeId": 1, "animeId": 2, "animeTitle": "A", "episodeTitle": "1"}]}
        """.data(using: .utf8)!
        let notMatched = try JSONDecoder().decode(MatchCollection.self, from: notMatchedJSON)
        XCTAssertEqual(LocalLibraryMatchEvaluator.evaluate(notMatched), .notMatched)

        let multipleJSON = """
        {"isMatched": true, "matches": [
          {"episodeId": 1, "animeId": 2, "animeTitle": "A", "episodeTitle": "1"},
          {"episodeId": 3, "animeId": 4, "animeTitle": "B", "episodeTitle": "2"}
        ]}
        """.data(using: .utf8)!
        let multiple = try JSONDecoder().decode(MatchCollection.self, from: multipleJSON)
        XCTAssertEqual(LocalLibraryMatchEvaluator.evaluate(multiple), .multipleResults(2))

        let empty = try JSONDecoder().decode(
            MatchCollection.self,
            from: #"{"isMatched": false, "matches": []}"#.data(using: .utf8)!
        )
        XCTAssertEqual(LocalLibraryMatchEvaluator.evaluate(empty), .noResult)
        XCTAssertEqual(LocalLibraryMatchEvaluator.evaluate(nil), .noResult)
    }

    func testMalformedMatchResponseThrows() {
        let data = #"[]"#.data(using: .utf8)!
        XCTAssertThrowsError(try JSONDecoder().decode(MatchCollection.self, from: data))
    }

    func testScanProgressFraction() {
        XCTAssertEqual(LocalLibraryScanProgress(scanned: 0, total: 0, currentFileName: "").fraction, 0)
        XCTAssertEqual(LocalLibraryScanProgress(scanned: 1, total: 4, currentFileName: "a").fraction, 0.25)
        XCTAssertEqual(LocalLibraryScanProgress(scanned: 9, total: 4, currentFileName: "a").fraction, 1)
    }

    // MARK: - Rescan metadata preservation

    func testRescanPreservesMatchMetadataWhenContentUnchanged() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let saved = try store.saveFile(
            makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id, matched: true)
        )
        let existing = try XCTUnwrap(store.file(id: saved.id))

        let scanned = LocalLibraryFile.makeScanned(
            folderId: folder.id,
            path: existing.path,
            fileName: existing.fileName,
            fileSize: existing.fileSize,
            modifiedAt: existing.modifiedAt,
            hash: existing.hash,
            existing: existing,
            now: Date(timeIntervalSince1970: 5_000)
        )
        XCTAssertTrue(scanned.isMatched)
        XCTAssertEqual(scanned.animeId, 100)
        XCTAssertEqual(scanned.episodeId, 200)
        XCTAssertEqual(scanned.animeTitle, "测试番剧")
        XCTAssertEqual(scanned.episodeTitle, "第1话")
        XCTAssertEqual(scanned.imageUrl, "https://example.com/a.jpg")
        XCTAssertEqual(scanned.type, "tvseries")

        let updated = try store.saveFile(scanned)
        XCTAssertTrue(updated.isMatched)
        XCTAssertEqual(updated.id, existing.id)
        XCTAssertEqual(updated.animeId, 100)
    }

    func testRescanPreservesMatchWhenMissingFileReturnsUnchanged() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let saved = try store.saveFile(
            makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id, matched: true)
        )
        _ = try store.markMissing(folderId: folder.id, keepingPaths: [])
        let missing = try XCTUnwrap(store.file(id: saved.id))
        XCTAssertTrue(missing.isMissing)

        let scanned = LocalLibraryFile.makeScanned(
            folderId: folder.id,
            path: missing.path,
            fileName: missing.fileName,
            fileSize: missing.fileSize,
            modifiedAt: missing.modifiedAt,
            hash: missing.hash,
            existing: missing,
            now: Date()
        )
        XCTAssertFalse(scanned.isMissing)
        XCTAssertTrue(scanned.isMatched)
        XCTAssertEqual(scanned.animeTitle, "测试番剧")
    }

    func testRescanClearsMatchWhenContentChanged() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let saved = try store.saveFile(
            makeFile(path: "/tmp/LocalLibrary/Anime/01.mkv", folderId: folder.id, matched: true)
        )
        let existing = try XCTUnwrap(store.file(id: saved.id))

        let sizeChanged = LocalLibraryFile.makeScanned(
            folderId: folder.id,
            path: existing.path,
            fileName: existing.fileName,
            fileSize: existing.fileSize + 1,
            modifiedAt: existing.modifiedAt,
            hash: existing.hash,
            existing: existing,
            now: Date()
        )
        XCTAssertFalse(sizeChanged.isMatched)
        XCTAssertNil(sizeChanged.animeId)

        let hashChanged = LocalLibraryFile.makeScanned(
            folderId: folder.id,
            path: existing.path,
            fileName: existing.fileName,
            fileSize: existing.fileSize,
            modifiedAt: existing.modifiedAt,
            hash: "different-hash",
            existing: existing,
            now: Date()
        )
        XCTAssertFalse(hashChanged.isMatched)
        XCTAssertNil(hashChanged.animeTitle)

        let hashFailed = LocalLibraryFile.makeScanned(
            folderId: folder.id,
            path: existing.path,
            fileName: existing.fileName,
            fileSize: existing.fileSize,
            modifiedAt: existing.modifiedAt,
            hash: nil,
            existing: existing,
            now: Date()
        )
        XCTAssertTrue(hashFailed.isMatched)
        XCTAssertEqual(hashFailed.animeId, 100)
        XCTAssertEqual(hashFailed.hash, existing.hash)
    }

    // MARK: - Nested folders

    func testSaveFilePreservesOriginalFolderIdForNestedFolder() throws {
        let parent = try store.addFolder(path: "/tmp/LocalLibrary/Anime", bookmark: nil)
        let child = try store.addFolder(path: "/tmp/LocalLibrary/Anime/Season1", bookmark: nil)
        let saved = try store.saveFile(
            makeFile(path: "/tmp/LocalLibrary/Anime/Season1/01.mkv", folderId: parent.id)
        )
        XCTAssertEqual(saved.folderId, parent.id)

        let again = try store.saveFile(
            makeFile(path: "/tmp/LocalLibrary/Anime/Season1/01.mkv", folderId: child.id, size: 2_048)
        )
        XCTAssertEqual(again.folderId, parent.id)
        XCTAssertEqual(again.fileSize, 2_048)

        // 子文件夹扫描范围没有该记录时，不应把父文件夹归属的记录标为缺失。
        XCTAssertEqual(try store.markMissing(folderId: child.id, keepingPaths: []), 0)
        XCTAssertEqual(try store.statistics().missingCount, 0)
    }

    func testFolderRelationshipDetection() {
        XCTAssertEqual(
            LocalLibraryFolderRules.relationship(
                newPath: "/tmp/LocalLibrary/Anime",
                existingPath: "/tmp/LocalLibrary/Anime"
            ),
            .same
        )
        XCTAssertEqual(
            LocalLibraryFolderRules.relationship(
                newPath: "/tmp/LocalLibrary",
                existingPath: "/tmp/LocalLibrary/Anime"
            ),
            .newIsAncestor
        )
        XCTAssertEqual(
            LocalLibraryFolderRules.relationship(
                newPath: "/tmp/LocalLibrary/Anime/Season1",
                existingPath: "/tmp/LocalLibrary/Anime"
            ),
            .newIsDescendant
        )
        XCTAssertEqual(
            LocalLibraryFolderRules.relationship(
                newPath: "/tmp/Other",
                existingPath: "/tmp/LocalLibrary/Anime"
            ),
            .none
        )
        // 前缀相同的兄弟目录不能被当成父子关系。
        XCTAssertEqual(
            LocalLibraryFolderRules.relationship(
                newPath: "/tmp/LocalLibrary/Anime2",
                existingPath: "/tmp/LocalLibrary/Anime"
            ),
            .none
        )
    }

    // MARK: - Missing files

    func testMissingFilterIncludesMissingAndCleanup() throws {
        let folderA = try store.addFolder(path: "/tmp/LocalLibrary/A", bookmark: nil)
        let folderB = try store.addFolder(path: "/tmp/LocalLibrary/B", bookmark: nil)
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/A/01.mkv", folderId: folderA.id))
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/B/02.mkv", folderId: folderB.id))

        _ = try store.markMissing(folderId: folderA.id, keepingPaths: [])
        XCTAssertEqual(try store.statistics().missingCount, 1)

        var query = LocalLibraryQuery()
        XCTAssertEqual(try store.files(query: query).map(\.folderId), [folderB.id])

        query.filter = .missing
        XCTAssertEqual(try store.files(query: query).map(\.folderId), [folderA.id])

        query = LocalLibraryQuery()
        query.includesMissing = true
        XCTAssertEqual(try store.files(query: query).count, 2)

        XCTAssertEqual(try store.deleteMissingFiles(folderId: folderA.id), 1)
        XCTAssertEqual(try store.statistics().missingCount, 0)
        XCTAssertEqual(try store.files(query: LocalLibraryQuery()).map(\.folderId), [folderB.id])

        _ = try store.markMissing(folderId: folderB.id, keepingPaths: [])
        XCTAssertEqual(try store.deleteMissingFiles(), 1)
        XCTAssertEqual(try store.statistics().totalCount, 0)
    }

    func testDeleteSelectedFilesOnly() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/A", bookmark: nil)
        let first = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/A/01.mkv", folderId: folder.id))
        _ = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/A/02.mkv", folderId: folder.id))

        XCTAssertEqual(try store.deleteFiles(ids: [first.id]), 1)
        XCTAssertNil(try store.file(id: first.id))
        XCTAssertEqual(try store.files(query: LocalLibraryQuery()).count, 1)
    }

    func testQueryLogicMissingFilter() {
        var missing = makeFile(path: "/tmp/A/Missing.mkv", folderId: 1)
        missing.id = 1
        missing.isMissing = true
        var normal = makeFile(path: "/tmp/A/Normal.mkv", folderId: 1)
        normal.id = 2
        let files = [missing, normal]

        var query = LocalLibraryQuery()
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [2])

        query.includesMissing = true
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [1, 2])

        query = LocalLibraryQuery()
        query.filter = .missing
        XCTAssertEqual(LocalLibraryQueryLogic.apply(files, query: query).map(\.id), [1])
    }

    // MARK: - Manual match

    func testManualMatchAndClear() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/A", bookmark: nil)
        let file = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/A/01.mkv", folderId: folder.id))

        let matched = try store.applyManualMatch(
            fileId: file.id,
            info: LocalLibraryMatchInfo(
                animeId: 9,
                episodeId: 99,
                animeTitle: "手动番剧",
                episodeTitle: "第3话",
                imageUrl: nil,
                type: "tvseries"
            )
        )
        XCTAssertTrue(matched?.isMatched == true)
        XCTAssertEqual(matched?.animeId, 9)
        XCTAssertEqual(matched?.episodeId, 99)
        XCTAssertEqual(matched?.animeTitle, "手动番剧")

        let cleared = try store.clearMatch(fileId: file.id)
        XCTAssertFalse(cleared?.isMatched == true)
        XCTAssertNil(cleared?.animeId)
        XCTAssertNil(cleared?.episodeTitle)
    }

    // MARK: - Grouping

    func testGroupingByAnimeAndEpisodeOrdering() {
        let folderId: Int64 = 1
        var episode10 = makeFile(path: "/tmp/A/10.mkv", folderId: folderId, matched: true)
        episode10.id = 10
        episode10.episodeTitle = "第10话"
        episode10.animeId = 100

        var episode2 = makeFile(path: "/tmp/A/02.mkv", folderId: folderId, matched: true)
        episode2.id = 2
        episode2.episodeTitle = "第2话"
        episode2.animeId = 100
        episode2.isMissing = true

        var episode1 = makeFile(path: "/tmp/A/01.mkv", folderId: folderId, matched: true)
        episode1.id = 1
        episode1.episodeTitle = "第1话"
        episode1.animeId = 100

        var otherAnime = makeFile(path: "/tmp/A/Other.mkv", folderId: folderId, matched: true)
        otherAnime.id = 20
        otherAnime.animeId = 200
        otherAnime.animeTitle = "另一部"

        var unmatched = makeFile(path: "/tmp/A/Movie.mkv", folderId: folderId)
        unmatched.id = 30

        let cards = LocalLibraryGrouping.cards(
            from: [episode10, episode2, episode1, otherAnime, unmatched],
            sort: .title
        )
        XCTAssertEqual(cards.count, 3)

        let group = cards.compactMap { card -> LocalLibraryAnimeGroup? in
            if case .group(let group) = card, group.animeId == 100 { return group }
            return nil
        }.first
        XCTAssertEqual(group?.files.map(\.id), [1, 2, 10])
        XCTAssertEqual(group?.episodeCount, 3)
        XCTAssertEqual(group?.totalSize, 3 * 1_024)
        XCTAssertEqual(group?.missingCount, 1)
        XCTAssertEqual(group?.primaryFile?.id, 1)

        XCTAssertEqual(
            cards.filter {
                if case .file = $0 { return true }
                return false
            }.count,
            1
        )
    }

    func testEpisodeNumberParsingAndOrdering() {
        XCTAssertEqual(LocalLibraryGrouping.episodeNumber(from: "第12话"), 12)
        XCTAssertEqual(LocalLibraryGrouping.episodeNumber(from: "EP03"), 3)
        XCTAssertEqual(LocalLibraryGrouping.episodeNumber(from: "S02E05"), 5)
        XCTAssertEqual(LocalLibraryGrouping.episodeNumber(from: "12.5"), 12.5)
        XCTAssertNil(LocalLibraryGrouping.episodeNumber(from: "Movie"))

        var tenth = makeFile(path: "/tmp/A/10.mkv", folderId: 1, matched: true)
        tenth.id = 10
        tenth.episodeTitle = "第10话"
        var second = makeFile(path: "/tmp/A/02.mkv", folderId: 1, matched: true)
        second.id = 2
        second.episodeTitle = "第2话"
        let ordered = LocalLibraryGrouping.orderedEpisodes([tenth, second])
        XCTAssertEqual(ordered.map(\.id), [2, 10])
    }

    // MARK: - Media metadata

    func testMediaMetadataPersistenceAndFormatting() throws {
        let folder = try store.addFolder(path: "/tmp/LocalLibrary/A", bookmark: nil)
        let file = try store.saveFile(makeFile(path: "/tmp/LocalLibrary/A/01.mkv", folderId: folder.id))

        _ = try store.updateMediaMetadata(fileId: file.id, duration: 1_425, width: 1_920, height: 1_080)
        let fetched = try XCTUnwrap(store.file(id: file.id))
        XCTAssertEqual(fetched.duration, 1_425)
        XCTAssertEqual(fetched.pixelWidth, 1_920)
        XCTAssertEqual(fetched.pixelHeight, 1_080)
        XCTAssertEqual(fetched.mediaMetadata.durationText, "23:45")
        XCTAssertEqual(fetched.mediaMetadata.resolutionText, "1080p")
        XCTAssertEqual(fetched.mediaMetadata.displayText, "23:45 · 1080p")

        let scanned = LocalLibraryFile.makeScanned(
            folderId: folder.id,
            path: fetched.path,
            fileName: fetched.fileName,
            fileSize: fetched.fileSize,
            modifiedAt: fetched.modifiedAt,
            hash: fetched.hash,
            existing: fetched,
            now: Date()
        )
        XCTAssertEqual(scanned.duration, 1_425)
        XCTAssertEqual(scanned.pixelWidth, 1_920)
        XCTAssertEqual(scanned.pixelHeight, 1_080)
    }

    func testMediaMetadataFormattingEdgeCases() {
        XCTAssertNil(LocalLibraryMediaMetadata().durationText)
        XCTAssertNil(LocalLibraryMediaMetadata().resolutionText)
        XCTAssertEqual(
            LocalLibraryMediaMetadata(duration: 65, width: 1_280, height: 720).displayText,
            "1:05 · 720p"
        )
        XCTAssertEqual(
            LocalLibraryMediaMetadata(duration: 3_661, width: 3_840, height: 2_160).displayText,
            "1:01:01 · 4K"
        )
    }

    // MARK: - Cancellation

    func testEnumerationHonorsCancellation() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent("LocalLibraryCancel-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: root) }
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try Data("a".utf8).write(to: root.appendingPathComponent("01.mp4"))

        XCTAssertThrowsError(
            try LocalLibraryScanRules.enumerateVideoFiles(in: root, shouldCancel: { true })
        ) { error in
            XCTAssertTrue(error is CancellationError)
        }
    }

    // MARK: - Migration

    func testLegacyDatabaseWithoutMediaMetadataColumnsMigrates() throws {
        let legacyURL = databaseDirectory.appendingPathComponent("Legacy.sqlite")
        var database: OpaquePointer?
        XCTAssertEqual(sqlite3_open(legacyURL.path, &database), SQLITE_OK)
        defer { sqlite3_close(database) }

        let schema = """
            CREATE TABLE folders (
                id INTEGER PRIMARY KEY AUTOINCREMENT,
                path TEXT NOT NULL UNIQUE,
                bookmark BLOB,
                addedAt REAL NOT NULL
            );
            CREATE TABLE files (
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
                lastScannedAt REAL NOT NULL DEFAULT 0
            );
            INSERT INTO folders(path, bookmark, addedAt) VALUES('/tmp/LocalLibrary/Legacy', NULL, 1000);
            INSERT INTO files(
                folderId, path, fileName, fileSize, modifiedAt, hash, isMatched, isMissing, lastScannedAt
            ) VALUES(1, '/tmp/LocalLibrary/Legacy/01.mkv', '01.mkv', 1024, 1000, 'hash', 1, 0, 2000);
            """
        XCTAssertEqual(sqlite3_exec(database, schema, nil, nil, nil), SQLITE_OK)
        sqlite3_close(database)
        database = nil

        let migrated = try LocalLibraryStore(databaseURL: legacyURL)
        let file = try XCTUnwrap(migrated.file(id: 1))
        XCTAssertEqual(file.fileName, "01.mkv")
        XCTAssertTrue(file.isMatched)
        XCTAssertNil(file.duration)
        XCTAssertNil(file.pixelWidth)

        _ = try migrated.updateMediaMetadata(fileId: 1, duration: 90, width: 640, height: 480)
        let updated = try XCTUnwrap(migrated.file(id: 1))
        XCTAssertEqual(updated.duration, 90)
        XCTAssertEqual(updated.pixelWidth, 640)
        XCTAssertEqual(updated.pixelHeight, 480)
    }
}
