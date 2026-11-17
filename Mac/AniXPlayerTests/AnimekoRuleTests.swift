import XCTest

final class AnimekoRuleTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - JSONPath search

    func testJSONPathSearchDedupPreferShorterNameAndKeywordFlags() async throws {
        let source = try makeSource("JSONPath 源")
        XCTAssertEqual(source.subjectFormat, "jsonpath")
        XCTAssertEqual(source.subjectJSONPathNames, "$[*]['title','name']")
        XCTAssertEqual(source.subjectJSONPathLinks, "$[*]['url','link']")
        XCTAssertTrue(source.preferShorterName)
        XCTAssertTrue(source.searchUseOnlyFirstWord)
        XCTAssertTrue(source.searchRemoveSpecial)

        let searchData = try fixtureData("jsonpath_search.json")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.host, "anime.example.com")
            let components = try XCTUnwrap(URLComponents(
                url: try XCTUnwrap(request.url),
                resolvingAgainstBaseURL: false
            ))
            XCTAssertEqual(
                components.queryItems?.first(where: { $0.name == "q" })?.value,
                "葬送的芙莉莲"
            )
            return (200, ["Content-Type": "application/json"], searchData)
        }

        let subjects = try await OnlineMediaResolver(httpClient: client)
            .search(source: source, keyword: "葬送的芙莉莲! 第二季")

        XCTAssertEqual(subjects.map(\.title), ["葬送的芙莉莲", "短名"])
        XCTAssertEqual(
            subjects[0].url?.absoluteString,
            "https://anime.example.com/anime/1"
        )
        XCTAssertEqual(
            subjects[1].url?.absoluteString,
            "https://anime.example.com/anime/2"
        )
        XCTAssertEqual(subjects[1].identityKey, "https://anime.example.com/anime/2")
    }

    func testJSONPathSearchWithoutSelectorsReportsClearError() async throws {
        let json = """
        {
          "exportedMediaSourceDataList": {
            "mediaSources": [
              {
                "arguments": {
                  "name": "缺少选择器",
                  "searchConfig": {
                    "searchUrl": "https://anime.example.com/search?q={keyword}",
                    "rawBaseUrl": "https://anime.example.com/",
                    "subjectFormatId": "jsonpath",
                    "selectorSubjectFormatJsonPathIndexed": {
                      "selectNames": "",
                      "selectLinks": "$[*].url"
                    }
                  }
                }
              }
            ]
          }
        }
        """
        let source = try XCTUnwrap(
            try OnlineSourceStore.parseAnimeko(data: Data(json.utf8)).first
        )
        let client = makeClient()
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/json"], Data("[]".utf8))
        }

        do {
            _ = try await OnlineMediaResolver(httpClient: client)
                .search(source: source, keyword: "测试")
            XCTFail("缺少 JSONPath 选择器时不应静默返回空结果")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("selectNames"))
        }
    }

    func testUnsupportedJSONPathOnlyFailsThatSource() async throws {
        let goodSource = try makeSource("JSONPath 源")
        let badSource = try makeSource("坏规则 源")
        let searchData = try fixtureData("jsonpath_search.json")
        let client = makeClient()

        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "application/json"], searchData)
        }

        let resolver = OnlineMediaResolver(httpClient: client)
        let goodSubjects = try await resolver.search(source: goodSource, keyword: "测试")
        XCTAssertEqual(goodSubjects.count, 2)

        var failure: Error?
        do {
            _ = try await resolver.search(source: badSource, keyword: "测试")
            XCTFail("不支持的 JSONPath 语法应抛出明确错误")
        } catch {
            failure = error
            XCTAssertTrue(error.localizedDescription.contains("JSONPath"))
        }

        let outcome = OnlineSearchMerger.makeOutcome(
            results: [
                OnlineSearchSourceResult(
                    source: badSource,
                    subjects: [],
                    error: failure
                ),
                OnlineSearchSourceResult(
                    source: goodSource,
                    subjects: goodSubjects,
                    error: nil
                )
            ],
            sourceCount: 2,
            pinnedSourceIDs: []
        )

        XCTAssertEqual(outcome.subjects.count, 2)
        XCTAssertNotNil(outcome.failures["坏规则 源"])
        XCTAssertEqual(outcome.sourceCount, 2)
    }

    // MARK: - Channels and episodes

    func testMatchChannelNameFiltersInvalidEpisodeLists() async throws {
        let source = try makeSource("JSONPath 源")
        let subject = OnlineSubject(
            source: source,
            title: "测试番剧",
            url: URL(string: "https://anime.example.com/anime/1")
        )
        let detail = try fixtureData("channel_detail.html")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://anime.example.com/anime/1"
            )
            return (200, ["Content-Type": "text/html; charset=utf-8"], detail)
        }

        let episodes = try await OnlineMediaResolver(httpClient: client)
            .loadEpisodes(source: source, subject: subject)

        XCTAssertEqual(episodes.map(\.title), ["第1集", "第2集"])
        XCTAssertEqual(
            episodes.map(\.url.absoluteString),
            [
                "https://anime.example.com/play/1-1.html",
                "https://anime.example.com/play/1-2.html"
            ]
        )
        XCTAssertFalse(episodes.contains { $0.url.absoluteString.contains("/play/2-") })
    }

    func testShowAllEpisodesControlsUnmatchedEpisodeFiltering() async throws {
        let defaultSource = try makeSource("DefaultEpisodes 源")
        let allSource = try makeSource("ShowAllEpisodes 源")
        XCTAssertFalse(defaultSource.showAllEpisodes)
        XCTAssertTrue(allSource.showAllEpisodes)

        let subject = OnlineSubject(
            source: defaultSource,
            title: "测试番剧",
            url: URL(string: "https://anime.example.com/anime/3")
        )
        let detail = try fixtureData("episodes_detail.html")
        let client = makeClient()
        StubURLProtocol.handler = { _ in
            (200, ["Content-Type": "text/html; charset=utf-8"], detail)
        }

        let resolver = OnlineMediaResolver(httpClient: client)
        let filtered = try await resolver.loadEpisodes(source: defaultSource, subject: subject)
        XCTAssertEqual(filtered.map(\.title), ["第1集", "第2集"])

        let all = try await resolver.loadEpisodes(source: allSource, subject: subject)
        XCTAssertEqual(all.map(\.title), ["第1集", "第2集", "剧场版"])
    }

    func testDefaultShowAllEpisodesIsFalseWhenFieldMissing() throws {
        let sources = try makeSources()
        let defaultSource = try XCTUnwrap(sources.first { $0.name == "DefaultEpisodes 源" })
        XCTAssertFalse(defaultSource.showAllEpisodes)
    }

    // MARK: - Helpers

    private func makeSources() throws -> [OnlineMediaSource] {
        return try OnlineSourceStore.parseAnimeko(data: try fixtureData("rules.json"))
    }

    private func makeSource(_ name: String) throws -> OnlineMediaSource {
        let sources = try makeSources()
        return try XCTUnwrap(sources.first { $0.name == name })
    }

    private func makeClient() -> OnlineHTTPClient {
        let configuration = OnlineHTTPClient.defaultConfiguration()
        configuration.protocolClasses = [StubURLProtocol.self]
        return OnlineHTTPClient(configuration: configuration)
    }

    private func fixtureData(_ name: String) throws -> Data {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Animeko", isDirectory: true)
        return try Data(contentsOf: directory.appendingPathComponent(name))
    }
}
