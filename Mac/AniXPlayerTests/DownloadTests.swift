//
//  DownloadTests.swift
//  AniXPlayerTests
//
//  macOS：下载中心模型、状态机、SQLite、Transmission RPC 与纯逻辑测试。
//

import XCTest

final class DownloadTests: XCTestCase {

    private var temporaryDirectory: URL!
    private var databaseURL: URL!
    private var store: DownloadStore!

    override func setUpWithError() throws {
        try super.setUpWithError()
        temporaryDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("DownloadTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: temporaryDirectory, withIntermediateDirectories: true)
        databaseURL = temporaryDirectory.appendingPathComponent("Downloads.sqlite")
        store = try DownloadStore(databaseURL: databaseURL)
        MockURLProtocol.reset()
    }

    override func tearDownWithError() throws {
        store = nil
        MockURLProtocol.reset()
        if let temporaryDirectory {
            try? FileManager.default.removeItem(at: temporaryDirectory)
        }
        try super.tearDownWithError()
    }

    // MARK: - Helpers

    private func makeTask(
        kind: DownloadTaskKind = .http,
        source: String = "https://example.com/video.mp4",
        title: String = "视频",
        savePath: String? = nil,
        status: DownloadTaskStatus = .queued,
        progress: Double = 0,
        downloaded: Int64 = 0,
        total: Int64 = 0,
        speed: Int64 = 0,
        upload: Int64 = 0,
        eta: Int? = nil,
        error: String? = nil,
        createdAt: Date = Date(timeIntervalSince1970: 1_000),
        engineTaskID: String? = nil,
        filePaths: [String] = [],
        isStreaming: Bool = false,
        streamPath: String? = nil,
        bookmark: Data? = nil
    ) -> DownloadTask {
        DownloadTask(
            kind: kind,
            source: source,
            title: title,
            savePath: savePath ?? temporaryDirectory.path,
            status: status,
            progress: progress,
            downloadedBytes: downloaded,
            totalBytes: total,
            downloadSpeed: speed,
            uploadSpeed: upload,
            etaSeconds: eta,
            errorMessage: error,
            createdAt: createdAt,
            updatedAt: createdAt,
            engineTaskID: engineTaskID,
            filePaths: filePaths,
            isStreaming: isStreaming,
            streamPath: streamPath,
            savePathBookmark: bookmark
        )
    }

    // MARK: - Source parsing

    func testMagnetNormalizationKeepsTrackersAndUppercasesBTIH() throws {
        let hash = "abcdefabcdefabcdefabcdefabcdefabcdefabcd"
        let raw = "magnet:?xt=urn:btih:\(hash)&dn=Test%20Anime&tr=udp%3A%2F%2Ftracker.example%3A80"
        let source = try DownloadSourceParser.parse(raw)

        XCTAssertEqual(source.kind, .magnet)
        XCTAssertTrue(source.source.hasPrefix("magnet:?xt=urn:btih:"))
        XCTAssertTrue(source.source.contains(hash.uppercased()))
        XCTAssertTrue(source.source.contains("dn=Test%20Anime"))
        XCTAssertTrue(source.source.contains("tr=udp%3A%2F%2Ftracker.example%3A80"))
        XCTAssertEqual(source.infoHash, hash)
        XCTAssertEqual(source.suggestedTitle, "Test Anime")
    }

    func testDDPlayMagnetPrefixIsRemoved() throws {
        let hash = String(repeating: "a", count: 40)
        let source = try DownloadSourceParser.parse("ddplay:magnet:?xt=urn:btih:\(hash)")

        XCTAssertEqual(source.kind, .magnet)
        XCTAssertTrue(source.source.hasPrefix("magnet:?xt="))
        XCTAssertFalse(source.source.hasPrefix("ddplay:"))
        XCTAssertEqual(source.infoHash, hash)
        XCTAssertTrue(source.suggestedTitle.contains(String(hash.prefix(8)).uppercased()))
    }

    func testMagnetWithoutInfoHashFails() {
        XCTAssertThrowsError(try DownloadSourceParser.parse("magnet:?dn=NoHash")) { error in
            XCTAssertEqual(error as? DownloadSourceError, .invalidMagnet)
        }
        XCTAssertThrowsError(try DownloadSourceParser.parse("magnet:?xt=urn:btih:short"))
    }

    func testTorrentURLAndLocalTorrentFile() throws {
        let urlSource = try DownloadSourceParser.parse("https://example.com/download/My%20Show.torrent?token=abc")
        XCTAssertEqual(urlSource.kind, .torrent)
        XCTAssertEqual(urlSource.suggestedTitle, "My Show")
        XCTAssertEqual(urlSource.source, "https://example.com/download/My%20Show.torrent?token=abc")

        let localURL = temporaryDirectory.appendingPathComponent("本地 种子.torrent")
        try Data("d4:infod4:name4:teste".utf8).write(to: localURL)
        let localSource = try DownloadSourceParser.parse(localURL.path)
        XCTAssertEqual(localSource.kind, .torrent)
        XCTAssertEqual(localSource.source, localURL.standardizedFileURL.path)
        XCTAssertEqual(localSource.suggestedTitle, "本地 种子")
        XCTAssertEqual(localSource.infoHash, "1ade8a1a581f338e4fce4ce784da3f7d03f81f3a")

        XCTAssertThrowsError(try DownloadSourceParser.parse("/tmp/does-not-exist-\(UUID().uuidString).torrent"))
    }

    func testDDPlayURLStyleMagnetPrefixIsRemoved() throws {
        let hash = String(repeating: "c", count: 40)
        let source = try DownloadSourceParser.parse("ddplay://magnet:?xt=urn:btih:\(hash)&dn=Test")
        XCTAssertEqual(source.kind, .magnet)
        XCTAssertEqual(source.source, "magnet:?xt=urn:btih:\(hash.uppercased())&dn=Test")
        XCTAssertEqual(source.infoHash, hash)
    }

    func testHTTPDirectLinkAndInvalidInput() throws {
        let source = try DownloadSourceParser.parse("https://example.com/videos/ep01.mp4")
        XCTAssertEqual(source.kind, .http)
        XCTAssertEqual(source.suggestedTitle, "ep01.mp4")
        XCTAssertEqual(source.source, "https://example.com/videos/ep01.mp4")

        XCTAssertThrowsError(try DownloadSourceParser.parse(""))
        XCTAssertThrowsError(try DownloadSourceParser.parse("   "))
        XCTAssertThrowsError(try DownloadSourceParser.parse("hello world"))
        XCTAssertThrowsError(try DownloadSourceParser.parse("ftp://example.com/file.mp4")) { error in
            guard case .unsupportedScheme("ftp") = error as? DownloadSourceError else {
                return XCTFail("expected unsupportedScheme, got \(error)")
            }
        }
    }

    func testBitTorrentInfoHashAndDeduplicationKeys() throws {
        let data = Data("d8:announce3:foo4:infod4:name4:testee".utf8)
        let hash = try XCTUnwrap(BitTorrentMetainfo.infoHash(in: data))
        XCTAssertEqual(hash, "1ade8a1a581f338e4fce4ce784da3f7d03f81f3a")

        let torrentURL = temporaryDirectory.appendingPathComponent("hash.torrent")
        try data.write(to: torrentURL)
        let torrentSource = try DownloadSourceParser.parse(torrentURL.path)
        XCTAssertEqual(torrentSource.infoHash, hash)

        let magnetSource = try DownloadSourceParser.parse("magnet:?xt=urn:btih:\(hash.uppercased())")
        XCTAssertEqual(
            DownloadSourceParser.deduplicationKey(for: torrentSource),
            DownloadSourceParser.deduplicationKey(for: magnetSource)
        )

        let base32Source = try DownloadSourceParser.parse(
            "magnet:?xt=urn:btih:DLPIUGSYD4ZY4T6OJTTYJWR7PUB7QHZ2"
        )
        XCTAssertEqual(
            DownloadSourceParser.normalizedInfoHash(base32Source.infoHash),
            hash
        )

        var task = makeTask(
            kind: .magnet,
            source: magnetSource.source,
            status: .downloading,
            engineTaskID: hash
        )
        XCTAssertEqual(DownloadSourceParser.deduplicationKey(for: task), "btih:\(hash)")
        task.kind = .torrent
        task.source = torrentURL.path
        XCTAssertEqual(DownloadSourceParser.deduplicationKey(for: task), "btih:\(hash)")

        let http = try DownloadSourceParser.parse("https://example.com/a.mp4")
        let httpTask = makeTask(kind: .http, source: http.source)
        XCTAssertEqual(
            DownloadSourceParser.deduplicationKey(for: httpTask),
            DownloadSourceParser.deduplicationKey(for: http)
        )
    }

    // MARK: - State machine

    func testValidStateTransitions() {
        let valid: [(DownloadTaskStatus, DownloadTaskStatus)] = [
            (.queued, .downloading),
            (.queued, .paused),
            (.queued, .stopped),
            (.downloading, .queued),
            (.downloading, .paused),
            (.downloading, .stopped),
            (.downloading, .completed),
            (.downloading, .failed),
            (.paused, .downloading),
            (.paused, .stopped),
            (.paused, .completed),
            (.stopped, .queued),
            (.stopped, .downloading),
            (.stopped, .completed),
            (.failed, .queued),
            (.failed, .downloading),
        ]
        for (from, to) in valid {
            XCTAssertTrue(from.canTransition(to: to), "\(from) -> \(to) 应该合法")
        }
    }

    func testInvalidStateTransitions() {
        let invalid: [(DownloadTaskStatus, DownloadTaskStatus)] = [
            (.completed, .queued),
            (.completed, .downloading),
            (.completed, .paused),
            (.completed, .failed),
            (.queued, .completed),
            (.failed, .completed),
        ]
        for (from, to) in invalid {
            XCTAssertFalse(from.canTransition(to: to), "\(from) -> \(to) 应该非法")
        }
    }

    func testCompletedTaskCannotRestart() {
        XCTAssertFalse(DownloadTaskStatus.completed.canStart)
        XCTAssertTrue(DownloadTaskStatus.failed.canStart)
        XCTAssertTrue(DownloadTaskStatus.paused.canStart)
        XCTAssertTrue(DownloadTaskStatus.stopped.canStart)
    }

    func testTaskTransitionThrowsAndCompletionResetsFields() throws {
        var completedTask = makeTask(status: .completed)
        XCTAssertThrowsError(try completedTask.transition(to: .downloading))
        XCTAssertEqual(completedTask.status, .completed)

        var task = makeTask(
            status: .downloading,
            progress: 0.4,
            downloaded: 400,
            total: 1_000,
            speed: 50,
            upload: 10,
            eta: 12,
            error: "some error"
        )

        try task.transition(to: .completed, at: Date(timeIntervalSince1970: 2_000))
        XCTAssertEqual(task.status, .completed)
        XCTAssertEqual(task.progress, 1)
        XCTAssertEqual(task.downloadSpeed, 0)
        XCTAssertEqual(task.uploadSpeed, 0)
        XCTAssertNil(task.etaSeconds)
        XCTAssertNil(task.errorMessage)
        XCTAssertEqual(task.updatedAt, Date(timeIntervalSince1970: 2_000))
    }

    // MARK: - SQLite store

    func testStoreCRUDAndStatusFiltering() throws {
        let older = makeTask(
            source: "https://example.com/a.mp4",
            title: "A",
            status: .downloading,
            progress: 0.25,
            downloaded: 25,
            total: 100,
            speed: 10,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        var newer = makeTask(
            kind: .magnet,
            source: "magnet:?xt=urn:btih:\(String(repeating: "b", count: 40))",
            title: "B",
            status: .completed,
            progress: 1,
            downloaded: 1_000,
            total: 1_000,
            createdAt: Date(timeIntervalSince1970: 2_000),
            engineTaskID: "hash-b",
            filePaths: ["/tmp/B.mkv"],
            bookmark: Data([1, 2, 3])
        )
        newer.uploadSpeed = 42
        newer.etaSeconds = 0

        try store.save(older)
        try store.save(newer)
        XCTAssertEqual(try store.count(), 2)

        let all = try store.allTasks()
        XCTAssertEqual(all.map { $0.title }, ["B", "A"])

        let downloading = try store.tasks(status: .downloading)
        XCTAssertEqual(downloading.count, 1)
        XCTAssertEqual(downloading[0].id, older.id)

        let completed = try XCTUnwrap(store.task(id: newer.id))
        XCTAssertEqual(completed.kind, .magnet)
        XCTAssertEqual(completed.engineTaskID, "hash-b")
        XCTAssertEqual(completed.filePaths, ["/tmp/B.mkv"])
        XCTAssertEqual(completed.savePathBookmark, Data([1, 2, 3]))
        XCTAssertEqual(completed.uploadSpeed, 42)
        XCTAssertEqual(completed.etaSeconds, 0)

        try store.delete(id: older.id)
        XCTAssertNil(try store.task(id: older.id))
        XCTAssertEqual(try store.count(), 1)
    }

    func testStorePersistsAcrossReopen() throws {
        var task = makeTask(
            kind: .torrent,
            source: "/tmp/show.torrent",
            title: "Reopen",
            status: .failed,
            progress: 0.7,
            downloaded: 700,
            total: 1_000,
            error: "network down"
        )
        task.savePathBookmark = Data([9, 8, 7])
        task.filePaths = ["/tmp/show/e01.mkv", "/tmp/show/e02.mkv"]
        try store.save(task)

        store = nil
        let reopened = try DownloadStore(databaseURL: databaseURL)
        let fetched = try XCTUnwrap(reopened.task(id: task.id))
        XCTAssertEqual(fetched.title, "Reopen")
        XCTAssertEqual(fetched.status, .failed)
        XCTAssertEqual(fetched.progress, 0.7, accuracy: 0.0001)
        XCTAssertEqual(fetched.errorMessage, "network down")
        XCTAssertEqual(fetched.filePaths, task.filePaths)
        XCTAssertEqual(fetched.savePathBookmark, Data([9, 8, 7]))
        store = reopened
    }

    func testStoreRejectsInvalidProgressAndKeepsBounds() throws {
        let task = makeTask(status: .downloading, progress: 1.7, downloaded: -5, total: -10)
        try store.save(task)
        let fetched = try XCTUnwrap(store.task(id: task.id))
        XCTAssertEqual(fetched.progress, 1)
        XCTAssertEqual(fetched.downloadedBytes, 0)
        XCTAssertEqual(fetched.totalBytes, 0)
    }

    // MARK: - Transmission RPC

    func testTransmissionSessionIDRetryOn409() async throws {
        var requestCount = 0
        MockURLProtocol.handler = { request in
            requestCount += 1
            if requestCount == 1 {
                return MockURLProtocol.response(
                    for: request,
                    status: 409,
                    headers: ["X-Transmission-Session-Id": "session-abc"],
                    json: [:]
                )
            }
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "X-Transmission-Session-Id"),
                "session-abc"
            )
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Basic dXNlcjpwYXNz"
            )
            return MockURLProtocol.response(
                for: request,
                json: ["version": "4.0.5", "rpc-version": 17, "download-dir": "/tmp"]
            )
        }

