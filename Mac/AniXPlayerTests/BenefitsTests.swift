import XCTest

final class BenefitsTests: XCTestCase {

    // MARK: - Subtitle transcriptions

    func testParsesSRTIntoTranscriptions() {
        let srt = """
        1
        00:00:05,000 --> 00:00:07,000
        {\\an8}第一行<font color="#ffffff">测试</font>

        2
        00:01:02,500 --> 00:01:03,000
        第二行
        第三行

        3
        01:02:03,000 --> 01:02:05,000
        超过一小时
        """

        let result = SubtitleTranscriptParser.parseSRT(srt)
        XCTAssertEqual(result.map { $0.start }, ["00:05", "01:02", "01:02:03"])
        XCTAssertEqual(result.map { $0.content }, ["第一行测试", "第二行 第三行", "超过一小时"])
    }

    func testParsesASSIntoTranscriptions() {
        let ass = """
        [Script Info]
        ScriptType: v4.00+

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:12.47,0:00:15.18,Default,,0,0,0,,{\\fs16}第一行\\N第二行
        Dialogue: 0,0:01:02.50,0:01:03.00,Default,,0,0,0,,简单文本
        Comment: 0,0:01:10.00,0:01:12.00,Default,,0,0,0,,这是注释
        Dialogue: 0,0:02:00.00,0:02:01.00,Default,,0,0,0,,m 0 0 l 100 100
        """

        let result = SubtitleTranscriptParser.parseASS(ass)
        XCTAssertEqual(result.map { $0.start }, ["00:12", "01:02"])
        XCTAssertEqual(result.map { $0.content }, ["第一行 第二行", "简单文本"])
    }

    func testUnspportedTranscriptExtensionReturnsEmpty() {
        let result = SubtitleTranscriptParser.transcriptions(
            fromText: "WEBVTT\n\n00:01.000 --> 00:02.000\nhello",
            fileExtension: "vtt"
        )
        XCTAssertTrue(result.isEmpty)
    }

    func testFormatsTranscriptTime() {
        XCTAssertEqual(SummaryTranscriptTime.format(5), "00:05")
        XCTAssertEqual(SummaryTranscriptTime.format(65.9), "01:05")
        XCTAssertEqual(SummaryTranscriptTime.format(3723), "01:02:03")
    }

    // MARK: - Summary JSON

    func testDecodesSummaryResponse() throws {
        let json = """
        {
          "success": true,
          "errorCode": 0,
          "errorMessage": "",
          "summaryId": 12,
          "summary": "总览",
          "topics": [
            {
              "order": 1,
              "title": "开场",
              "parts": [
                { "start": "00:10", "content": "内容一" },
                { "start": "01:02:03", "content": "内容二" }
              ]
            }
          ],
          "usage": 1,
          "countRemain": 9
        }
        """

        let response = try JSONDecoder().decode(SummaryVideoResponse.self, from: Data(json.utf8))
        XCTAssertTrue(response.isSuccess)
        XCTAssertTrue(response.hasContent)
        XCTAssertEqual(response.summaryId, 12)
        XCTAssertEqual(response.summary, "总览")
        XCTAssertEqual(response.topics.count, 1)
        XCTAssertEqual(response.topics.first?.parts.count, 2)
        XCTAssertEqual(response.topics.first?.parts.last?.start, "01:02:03")
        XCTAssertEqual(response.usage, 1)
        XCTAssertEqual(response.countRemain, 9)
    }

    func testDecodesSummaryErrorResponse() throws {
        let json = """
        { "success": false, "errorCode": 62, "errorMessage": "内容过滤" }
        """

        let response = try JSONDecoder().decode(SummaryVideoResponse.self, from: Data(json.utf8))
        XCTAssertFalse(response.isSuccess)
        XCTAssertFalse(response.hasContent)
        XCTAssertEqual(response.errorCode, 62)
    }

