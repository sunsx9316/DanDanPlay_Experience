import XCTest

final class SubtitleTranslationTests: XCTestCase {

    // MARK: - SRT

    func testSRTParsesIndexTimelineAndMultilineText() throws {
        let content = """
        1
        00:00:30,141 --> 00:00:33,074
        Would you like some yakitori?

        2
        00:00:34,000 --> 00:00:36,500
        Line one
        Line two
        """

        let document = try SubtitleDocumentLoader.parseSRT(content)

        XCTAssertEqual(document.lines.count, 2)
        XCTAssertEqual(document.lines[0].start.milliseconds, 30_141)
        XCTAssertEqual(document.lines[0].end.milliseconds, 33_074)
        XCTAssertEqual(document.lines[0].originalText, "Would you like some yakitori?")
        XCTAssertEqual(document.lines[1].originalText, "Line one\nLine two")
        XCTAssertEqual(document.skippedLineCount, 0)
    }

    func testSRTExportModes() throws {
        let content = """
        1
        00:00:30,141 --> 00:00:33,074
        Hello

        2
        00:00:34,000 --> 00:00:36,500
        Line one
        Line two
        """

        var document = try SubtitleDocumentLoader.parseSRT(content)
        document.applyTranslations([
            "Hello": "你好",
            "Line one\nLine two": "第一行\n第二行",
        ])

        let translated = document.exportText(mode: .translated)
        XCTAssertTrue(translated.contains("00:00:30,141 --> 00:00:33,074\n你好"))
        XCTAssertTrue(translated.contains("00:00:34,000 --> 00:00:36,500\n第一行\n第二行"))
        XCTAssertFalse(translated.contains("Hello"))
        XCTAssertEqual(document.translatedLineCount, 2)

        let original = document.exportText(mode: .original)
        XCTAssertTrue(original.contains("Hello"))
        XCTAssertTrue(original.contains("Line one\nLine two"))

        let bilingual = document.exportText(mode: .bilingual)
        XCTAssertTrue(bilingual.contains("Hello\n你好"))
        XCTAssertTrue(bilingual.contains("Line one\nLine two\n第一行\n第二行"))
    }

    func testSRTDotTimelineAndSkippedBlock() throws {
        let content = """
        1
        0:00:01.25 --> 0:00:02.5
        One

        2
        not a timeline
        Broken

        3
        00:00:03,000 --> 00:00:04,000
        Three
        """

        let document = try SubtitleDocumentLoader.parseSRT(content)
        XCTAssertEqual(document.lines.count, 2)
        XCTAssertEqual(document.lines[0].start.milliseconds, 1_250)
        XCTAssertEqual(document.lines[0].end.milliseconds, 2_500)
        XCTAssertEqual(document.lines[1].originalText, "Three")
        XCTAssertEqual(document.skippedLineCount, 1)
    }

    // MARK: - ASS

