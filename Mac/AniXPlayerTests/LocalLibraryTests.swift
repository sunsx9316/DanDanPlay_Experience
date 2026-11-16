import XCTest

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
            lastScannedAt: Date(timeIntervalSince1970: 2_000)
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
}