    func testDecodesSummaryWithMissingOptionalFields() throws {
        let response = try JSONDecoder().decode(SummaryVideoResponse.self, from: Data("{}".utf8))
        XCTAssertTrue(response.summary.isEmpty)
        XCTAssertTrue(response.topics.isEmpty)
        XCTAssertEqual(response.errorCode, nil)
        XCTAssertFalse(response.hasContent)
    }

    func testBuildsMarkdown() {
        let topics = [
            SummaryTopic(
                order: 1,
                title: "开场",
                parts: [SummaryTopicPart(start: "00:10", content: "内容")]
            )
        ]
        let markdown = SummaryMarkdown.make(summary: "总览", topics: topics)
        XCTAssertEqual(markdown, "**总览**\n\n**1. 开场**\n\n- [00:10](00:10) 内容")
    }

    // MARK: - Cache key

    func testCacheFileNameOnlyAcceptsHexHash() {
        XCTAssertEqual(SummaryCache.fileName(forHash: "ABCDEF0123"), "ABCDEF0123.json")
        XCTAssertEqual(SummaryCache.fileName(forHash: "  abcdef0123  "), "ABCDEF0123.json")
        XCTAssertNil(SummaryCache.fileName(forHash: ""))
        XCTAssertNil(SummaryCache.fileName(forHash: "../../etc/passwd"))
        XCTAssertNil(SummaryCache.fileName(forHash: "abc.json"))
        XCTAssertNil(SummaryCache.fileName(forHash: String(repeating: "a", count: 65)))
    }

    func testCacheRoundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("AniXSummaryTests-\(UUID().uuidString)", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let cache = SummaryCache(directoryURL: directory)
        let response = SummaryVideoResponse(
            success: true,
            errorCode: 0,
            summaryId: 7,
            topics: [],
            summary: "总览",
            usage: 1,
            countRemain: 3
        )

        let url = try cache.save(response, hash: "aabbcc", fileName: "video.mkv", videoTitle: "标题")
        XCTAssertEqual(url.lastPathComponent, "AABBCC.json")
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        let entry = cache.load(hash: "aabbcc")
        XCTAssertEqual(entry?.response.summary, "总览")
        XCTAssertEqual(entry?.fileName, "video.mkv")
        XCTAssertEqual(entry?.videoTitle, "标题")
        XCTAssertNil(cache.load(hash: "not-a-hash"))
    }

    // MARK: - Backup danmaku merge

    func testBackupDanmakuMergeDeduplicatesAndSorts() {
        func key(_ time: Int, _ message: String) -> BackupDanmakuKey {
            return BackupDanmakuKey(timeMilliseconds: time * 1000, mode: 1, color: 0xFFFFFF, message: message)
        }

        let existing = [key(10, "a"), key(20, "b")]
        let fetched = [
            key(20, "b"),   // 已存在
            key(5, "new"),  // 新增
            key(10, "c"),   // 同一时间但文本不同，新增
            key(5, "new")   // fetched 内部重复
        ]

        let plan = BackupDanmakuMerger.plan(existing: Set(existing), fetched: fetched)
        XCTAssertEqual(plan.addedCount, 2)
        XCTAssertEqual(plan.addedIndices, [1, 2])
        XCTAssertEqual(plan.addedKeys.map { $0.timeMilliseconds }, [5000, 10000])

        let merged = BackupDanmakuMerger.merge(existing: existing, fetched: fetched)
        XCTAssertEqual(merged.addedCount, 2)
        XCTAssertEqual(merged.keys.count, 4)
        XCTAssertEqual(Set(merged.keys).count, 4)
        XCTAssertEqual(merged.keys.map { $0.timeMilliseconds }, [5000, 10000, 10000, 20000])
    }

    func testBackupDanmakuMergeWithoutNewItems() {
        let key = BackupDanmakuKey(timeMilliseconds: 1000, mode: 1, color: 0, message: "same")
        let plan = BackupDanmakuMerger.plan(existing: [key], fetched: [key, key])
        XCTAssertEqual(plan.addedCount, 0)
        XCTAssertTrue(plan.addedIndices.isEmpty)
    }
}