    private func makeASS() -> String {
        #"""
        [Script Info]
        Title: Test
        ScriptType: v4.00+

        [V4+ Styles]
        Format: Name, Fontname, Fontsize, PrimaryColour, SecondaryColour, OutlineColour, BackColour, Bold, Italic, Underline, StrikeOut, ScaleX, ScaleY, Spacing, Angle, BorderStyle, Outline, Shadow, Alignment, MarginL, MarginR, MarginV, Encoding
        Style: Default,Arial,20,&H00FFFFFF,&H000000FF,&H00000000,&H00000000,0,0,0,0,100,100,0,0,1,2,0,2,10,10,10,1

        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:12.47,0:00:15.18,Default,,0,0,0,,{\i1}Hello\N{\fs16}world
        Dialogue: 1,0:00:16.00,0:00:18.00,Other,Speaker,10,20,30,Fade,你好，世界
        Dialogue: 0,0:00:18.50,0:00:19.00,Default,,0,0,0,,A\hB
        Comment: 0,0:00:19.00,0:00:20.00,Default,,0,0,0,,preserved comment
        """#
    }

    func testASSParsesDialogueFieldsAndVisibleText() throws {
        let document = try SubtitleDocumentLoader.parseASS(makeASS())

        XCTAssertEqual(document.lines.count, 3)
        XCTAssertEqual(document.lines[0].originalText, "Hello\nworld")
        XCTAssertEqual(document.lines[0].start.milliseconds, 12_470)
        XCTAssertEqual(document.lines[0].end.milliseconds, 15_180)
        XCTAssertEqual(document.lines[1].originalText, "你好，世界")
        XCTAssertEqual(document.lines[2].originalText, "A B")
        XCTAssertEqual(document.skippedLineCount, 0)
    }

    func testASSExportPreservesFieldsTagsAndLineBreaks() throws {
        var document = try SubtitleDocumentLoader.parseASS(makeASS())
        document.applyTranslations([
            "Hello\nworld": "你好\n世界",
            "你好，世界": "Hello, world",
            "A B": "甲 乙",
        ])

        let output = document.exportText(mode: .translated, format: .ass)

        XCTAssertTrue(output.contains(#"Dialogue: 0,0:00:12.47,0:00:15.18,Default,,0,0,0,,{\i1}你好\N{\fs16}世界"#))
        XCTAssertTrue(output.contains("Dialogue: 1,0:00:16.00,0:00:18.00,Other,Speaker,10,20,30,Fade,Hello, world"))
        XCTAssertTrue(output.contains(#"Dialogue: 0,0:00:18.50,0:00:19.00,Default,,0,0,0,,甲 乙\h"#))
        XCTAssertTrue(output.contains("Comment: 0,0:00:19.00,0:00:20.00,Default,,0,0,0,,preserved comment"))
        XCTAssertTrue(output.contains("[Script Info]"))
        XCTAssertTrue(output.contains("Style: Default,Arial,20"))
        XCTAssertTrue(output.contains("[V4+ Styles]"))
    }

    func testASSBilingualJoinsWithASSEscape() throws {
        var document = try SubtitleDocumentLoader.parseASS(makeASS())
        document.applyTranslations(["Hello\nworld": "你好\n世界"])

        let output = document.exportText(mode: .bilingual, format: .ass)
        XCTAssertTrue(output.contains(#"{\i1}Hello\N{\fs16}world\N{\i1}你好\N{\fs16}世界"#))
    }

    func testASSOriginalExportIsByteIdenticalAfterNewlineNormalization() throws {
        let content = makeASS()
        let document = try SubtitleDocumentLoader.parseASS(content)
        XCTAssertEqual(document.exportText(mode: .original), content)
    }

    func testASSUnsafeDialogueIsSkippedAndPreserved() throws {
        let content = #"""
        [Events]
        Format: Layer, Start, End, Style, Name, MarginL, MarginR, MarginV, Effect, Text
        Dialogue: 0,0:00:01.00,0:00:02.00,Default,,0,0,0,,good line
        Dialogue: 0,0:00:02.00,0:00:03.00,Default,,0,0,0,,bad {unclosed tag
        Dialogue: 0,0:00:03.00,0:00:04.00,Default,,0,0,0
        """#

        var document = try SubtitleDocumentLoader.parseASS(content)
        XCTAssertEqual(document.lines.count, 1)
        XCTAssertEqual(document.skippedLineCount, 2)
        XCTAssertEqual(document.lines[0].originalText, "good line")

        document.applyTranslations(["good line": "好"])
        let output = document.exportText(mode: .translated, format: .ass)
        XCTAssertTrue(output.contains("好"))
        XCTAssertTrue(output.contains("bad {unclosed tag"))
        XCTAssertTrue(output.contains("Dialogue: 0,0:00:03.00,0:00:04.00,Default,,0,0,0"))
    }

    // MARK: - Batching

    func testBatchPlannerDeduplicatesAndUsesSlowModeBelow100() {
        let plan = SubtitleBatchPlanner.plan(
            texts: ["alpha", "alpha", "   ", "beta"],
            serviceID: 5,
            totalLineCount: 500
        )

        XCTAssertEqual(plan.texts, ["alpha", "beta"])
        XCTAssertEqual(plan.mode, .chatGPTSlow)
        XCTAssertEqual(plan.maxCharactersPerBatch, 250)
        XCTAssertEqual(plan.maxLinesPerBatch, 5)
    }

    func testBatchPlannerSlowModeBoundaryAt100Lines() {
        let texts = (0..<100).map { "text-\($0)" }

        let slow = SubtitleBatchPlanner.plan(texts: texts, serviceID: 3, totalLineCount: 401)
        XCTAssertEqual(slow.mode, .chatGPTSlow)

        let normal = SubtitleBatchPlanner.plan(texts: texts, serviceID: 3, totalLineCount: 400)
        XCTAssertEqual(normal.mode, .chatGPTNormal)

        let ninetyNine = SubtitleBatchPlanner.plan(
            texts: Array(texts.prefix(99)),
            serviceID: 3,
            totalLineCount: 1
        )
        XCTAssertEqual(ninetyNine.mode, .chatGPTSlow)
    }

    func testChatGPTNormalModeSplitsAt15Lines() {
        let texts = (0..<120).map { "t\($0)" }
        let plan = SubtitleBatchPlanner.plan(texts: texts, serviceID: 5, totalLineCount: 120)

        XCTAssertEqual(plan.mode, .chatGPTNormal)
        XCTAssertEqual(plan.batches.count, 8)
        XCTAssertTrue(plan.batches.allSatisfy { $0.count == 15 })
    }

    func testChatGPTNormalModeSplitsAt500Characters() {
        let texts = (0..<100).map { String(repeating: "x", count: 55) + String(format: "%05d", $0) }
        let plan = SubtitleBatchPlanner.plan(texts: texts, serviceID: 5, totalLineCount: 100)

        XCTAssertEqual(plan.mode, .chatGPTNormal)
        XCTAssertEqual(plan.batches.count, 13)
        XCTAssertEqual(plan.batches[0].count, 8)
        XCTAssertEqual(plan.batches[12].count, 4)
    }

    func testChatGPTSlowModeSplitsAt250CharsOr5Lines() {
        let texts = (0..<6).map { String(repeating: "x", count: 45) + String(format: "%05d", $0) }
        let plan = SubtitleBatchPlanner.plan(texts: texts, serviceID: 5, totalLineCount: 6)

        XCTAssertEqual(plan.mode, .chatGPTSlow)
        XCTAssertEqual(plan.batches.count, 2)
        XCTAssertEqual(plan.batches[0].count, 5)
        XCTAssertEqual(plan.batches[1].count, 1)
    }

    func testLongTextGetsOwnBatchWithoutEmptyBatch() {
        let longText = String(repeating: "x", count: 300)
        let plan = SubtitleBatchPlanner.plan(
            texts: [longText, "short"],
            serviceID: 5,
            totalLineCount: 2
        )

        XCTAssertEqual(plan.batches.count, 2)
        XCTAssertEqual(plan.batches[0], [longText])
        XCTAssertEqual(plan.batches[1], ["short"])
    }

    func testAzureUses10000CharacterBatches() {
        let texts = [
            String(repeating: "a", count: 6_000),
            String(repeating: "b", count: 6_000),
        ]
        let plan = SubtitleBatchPlanner.plan(texts: texts, serviceID: 1, totalLineCount: 2)

        XCTAssertEqual(plan.mode, .azure)
        XCTAssertEqual(plan.maxCharactersPerBatch, 10_000)
        XCTAssertEqual(plan.batches.count, 2)
        XCTAssertEqual(plan.batches[0], [texts[0]])
        XCTAssertEqual(plan.batches[1], [texts[1]])
    }

    // MARK: - Decoding

    func testTranslateResponseDecoding() throws {
        let json = #"""
        {
          "success": true,
          "errorCode": 0,
          "errorMessage": null,
          "translation": {"Hello": "你好", "World": "世界"},
          "language": "ZH",
          "usage": 12,
          "countRemain": 345
        }
        """#
        let response = try JSONDecoder().decode(SubtitleTranslateResponse.self, from: Data(json.utf8))

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.translation["Hello"], "你好")
        XCTAssertEqual(response.translation["World"], "世界")
        XCTAssertEqual(response.language, "ZH")
        XCTAssertEqual(response.usage, 12)
        XCTAssertEqual(response.countRemain, 345)
    }

    func testErrorResponseDecodingWithoutTranslation() throws {
        let json = #"""
        {"success":false,"errorCode":61,"errorMessage":"已达到本月接口调用限额"}
        """#
        let response = try JSONDecoder().decode(SubtitleTranslateResponse.self, from: Data(json.utf8))

        XCTAssertFalse(response.success)
        XCTAssertEqual(response.errorCode, TranslationErrorCode.reachLimit)
        XCTAssertEqual(response.errorMessage, "已达到本月接口调用限额")
        XCTAssertTrue(response.translation.isEmpty)
        XCTAssertNil(response.countRemain)
    }

    func testServiceListDecoding() throws {
        let json = #"""
        {
          "success": true,
          "errorCode": 0,
          "services": [
            {"id": 0, "name": "默认"},
            {"id": 1, "name": "Azure翻译"},
            {"id": 5, "name": "GPT-4o"}
          ]
        }
        """#
        let response = try JSONDecoder().decode(SubtitleServiceListResponse.self, from: Data(json.utf8))

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.services.count, 3)
        XCTAssertEqual(response.services[2].id, 5)
        XCTAssertEqual(response.services[2].name, "GPT-4o")
    }

    func testUsageResponseDecoding() throws {
        let json = #"""
        {
          "success": true,
          "currentPeriod": "2026-11",
          "currentPeriodStart": "2026-11-01T00:00:00+08:00",
          "currentPeriodEnd": "2026-11-30T23:59:59+08:00",
          "services": [
            {"id": 5, "name": "GPT-4o", "usage": 120, "remain": 380, "total": 500}
          ]
        }
        """#
        let response = try JSONDecoder().decode(SubtitleServiceUsageResponse.self, from: Data(json.utf8))

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.currentPeriod, "2026-11")
        XCTAssertEqual(response.currentPeriodStart, "2026-11-01T00:00:00+08:00")
        XCTAssertEqual(response.services.first?.remain, 380)
        XCTAssertEqual(response.services.first?.total, 500)
    }

    func testTranslationAPIClientUsesExpectedPathAndBody() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let apiClient = APIClient(session: URLSession(configuration: configuration))
        let authenticated = AuthenticatedAPIClient(
            client: apiClient,
            tokenProvider: { "test-token" },
            refreshHandler: { "refreshed-token" }
        )
        let client = SubtitleTranslationAPIClient(
            client: authenticated,
            environment: APIEnvironment(host: "https://example.com", clientId: "test")
        )

        var capturedRequest: URLRequest?
        var capturedBody: Data?
        StubURLProtocol.handler = { request in
            capturedRequest = request
            capturedBody = request.anixBodyData
            let json = #"""
            {"success":true,"translation":{"hello":"你好"},"usage":1,"countRemain":9}
            """#
            return (200, [:], Data(json.utf8))
        }
        defer { StubURLProtocol.handler = nil }

        let response = try await client.translate(SubtitleTranslateRequest(
            texts: ["hello"],
            fromLanguage: "",
            toLanguage: "ZH",
            fileName: "episode.srt",
            service: 5
        ))

        XCTAssertEqual(response.translation["hello"], "你好")
        XCTAssertEqual(capturedRequest?.url?.absoluteString, "https://example.com/api/v2/ai/translate")
        XCTAssertEqual(capturedRequest?.httpMethod, "POST")
        XCTAssertEqual(capturedRequest?.value(forHTTPHeaderField: "Authorization"), "Bearer test-token")

        let bodyData = try XCTUnwrap(capturedBody)
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: bodyData) as? [String: Any])
        XCTAssertEqual(body["fromLanguage"] as? String, "")
        XCTAssertEqual(body["toLanguage"] as? String, "ZH")
        XCTAssertEqual(body["fileName"] as? String, "episode.srt")
        XCTAssertEqual(body["service"] as? Int, 5)
        XCTAssertEqual(body["texts"] as? [String], ["hello"])
    }

    // MARK: - Engine

    func testBatchFailureKeepsOtherBatchResults() async {
        let firstText = String(repeating: "a", count: 200)
        let secondText = String(repeating: "b", count: 200)

        let api = FakeSubtitleTranslationAPI { request in
            if request.texts == [firstText] {
                return SubtitleTranslateResponse(
                    success: true,
                    translation: [firstText: "甲"],
                    usage: 10,
                    countRemain: 90
                )
            }
            return SubtitleTranslateResponse(
                success: false,
                errorCode: TranslationErrorCode.reachLimit,
                errorMessage: "已达到本月接口调用限额",
                translation: [:],
                usage: 0,
                countRemain: 0
            )
        }

        let engine = SubtitleTranslationEngine(api: api)
        let outcome = await engine.translate(
            texts: [firstText, secondText],
            totalLineCount: 2,
            serviceID: 5,
            fromLanguage: "",
            toLanguage: "ZH",
            fileName: "episode.srt"
        )

        XCTAssertEqual(outcome.translations[firstText], "甲")
        XCTAssertNil(outcome.translations[secondText])
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertEqual(outcome.failures.first?.errorCode, TranslationErrorCode.reachLimit)
        XCTAssertTrue(outcome.hasReachLimitFailure)
        XCTAssertEqual(outcome.usage, 10)
        XCTAssertEqual(outcome.countRemain, 0)
        XCTAssertEqual(outcome.completedBatchCount, 2)
        XCTAssertEqual(outcome.totalBatchCount, 2)
        XCTAssertFalse(outcome.wasCancelled)
    }

    func testErrorResponseWithPartialTranslationStillAppliesResults() async {
        let firstText = String(repeating: "c", count: 200)
        let secondText = String(repeating: "d", count: 200)

        let api = FakeSubtitleTranslationAPI { request in
            if request.texts == [firstText] {
                return SubtitleTranslateResponse(
                    success: true,
                    translation: [firstText: "丙"],
                    usage: 5,
                    countRemain: 95
                )
            }
            return SubtitleTranslateResponse(
                success: false,
                errorCode: TranslationErrorCode.chatGPTContentFilter,
                errorMessage: "检测到不适当内容",
                translation: [secondText: "丁"],
                usage: 2,
                countRemain: 93
            )
        }

        let engine = SubtitleTranslationEngine(api: api)
        let outcome = await engine.translate(
            texts: [firstText, secondText],
            totalLineCount: 2,
            serviceID: 5,
            fromLanguage: "",
            toLanguage: "ZH",
            fileName: "episode.srt"
        )

        XCTAssertEqual(outcome.translations[firstText], "丙")
        XCTAssertEqual(outcome.translations[secondText], "丁")
        XCTAssertTrue(outcome.hasContentFilterFailure)
        XCTAssertEqual(outcome.failures.count, 1)
    }

    func testEngineLimitsConcurrencyToFour() async {
        let counter = ConcurrencyCounter()
        let texts = (0..<12).map { String(repeating: "\($0)", count: 300) }

        let api = FakeSubtitleTranslationAPI { request in
            counter.begin()
            try? await Task.sleep(nanoseconds: 60_000_000)
            counter.end()
            let translation = Dictionary(uniqueKeysWithValues: request.texts.map { ($0, "translated") })
            return SubtitleTranslateResponse(success: true, translation: translation, usage: 1, countRemain: 100)
        }

        let engine = SubtitleTranslationEngine(api: api, maxConcurrentBatches: 4)
        let outcome = await engine.translate(
            texts: texts,
            totalLineCount: texts.count,
            serviceID: 5,
            fromLanguage: "",
            toLanguage: "ZH",
            fileName: "episode.srt"
        )

        XCTAssertEqual(outcome.translations.count, texts.count)
        XCTAssertEqual(outcome.totalBatchCount, texts.count)
        XCTAssertLessThanOrEqual(counter.maximum, 4)
        XCTAssertEqual(counter.maximum, 4)
    }
}

// MARK: - Test doubles

private final class FakeSubtitleTranslationAPI: SubtitleTranslationAPIProviding {
    private let handler: (SubtitleTranslateRequest) async throws -> SubtitleTranslateResponse

    init(handler: @escaping (SubtitleTranslateRequest) async throws -> SubtitleTranslateResponse) {
        self.handler = handler
    }

    func translate(_ request: SubtitleTranslateRequest) async throws -> SubtitleTranslateResponse {
        try await handler(request)
    }

    func fetchServices() async throws -> SubtitleServiceListResponse {
        SubtitleServiceListResponse(success: true, services: [])
    }

    func fetchUsage() async throws -> SubtitleServiceUsageResponse {
        SubtitleServiceUsageResponse(success: true)
    }
}

private final class ConcurrencyCounter {
    private let lock = NSLock()
    private var current = 0
    private(set) var maximum = 0

    func begin() {
        lock.lock()
        current += 1
        maximum = max(maximum, current)
        lock.unlock()
    }

    func end() {
        lock.lock()
        current -= 1
        lock.unlock()
    }
}

private extension URLRequest {
    /// URLSession 交给 URLProtocol 时，body 往往变成 httpBodyStream。
    var anixBodyData: Data? {
        if let httpBody = httpBody {
            return httpBody
        }
        guard let stream = httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let read = stream.read(&buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