        let client = makeRPCClient(username: "user", password: "pass")
        let info = try await client.sessionGet()

        XCTAssertEqual(info.version, "4.0.5")
        XCTAssertEqual(info.rpcVersion, 17)
        XCTAssertEqual(info.downloadDirectory, "/tmp")
        XCTAssertEqual(requestCount, 2)
    }

    func testTransmissionTorrentAddMagnetEncoding() async throws {
        MockURLProtocol.handler = { request in
            let body = try XCTUnwrap(MockURLProtocol.jsonBody(from: request))
            XCTAssertEqual(body["method"] as? String, "torrent-add")
            let arguments = try XCTUnwrap(body["arguments"] as? [String: Any])
            XCTAssertEqual(arguments["filename"] as? String, "magnet:?xt=urn:btih:ABC")
            XCTAssertEqual(arguments["download-dir"] as? String, "/tmp/downloads")
            XCTAssertEqual(arguments["paused"] as? Bool, false)
            XCTAssertEqual(arguments["sequentialDownload"] as? Bool, true)

            return MockURLProtocol.response(
                for: request,
                json: [
                    "torrent-added": [
                        "id": 3,
                        "name": "Test Torrent",
                        "hashString": "ABCDEF",
                    ]
                ]
            )
        }

        let client = makeRPCClient()
        let result = try await client.addTorrent(
            source: "magnet:?xt=urn:btih:ABC",
            savePath: "/tmp/downloads",
            sequentialDownload: true
        )
        XCTAssertEqual(result.id, 3)
        XCTAssertEqual(result.name, "Test Torrent")
        XCTAssertEqual(result.engineTaskID, "abcdef")
        XCTAssertFalse(result.isDuplicate)
    }

    func testTransmissionTorrentAddMetainfoAndDuplicate() async throws {
        let metainfo = Data("d4:infod4:name4:testee".utf8)
        MockURLProtocol.handler = { request in
            let body = try XCTUnwrap(MockURLProtocol.jsonBody(from: request))
            let arguments = try XCTUnwrap(body["arguments"] as? [String: Any])
            XCTAssertEqual(arguments["metainfo"] as? String, metainfo.base64EncodedString())
            XCTAssertNil(arguments["filename"])

            return MockURLProtocol.response(
                for: request,
                json: [
                    "torrent-duplicate": [
                        "id": 8,
                        "name": "Duplicate",
                        "hashString": "DEADBEEF",
                    ]
                ]
            )
        }

        let client = makeRPCClient()
        let result = try await client.addTorrent(
            metainfo: metainfo,
            savePath: "/tmp",
            sequentialDownload: false
        )
        XCTAssertTrue(result.isDuplicate)
        XCTAssertEqual(result.id, 8)
        XCTAssertEqual(result.engineTaskID, "deadbeef")
    }

    func testTransmissionTorrentGetDecoding() async throws {
        MockURLProtocol.handler = { request in
            let body = try XCTUnwrap(MockURLProtocol.jsonBody(from: request))
            XCTAssertEqual(body["method"] as? String, "torrent-get")
            let arguments = try XCTUnwrap(body["arguments"] as? [String: Any])
            XCTAssertEqual(arguments["ids"] as? [String], ["hash-1"])
            XCTAssertNotNil(arguments["fields"])

            return MockURLProtocol.response(
                for: request,
                json: [
                    "torrents": [
                        [
                            "id": 1,
                            "hashString": "HASH-1",
                            "name": "Show S01",
                            "downloadDir": "/tmp/downloads",
                            "percentDone": 0.5,
                            "rateDownload": 1_024,
                            "rateUpload": 128,
                            "eta": 60,
                            "status": 4,
                            "totalSize": 2_000,
                            "leftUntilDone": 1_000,
                            "isFinished": false,
                            "error": 0,
                            "errorString": "",
                            "files": [
                                [
                                    "name": "Show/e01.mkv",
                                    "length": 2_000,
                                    "bytesCompleted": 1_000,
                                    "isWanted": true,
                                ]
                            ],
                        ]
                    ]
                ]
            )
        }

        let client = makeRPCClient()
        let torrents = try await client.getTorrents(ids: ["hash-1"])
        let torrent = try XCTUnwrap(torrents.first)
        XCTAssertEqual(torrent.id, 1)
        XCTAssertEqual(torrent.hashString, "HASH-1")
        XCTAssertEqual(torrent.name, "Show S01")
        XCTAssertEqual(torrent.percentDone, 0.5, accuracy: 0.0001)
        XCTAssertEqual(torrent.rateDownload, 1_024)
        XCTAssertEqual(torrent.rateUpload, 128)
        XCTAssertEqual(torrent.etaSeconds, 60)
        XCTAssertEqual(torrent.status, 4)
        XCTAssertEqual(torrent.totalSize, 2_000)
        XCTAssertEqual(torrent.leftUntilDone, 1_000)
        XCTAssertFalse(torrent.isFinished)
        XCTAssertEqual(torrent.downloadedBytes, 1_000)
        XCTAssertEqual(torrent.files.count, 1)
        XCTAssertEqual(torrent.files[0].index, 0)
        XCTAssertEqual(torrent.files[0].bytesCompleted, 1_000)
        XCTAssertEqual(torrent.files[0].progress, 0.5, accuracy: 0.0001)
        XCTAssertEqual(torrent.filePaths, ["/tmp/downloads/Show/e01.mkv"])
        XCTAssertEqual(torrent.fileProgress.count, 1)
        XCTAssertEqual(torrent.fileProgress[0].index, 0)
        XCTAssertEqual(torrent.fileProgress[0].path, "/tmp/downloads/Show/e01.mkv")
        XCTAssertEqual(torrent.fileProgress[0].isWanted, true)
    }

    func testTransmissionStartStopRemoveArguments() async throws {
        var methods: [String] = []
        var lastArguments: [[String: Any]] = []

        MockURLProtocol.handler = { request in
            let body = try XCTUnwrap(MockURLProtocol.jsonBody(from: request))
            methods.append(try XCTUnwrap(body["method"] as? String))
            lastArguments.append(try XCTUnwrap(body["arguments"] as? [String: Any]))
            return MockURLProtocol.response(for: request, json: [:])
        }

        let client = makeRPCClient()
        try await client.start(ids: ["abc"])
        try await client.stop(ids: ["abc"])
        try await client.remove(ids: ["abc"], deleteLocalData: true)

        XCTAssertEqual(methods, ["torrent-start", "torrent-stop", "torrent-remove"])
        XCTAssertEqual(lastArguments[0]["ids"] as? [String], ["abc"])
        XCTAssertEqual(lastArguments[1]["ids"] as? [String], ["abc"])
        XCTAssertEqual(lastArguments[2]["ids"] as? [String], ["abc"])
        XCTAssertEqual(lastArguments[2]["delete-local-data"] as? Bool, true)
    }

    func testTransmissionSetFilesWantedArguments() async throws {
        var captured: [String: Any]?
        MockURLProtocol.handler = { request in
            let body = try XCTUnwrap(MockURLProtocol.jsonBody(from: request))
            XCTAssertEqual(body["method"] as? String, "torrent-set")
            captured = try XCTUnwrap(body["arguments"] as? [String: Any])
            return MockURLProtocol.response(for: request, json: [:])
        }

        let client = makeRPCClient()
        try await client.setFilesWanted(ids: ["hash"], indices: [0, 2], wanted: true)
        XCTAssertEqual(captured?["ids"] as? [String], ["hash"])
        XCTAssertEqual(captured?["files-wanted"] as? [Int], [0, 2])
        XCTAssertNil(captured?["files-unwanted"])

        try await client.setFilesWanted(ids: ["hash"], indices: [1], wanted: false)
        XCTAssertEqual(captured?["files-unwanted"] as? [Int], [1])
    }

    func testTransmissionSequentialFallbackOnOldServer() async throws {
        var callCount = 0
        MockURLProtocol.handler = { request in
            callCount += 1
            let body = try XCTUnwrap(MockURLProtocol.jsonBody(from: request))
            let arguments = try XCTUnwrap(body["arguments"] as? [String: Any])
            if callCount == 1 {
                XCTAssertEqual(arguments["sequentialDownload"] as? Bool, true)
                return MockURLProtocol.response(
                    for: request,
                    result: "invalid argument",
                    json: [:]
                )
            }
            XCTAssertNil(arguments["sequentialDownload"])
            return MockURLProtocol.response(
                for: request,
                json: [
                    "torrent-added": [
                        "id": 9,
                        "name": "Fallback",
                        "hashString": "fallbackhash",
                    ]
                ]
            )
        }

        let client = makeRPCClient()
        let result = try await client.addTorrent(
            source: "magnet:?xt=urn:btih:fallback",
            savePath: "/tmp",
            sequentialDownload: true
        )
        XCTAssertEqual(result.id, 9)
        XCTAssertEqual(callCount, 2)
    }

    func testTransmissionUnauthorizedAndUnavailableErrors() async throws {
        MockURLProtocol.handler = { request in
            MockURLProtocol.response(for: request, status: 401, json: [:])
        }
        let client = makeRPCClient(username: "u", password: "bad")
        do {
            _ = try await client.sessionGet()
            XCTFail("应该抛出 unauthorized")
        } catch let error as TransmissionRPCError {
            XCTAssertEqual(error, .unauthorized)
        }

        MockURLProtocol.handler = { request in
            throw URLError(.cannotConnectToHost)
        }
        do {
            _ = try await client.sessionGet()
            XCTFail("应该抛出 unavailable")
        } catch let error as TransmissionRPCError {
            guard case .unavailable = error else {
                return XCTFail("expected unavailable, got \(error)")
            }
        }
    }

    // MARK: - Query / formatting

    func testFormatting() {
        XCTAssertEqual(DownloadFormatting.speed(0), "—")
        XCTAssertTrue(DownloadFormatting.speed(2_000_000).hasSuffix("/s"))
        XCTAssertEqual(DownloadFormatting.eta(nil), "—")
        XCTAssertEqual(DownloadFormatting.eta(0), "—")
        XCTAssertEqual(DownloadFormatting.eta(45), "45 秒")
        XCTAssertEqual(DownloadFormatting.eta(65), "1 分 5 秒")
        XCTAssertEqual(DownloadFormatting.eta(3_660), "1 小时 1 分")
        XCTAssertEqual(DownloadFormatting.percent(-0.2), "0.0%")
        XCTAssertEqual(DownloadFormatting.percent(0.456), "45.6%")
        XCTAssertEqual(DownloadFormatting.percent(2), "100.0%")
    }

    func testSpeedMeter() {
        var meter = DownloadSpeedMeter(window: 3)
        let base = Date(timeIntervalSince1970: 1_000)
        XCTAssertEqual(meter.record(totalBytes: 0, at: base), 0)
        XCTAssertEqual(meter.record(totalBytes: 1_000, at: base.addingTimeInterval(1)), 1_000)
        XCTAssertEqual(meter.record(totalBytes: 3_000, at: base.addingTimeInterval(2)), 1_500)
        XCTAssertEqual(meter.record(totalBytes: 3_000, at: base.addingTimeInterval(3)), 1_000)

        meter.reset()
        XCTAssertEqual(meter.record(totalBytes: 5_000, at: base), 0)
    }

    func testQueryFilterSearchAndSort() {
        let first = makeTask(
            title: "Alpha",
            status: .downloading,
            progress: 0.2,
            speed: 100,
            createdAt: Date(timeIntervalSince1970: 1_000)
        )
        let second = makeTask(
            title: "Beta",
            status: .completed,
            progress: 1,
            total: 999,
            speed: 0,
            createdAt: Date(timeIntervalSince1970: 2_000)
        )
        let third = makeTask(
            title: "Gamma",
            status: .failed,
            progress: 0.4,
            speed: 0,
            createdAt: Date(timeIntervalSince1970: 3_000)
        )
        let tasks = [first, second, third]

        var query = DownloadQuery()
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Gamma", "Beta", "Alpha"])

        query.filter = .active
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Alpha"])

        query.filter = .completed
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Beta"])

        query = DownloadQuery(searchText: "amm")
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Gamma"])

        query = DownloadQuery(sort: .title)
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Alpha", "Beta", "Gamma"])

        query = DownloadQuery(sort: .progress)
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Beta", "Gamma", "Alpha"])

        query = DownloadQuery(sort: .size)
        XCTAssertEqual(DownloadQueryLogic.apply(tasks, query: query).map { $0.title }, ["Beta", "Gamma", "Alpha"])
    }

    func testPlaybackRules() {
        let downloading = makeTask(
            kind: .magnet,
            status: .downloading,
            filePaths: ["/tmp/a.mkv", "/tmp/b.srt"]
        )
        XCTAssertEqual(
            DownloadFileRules.playablePath(for: downloading, sizeAtPath: { _ in 25 * 1024 * 1024 }),
            "/tmp/a.mkv"
        )
        XCTAssertNil(
            DownloadFileRules.playablePath(for: downloading, sizeAtPath: { _ in 19 * 1024 * 1024 })
        )

        let httpDownloading = makeTask(status: .downloading, filePaths: ["/tmp/http.mp4"])
        XCTAssertNil(
            DownloadFileRules.playablePath(for: httpDownloading, sizeAtPath: { _ in 100 * 1024 * 1024 })
        )

        let completed = makeTask(
            kind: .http,
            status: .completed,
            filePaths: ["/tmp/small.mp4", "/tmp/large.mkv"]
        )
        XCTAssertEqual(
            DownloadFileRules.playablePath(
                for: completed,
                sizeAtPath: { $0.hasSuffix(".mkv") ? 300 : 10 }
            ),
            "/tmp/large.mkv"
        )

        XCTAssertTrue(DownloadFileRules.isVideoFile(path: "/tmp/Show.MKV"))
        XCTAssertFalse(DownloadFileRules.isVideoFile(path: "/tmp/Show.srt"))
    }

    func testPlaybackPathsIncludeAllVideosInNaturalOrder() {
        let task = makeTask(
            kind: .torrent,
            status: .completed,
            filePaths: [
                "/tmp/Show/episode 10.mkv",
                "/tmp/Show/episode 2.mkv",
                "/tmp/Show/episode 1.mkv",
                "/tmp/Show/readme.srt",
            ]
        )
        let paths = DownloadFileRules.playablePaths(for: task) { _ in 100 * 1024 * 1024 }
        XCTAssertEqual(paths, [
            "/tmp/Show/episode 1.mkv",
            "/tmp/Show/episode 2.mkv",
            "/tmp/Show/episode 10.mkv",
        ])
        XCTAssertEqual(
            DownloadFileRules.playablePath(for: task) { _ in 100 * 1024 * 1024 },
            "/tmp/Show/episode 1.mkv"
        )
    }

    func testPlaybackFallsBackForFilesWithoutRecognizedExtension() {
        XCTAssertTrue(
            DownloadFileRules.isPlayableCandidate(
                path: "/tmp/Show/video",
                size: 20 * 1024 * 1024
            )
        )
        XCTAssertFalse(
            DownloadFileRules.isPlayableCandidate(
                path: "/tmp/Show/video",
                size: 1 * 1024 * 1024
            )
        )
        XCTAssertFalse(
            DownloadFileRules.isPlayableCandidate(
                path: "/tmp/Show/notes.srt",
                size: 50 * 1024 * 1024
            )
        )
        XCTAssertTrue(
            DownloadFileRules.isPlayableCandidate(
                path: "/tmp/Show/video.bin",
                size: 20 * 1024 * 1024
            )
        )
    }

    func testMissingCompletedFilesState() {
        let task = makeTask(kind: .http, status: .completed, filePaths: ["/tmp/a.mp4", "/tmp/b.mkv"])
        XCTAssertTrue(DownloadFileRules.hasMissingFiles(task) { _ in false })
        XCTAssertFalse(DownloadFileRules.hasMissingFiles(task) { $0 == "/tmp/a.mp4" })
        XCTAssertFalse(DownloadFileRules.hasMissingFiles(makeTask(status: .downloading, filePaths: ["/tmp/a.mp4"])) { _ in false })
    }

    func testFileNameSanitizeAndUniqueDestination() throws {
        XCTAssertEqual(DownloadFileName.sanitize("a/b:c?.mp4"), "a-b-c-.mp4")
        XCTAssertEqual(DownloadFileName.sanitize("  "), "download")

        let directory = temporaryDirectory.appendingPathComponent("files", isDirectory: true)
        let first = DownloadFileName.uniqueURL(
            in: directory,
            preferredName: "video.mp4",
            fileExists: { _ in false }
        )
        XCTAssertEqual(first.lastPathComponent, "video.mp4")

        let second = DownloadFileName.uniqueURL(
            in: directory,
            preferredName: "video.mp4",
            fileExists: { $0.hasSuffix("video.mp4") }
        )
        XCTAssertEqual(second.lastPathComponent, "video (2).mp4")

        let header = "attachment; filename=\"动画 01.mkv\""
        XCTAssertEqual(DownloadFileName.fileName(fromContentDisposition: header), "动画 01.mkv")
        let encodedHeader = "attachment; filename*=UTF-8''%E5%8A%A8%E7%94%BB%2001.mkv"
        XCTAssertEqual(DownloadFileName.fileName(fromContentDisposition: encodedHeader), "动画 01.mkv")
    }

    // MARK: - RPC helpers

    private func makeRPCClient(
        username: String = "",
        password: String = ""
    ) -> TransmissionRPCClient {
        let configuration = TransmissionRPCConfiguration(
            host: "127.0.0.1",
            port: 9091,
            username: username,
            password: password,
            sequentialDownload: true
        )
        let sessionConfiguration = URLSessionConfiguration.ephemeral
        sessionConfiguration.protocolClasses = [MockURLProtocol.self]
        let session = URLSession(configuration: sessionConfiguration)
        return TransmissionRPCClient(configuration: configuration, session: session)
    }
}

// MARK: - URLProtocol stub

private final class MockURLProtocol: URLProtocol {

    static var handler: ((URLRequest) throws -> (HTTPURLResponse, Data))?
    static var requests: [URLRequest] = []

    static func reset() {
        handler = nil
        requests = []
    }

    static func response(
        for request: URLRequest,
        status: Int = 200,
        headers: [String: String] = [:],
        result: String = "success",
        json: Any
    ) -> (HTTPURLResponse, Data) {
        let payload: [String: Any] = [
            "arguments": json,
            "result": result,
        ]
        let data = (try? JSONSerialization.data(withJSONObject: payload)) ?? Data("{}".utf8)
        let url = request.url ?? URL(string: "http://127.0.0.1:9091/transmission/rpc")!
        let response = HTTPURLResponse(
            url: url,
            statusCode: status,
            httpVersion: "HTTP/1.1",
            headerFields: headers
        )!
        return (response, data)
    }

    static func jsonBody(from request: URLRequest) -> [String: Any]? {
        guard let data = bodyData(from: request),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        return object
    }

    private static func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4_096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data.isEmpty ? nil : data
    }

    override class func canInit(with request: URLRequest) -> Bool {
        true
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest {
        request
    }

    override func startLoading() {
        MockURLProtocol.requests.append(request)
        guard let handler = MockURLProtocol.handler else {
            client?.urlProtocol(self, didFailWithError: URLError(.unknown))
            return
        }
        do {
            let (response, data) = try handler(request)
            client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            client?.urlProtocol(self, didLoad: data)
            client?.urlProtocolDidFinishLoading(self)
        } catch {
            client?.urlProtocol(self, didFailWithError: error)
        }
    }

    override func stopLoading() {}
}
