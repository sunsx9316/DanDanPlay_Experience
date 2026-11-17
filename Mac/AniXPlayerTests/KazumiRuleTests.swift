import XCTest

final class KazumiRuleTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - JSONPath

    func testJSONPathSubset() throws {
        let document: [String: Any] = [
            "list": [
                ["name": "A", "id": 11],
                ["name": "B", "id": 12]
            ],
            "data": [
                "records": [
                    ["title": "C"]
                ]
            ],
            "weird key": "value"
        ]

        XCTAssertEqual(
            try KazumiJSONPath.read(document, path: "$.list[*].name").compactMap { $0 as? String },
            ["A", "B"]
        )
        XCTAssertEqual(
            try KazumiJSONPath.first(in: document, path: "$.list[0].id") as? Int,
            11
        )
        XCTAssertEqual(
            try KazumiJSONPath.first(in: document, path: "$.list[-1].name") as? String,
            "B"
        )
        XCTAssertEqual(
            try KazumiJSONPath.first(in: document, path: "$.data.records[*].title") as? String,
            "C"
        )
        XCTAssertEqual(
            try KazumiJSONPath.first(in: document, path: "$['weird key']") as? String,
            "value"
        )
        XCTAssertEqual(
            try KazumiJSONPath.read(document, path: "$..name").compactMap { $0 as? String },
            ["A", "B"]
        )
        XCTAssertThrowsError(try KazumiJSONPath.read(document, path: "list[*]"))
    }

    // MARK: - Search API

    func testLMMSearchGETAndSourceTemplate() async throws {
        let source = try makeSource("lmm_rule.json")
        let searchData = try fixtureData("lmm_search.json")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "GET")
            XCTAssertEqual(request.url?.host, "www.lmm22.com")
            let components = try XCTUnwrap(URLComponents(
                url: try XCTUnwrap(request.url),
                resolvingAgainstBaseURL: false
            ))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            })
            XCTAssertEqual(query["mid"], "1")
            XCTAssertEqual(query["wd"], "葬送的芙莉莲 第二季")
            return (200, ["Content-Type": "application/json; charset=utf-8"], searchData)
        }

        let subjects = try await OnlineMediaResolver(httpClient: client)
            .search(source: source, keyword: "葬送的芙莉莲 第二季")

        XCTAssertEqual(subjects.count, 2)
        XCTAssertEqual(subjects[0].title, "葬送的芙莉莲")
        XCTAssertEqual(subjects[0].sourceToken, "42")
        XCTAssertEqual(
            subjects[0].url?.absoluteString,
            "https://www.lmm22.com/index.php/vod/detail/id/42.html"
        )
        XCTAssertEqual(
            subjects[1].url?.absoluteString,
            "https://www.lmm22.com/index.php/vod/detail/id/43.html"
        )
        XCTAssertTrue(source.detail.contains("API 搜索"))
        XCTAssertTrue(source.detail.contains("XPath 选集"))
    }

    func testTvTFunSearchWithBaseURLWithoutTrailingSlash() async throws {
        let source = try makeSource("tvtfun_rule.json")
        let searchData = try fixtureData("tvtfun_search.json")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            let components = try XCTUnwrap(URLComponents(
                url: try XCTUnwrap(request.url),
                resolvingAgainstBaseURL: false
            ))
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            })
            XCTAssertEqual(query["keyword"], "测试番剧")
            XCTAssertEqual(query["page"], "1")
            XCTAssertEqual(query["pageSize"], "24")
            return (200, ["Content-Type": "application/json"], searchData)
        }

        let subjects = try await OnlineMediaResolver(httpClient: client)
            .search(source: source, keyword: "测试番剧")

        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(
            subjects[0].url?.absoluteString,
            "https://www.tvtfun.net/watch/test-anime/1"
        )
    }

    func testXfdmPOSTSearchJSONBodyAndHeaders() async throws {
        let source = try makeSource("xfdm_rule.json")
        let searchData = try fixtureData("xfdm_search.json")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.value(forHTTPHeaderField: "apikey"), "test-key")
            XCTAssertEqual(
                request.value(forHTTPHeaderField: "Authorization"),
                "Bearer test-key"
            )
            XCTAssertTrue(
                request.value(forHTTPHeaderField: "Content-Type")?
                    .contains("application/json") == true
            )

            let body = try XCTUnwrap(Self.bodyData(of: request))
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["search_term"] as? String, "测试番剧")
            XCTAssertEqual(json["page_number"] as? Int, 1)
            XCTAssertEqual(json["items_per_page"] as? Int, 24)
            return (200, ["Content-Type": "application/json"], searchData)
        }

        let subjects = try await OnlineMediaResolver(httpClient: client)
            .search(source: source, keyword: "测试番剧")

        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].title, "测试番剧")
        XCTAssertEqual(subjects[0].sourceToken, "uuid-1")
        // sourceTemplate 为空时不能把内部 ID 伪造成 URL。
        XCTAssertNil(subjects[0].url)
    }

    func testEmptySourceTemplateKeepsTokenButNoURL() async throws {
        let source = try makeSource("giri_rule.json")
        let searchData = try fixtureData("giri_search.json")
        let client = makeClient()

        StubURLProtocol.handler = { _ in
            return (200, ["Content-Type": "application/json"], searchData)
        }

        let subjects = try await OnlineMediaResolver(httpClient: client)
            .search(source: source, keyword: "测试番剧")

        XCTAssertEqual(subjects.count, 1)
        XCTAssertEqual(subjects[0].sourceToken, "77")
        XCTAssertNil(subjects[0].url)
        XCTAssertEqual(subjects[0].identityKey, "kazumi:giriGiriLove|token:77")
    }

    func testAPISearchWithoutTemplateUsesURLFieldForXPathChapters() async throws {
        let source = try makeSource("mgnacg_rule.json")
        XCTAssertTrue(source.detail.contains("搜索结果 URL"))

        let searchData = try fixtureData("mgnacg_search.json")
        let detail = try fixtureData("mgnacg_detail.html")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path.contains("suggest") {
                return (200, ["Content-Type": "application/json"], searchData)
            }
            if url.path == "/media/101.html" {
                return (200, ["Content-Type": "text/html; charset=utf-8"], detail)
            }
            XCTFail("不应猜测或请求其他详情页地址：\(url.absoluteString)")
            return (404, [:], Data())
        }

        let resolver = OnlineMediaResolver(httpClient: client)
        let subjects = try await resolver.search(source: source, keyword: "测试番剧")

        XCTAssertEqual(
            subjects.map(\.title),
            ["有相对 URL", "没有 URL", "有绝对 URL", "URL 字段是裸 ID"]
        )
        XCTAssertEqual(
            subjects[0].url?.absoluteString,
            "https://www.mgnacg.com/media/101.html"
        )
        XCTAssertNil(subjects[1].url)
        XCTAssertEqual(
            subjects[2].url?.absoluteString,
            "https://www.mgnacg.com/media/103.html"
        )
        XCTAssertNil(subjects[3].url)

        let episodes = try await resolver.loadEpisodes(source: source, subject: subjects[0])
        XCTAssertEqual(episodes.map(\.title), ["第1集", "第2集"])
        XCTAssertEqual(
            episodes[0].url.absoluteString,
            "https://www.mgnacg.com/play/101-1.html"
        )

        do {
            _ = try await resolver.loadEpisodes(source: source, subject: subjects[1])
            XCTFail("没有详情页 URL 时不应伪造地址")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("XPath"))
            XCTAssertTrue(error.localizedDescription.contains("URL"))
        }
    }

    func testSourceTemplateEncodingRelativeAndAbsoluteSource() throws {
        let searchJSON = """
        {
          "list": [
            { "id": "abc/def", "name": "相对模板" },
            { "id": "https://cdn.example.com/watch/7?x=1", "name": "绝对地址" }
          ]
        }
        """

        let relativeConfig = KazumiSearchAPIConfig(json: [
            "request": [
                "method": "GET",
                "url": "https://api.example.com/search"
            ],
            "listPath": "$.list[*]",
            "namePath": "$.name",
            "sourcePath": "$.id",
            "sourceTemplate": "detail/@source.html"
        ])
        let base = try XCTUnwrap(URL(string: "https://www.example.com/media/"))
        let relativeItems = try KazumiAPISearchParser.parse(
            text: searchJSON,
            config: relativeConfig,
            baseURL: base
        )
        XCTAssertEqual(
            relativeItems[0].url?.absoluteString,
            "https://www.example.com/media/detail/abc%2Fdef.html"
        )

        let absoluteConfig = KazumiSearchAPIConfig(json: [
            "request": [
                "method": "GET",
                "url": "https://api.example.com/search"
            ],
            "listPath": "$.list[*]",
            "namePath": "$.name",
            "sourcePath": "$.id",
            "sourceTemplate": "@source"
        ])
        let absoluteItems = try KazumiAPISearchParser.parse(
            text: searchJSON,
            config: absoluteConfig,
            baseURL: base
        )
        XCTAssertEqual(
            absoluteItems[1].url?.absoluteString,
            "https://cdn.example.com/watch/7?x=1"
        )
    }

    func testInvalidJSONPathRuleIsSkippedWithClearReason() throws {
        let invalid = """
        {
          "name": "BadJSONPath",
          "version": "1.0",
          "baseURL": "https://www.example.com/media/",
          "searchMode": "api",
          "chapterMode": "xpath",
          "searchApiConfig": {
            "request": { "method": "GET", "url": "https://api.example.com/search" },
            "listPath": "$.list[?(@.id > 1)]",
            "namePath": "$.name",
            "sourcePath": "$.id"
          },
          "chapterRoads": "//ul[@class='episodes']",
          "chapterResult": ".//a"
        }
        """
        switch try parseRuleResult(json: invalid) {
        case .loaded:
            XCTFail("不支持的 JSONPath 语法不应让规则静默加载")
        case .skipped(let name, let reason):
            XCTAssertEqual(name, "BadJSONPath")
            XCTAssertTrue(reason.contains("JSONPath"))
        }

        // 同一批规则里其他规则仍应正常解析。
        let valid = try makeSource("lmm_rule.json")
        XCTAssertEqual(valid.name, "LMM")

        let filterRule = """
        {
          "name": "FilteredAPI",
          "version": "1.0",
          "baseURL": "https://www.example.com/media/",
          "searchMode": "api",
          "chapterMode": "xpath",
          "searchApiConfig": {
            "request": { "method": "GET", "url": "https://api.example.com/search" },
            "listPath": "$.list[?(@.type == 'anime')]",
            "namePath": "$.name",
            "sourcePath": "$.id"
          },
          "chapterRoads": "//ul[@class='episodes']",
          "chapterResult": ".//a"
        }
        """
        switch try parseRuleResult(json: filterRule) {
        case .loaded(let source):
            XCTAssertEqual(source.name, "FilteredAPI")
        case .skipped(_, let reason):
            XCTFail("常用过滤表达式不应导致规则被跳过：\(reason)")
        }
    }

    func testLegacyXPathUsePostSendsFormBody() async throws {
        let rule = """
        {
          "name": "PostXPath",
          "version": "1.0",
          "baseURL": "https://post.example.com/",
          "searchURL": "https://post.example.com/search?wd=@keyword&submit=",
          "searchList": "//div[contains(@class,'search-results-section')]/*[contains(@class,'video-card')]",
          "searchName": "//span[contains(@class,'video-card-title')]",
          "searchResult": ".",
          "chapterRoads": "//section[@class='anthology']",
          "chapterResult": "//a",
          "usePost": true,
          "searchMode": "xpath",
          "chapterMode": "xpath"
        }
        """
        let source = try makeSource(json: rule)
        let html = try fixtureData("xpath_search.html")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.query, nil)
            XCTAssertEqual(request.url?.path, "/search")
            let body = try XCTUnwrap(Self.bodyData(of: request))
            let text = try XCTUnwrap(String(data: body, encoding: .utf8))
            XCTAssertTrue(text.contains("wd=%E6%B5%8B%E8%AF%95"))
            XCTAssertTrue(text.contains("submit="))
            return (200, ["Content-Type": "text/html"], html)
        }

        let subjects = try await OnlineMediaResolver(httpClient: client)
            .search(source: source, keyword: "测试")

        XCTAssertEqual(subjects.count, 2)
        XCTAssertEqual(subjects[0].title, "搜索结果 A")
        XCTAssertEqual(
            subjects[0].url?.absoluteString,
            "https://post.example.com/anime/100.html"
        )
        XCTAssertEqual(subjects[1].title, "搜索结果 B")
        XCTAssertEqual(
            subjects[1].url?.absoluteString,
            "https://post.example.com/detail/101.html"
        )
    }

    // MARK: - Chapter API

    func testDelimitedChapterAPIWithEpisodePageAndAlternates() async throws {
        let source = try makeSource("giri_rule.json")
        let searchData = try fixtureData("giri_search.json")
        let detail = try fixtureData("giri_detail.json")
        let client = makeClient()

        StubURLProtocol.handler = { request in
            let url = try XCTUnwrap(request.url)
            if url.path.contains("get_list") {
                let components = try XCTUnwrap(URLComponents(
                    url: url,
                    resolvingAgainstBaseURL: false
                ))
                XCTAssertEqual(
                    components.queryItems?.first(where: { $0.name == "vod_name" })?.value,
                    "测试番剧"
                )
                return (200, ["Content-Type": "application/json"], searchData)
            }

            let components = try XCTUnwrap(URLComponents(
                url: url,
                resolvingAgainstBaseURL: false
            ))
            XCTAssertEqual(
                components.queryItems?.first(where: { $0.name == "vod_id" })?.value,
                "77"
            )
            return (200, ["Content-Type": "application/json"], detail)
        }

        let resolver = OnlineMediaResolver(httpClient: client)
        let subjects = try await resolver.search(source: source, keyword: "测试番剧")
        let subject = try XCTUnwrap(subjects.first)
        XCTAssertNil(subject.url)
        XCTAssertEqual(subject.sourceToken, "77")

        let episodes = try await resolver.loadEpisodes(source: source, subject: subject)

        XCTAssertEqual(episodes.count, 2)
        XCTAssertEqual(episodes[0].title, "第1集")
        XCTAssertEqual(episodes[0].roadName, "线路A")
        XCTAssertEqual(episodes[0].alternateURLs.count, 1)
        XCTAssertEqual(episodes[1].alternateURLs.count, 1)

        let first = try XCTUnwrap(URLComponents(
            url: episodes[0].url,
            resolvingAgainstBaseURL: false
        ))
        XCTAssertEqual(first.host, "pl.girigirilove.com")
        XCTAssertEqual(first.path, "/addons/aplyer/atom.php")
        XCTAssertEqual(
            first.queryItems?.first(where: { $0.name == "url" })?.value,
            "https://a.example.com/play/1"
        )

        let alternate = try XCTUnwrap(URLComponents(
            url: episodes[0].alternateURLs[0],
            resolvingAgainstBaseURL: false
        ))
        XCTAssertEqual(
            alternate.queryItems?.first(where: { $0.name == "url" })?.value,
            "https://b.example.com/play/1"
        )
    }

    func testAPISearchWithXPathChaptersStillLoadsEpisodes() async throws {
        let source = try makeSource("lmm_rule.json")
        let detail = try fixtureData("lmm_detail.html")
        let subject = OnlineSubject(
            source: source,
            title: "葬送的芙莉莲",
            url: URL(string: "https://www.lmm22.com/index.php/vod/detail/id/42.html"),
            sourceToken: "42"
        )
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(
                request.url?.absoluteString,
                "https://www.lmm22.com/index.php/vod/detail/id/42.html"
            )
            return (200, ["Content-Type": "text/html; charset=utf-8"], detail)
        }

        let episodes = try await OnlineMediaResolver(httpClient: client)
            .loadEpisodes(source: source, subject: subject)

        XCTAssertEqual(episodes.map(\.title), ["第1集", "第2集"])
        XCTAssertEqual(
            episodes[0].url.absoluteString,
            "https://www.lmm22.com/play/42-1-1.html"
        )
    }

    func testNestedChapterAPIWithSourceAndEpisodeURL() async throws {
        let source = try makeSource("sorani_rule.json")
        let detail = try fixtureData("sorani_detail.json")
        let subject = OnlineSubject(
            source: source,
            title: "测试番剧",
            url: nil,
            sourceToken: "123"
        )
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/sorani-cms/api/video/123")
            return (200, ["Content-Type": "application/json"], detail)
        }

        let episodes = try await OnlineMediaResolver(httpClient: client)
            .loadEpisodes(source: source, subject: subject)

        XCTAssertEqual(episodes.map(\.title), ["第1话", "第2话"])
        XCTAssertEqual(
            episodes[0].url.absoluteString,
            "https://www.sorani.net/anime/mal/123/episode/1"
        )
        XCTAssertEqual(
            episodes[1].url.absoluteString,
            "https://www.sorani.net/anime/mal/123/episode/2"
        )
        XCTAssertTrue(episodes[0].alternateURLs.isEmpty)
    }

    func testNestedChapterAPIPOSTBodyAndAlternates() async throws {
        let source = try makeSource("xfdm_rule.json")
        let detail = try fixtureData("xfdm_detail.json")
        let subject = OnlineSubject(
            source: source,
            title: "测试番剧",
            url: nil,
            sourceToken: "uuid-1"
        )
        let client = makeClient()

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.httpMethod, "POST")
            let body = try XCTUnwrap(Self.bodyData(of: request))
            let json = try XCTUnwrap(
                JSONSerialization.jsonObject(with: body) as? [String: Any]
            )
            XCTAssertEqual(json["p_id"] as? String, "uuid-1")
            return (200, ["Content-Type": "application/json"], detail)
        }

        let episodes = try await OnlineMediaResolver(httpClient: client)
            .loadEpisodes(source: source, subject: subject)

        XCTAssertEqual(episodes.map(\.title), ["第1话", "第2话"])
        XCTAssertEqual(
            episodes[0].url.absoluteString,
            "https://next.xifanacg.com/anime/uuid-1/play/ep-1"
        )
        XCTAssertEqual(
            episodes[0].alternateURLs.first?.absoluteString,
            "https://next.xifanacg.com/anime/uuid-1/play/ep-1-alt"
        )
    }

    func testAPIWithoutTemplateAndXPathChaptersReportsUnsupported() async throws {
        let rule = """
        {
          "name": "NoTemplate",
          "version": "1.0",
          "baseURL": "https://www.example.com/media/",
          "searchMode": "api",
          "chapterMode": "xpath",
          "searchApiConfig": {
            "request": { "method": "GET", "url": "https://api.example.com/search", "query": { "q": "@keyword" } },
            "listPath": "$.list[*]",
            "namePath": "$.name",
            "sourcePath": "$.id",
            "sourceTemplate": ""
          },
          "chapterRoads": "//ul[@class='episodes']",
          "chapterResult": ".//a"
        }
        """
        let source = try makeSource(json: rule)
        XCTAssertTrue(source.detail.contains("搜索结果 URL"))
        let subject = OnlineSubject(
            source: source,
            title: "测试番剧",
            url: nil,
            sourceToken: "123"
        )
        let client = makeClient()

        do {
            _ = try await OnlineMediaResolver(httpClient: client)
                .loadEpisodes(source: source, subject: subject)
            XCTFail("没有详情页地址时不应伪造 URL 或返回空剧集")
        } catch {
            XCTAssertTrue(error.localizedDescription.contains("XPath"))
        }
    }

    // MARK: - XPath and URL

    func testRelativeXPathUnionFollowingSiblingAndHrefLookup() throws {
        let source = try makeSource("ezdmw_rule.json")
        let html = try fixtureData("ezdmw_chapter.html")
        let document = try OnlineHTMLDocument(
            html: String(decoding: html, as: UTF8.self),
            baseURL: URL(string: "https://m.ezdmw.org/")
        )

        let roads = document.nodes(xpath: source.kazumiChapterRoads)
        XCTAssertEqual(roads.count, 3)
        var episodes: [XMLNode] = []
        for road in roads {
            episodes.append(contentsOf: document.nodes(
                xpath: source.kazumiChapterResult,
                in: road
            ))
        }
        XCTAssertEqual(episodes.count, 4)

        XCTAssertEqual(
            document.href(of: episodes[0])?.absoluteString,
            "https://m.ezdmw.org/play/1-1.html"
        )
        XCTAssertEqual(
            document.href(of: episodes[1])?.absoluteString,
            "https://m.ezdmw.org/?ep=2"
        )
        XCTAssertEqual(
            document.href(of: episodes[2])?.absoluteString,
            "https://cdn.example.com/play/2-1.html"
        )
        XCTAssertEqual(
            document.href(of: episodes[3])?.absoluteString,
            "https://m.ezdmw.org/play/3-1.html"
        )

        let searchHTML = try fixtureData("xpath_search.html")
        let searchDocument = try OnlineHTMLDocument(
            html: String(decoding: searchHTML, as: UTF8.self),
            baseURL: URL(string: "https://post.example.com/")
        )
        let cards = searchDocument.nodes(
            xpath: "//div[contains(@class,'search-results-section')]/*[contains(@class,'video-card')]"
        )
        XCTAssertEqual(cards.count, 3)
        XCTAssertEqual(
            searchDocument.href(of: cards[0])?.absoluteString,
            "https://post.example.com/anime/100.html"
        )
        XCTAssertEqual(
            searchDocument.href(of: cards[1])?.absoluteString,
            "https://post.example.com/detail/101.html"
        )
        XCTAssertNil(searchDocument.href(of: cards[2]))
    }

    func testURLJoinBoundaries() throws {
        let https = URL(string: "https://site.example.com")!
        let page = URL(string: "https://site.example.com/path/page.html")!

        XCTAssertEqual(
            KazumiURL.resolve("https://cdn.example.com/a.m3u8", base: https)?.absoluteString,
            "https://cdn.example.com/a.m3u8"
        )
        XCTAssertEqual(
            KazumiURL.resolve("//cdn.example.com/a.m3u8", base: https)?.absoluteString,
            "https://cdn.example.com/a.m3u8"
        )
        XCTAssertEqual(
            KazumiURL.resolve("?ep=2", base: page)?.absoluteString,
            "https://site.example.com/path/page.html?ep=2"
        )
        XCTAssertEqual(
            KazumiURL.resolve("/root/x", base: https)?.absoluteString,
            "https://site.example.com/root/x"
        )
        XCTAssertEqual(
            KazumiURL.resolve("sub/page", base: https)?.absoluteString,
            "https://site.example.com/sub/page"
        )
        XCTAssertEqual(
            KazumiURL.resolve("detail/1", base: page)?.absoluteString,
            "https://site.example.com/path/detail/1"
        )
        XCTAssertEqual(
            KazumiURL.resolve("//cdn.example.com/x", base: nil)?.absoluteString,
            "https://cdn.example.com/x"
        )
        XCTAssertEqual(
            KazumiURL.resolve(
                "https%3A%2F%2Fcdn.example.com%2Fa%2Fb.m3u8",
                base: https
            )?.absoluteString,
            "https://cdn.example.com/a/b.m3u8"
        )
        XCTAssertNil(KazumiURL.resolve("/relative", base: nil))
        XCTAssertNil(KazumiURL.resolve("javascript:void(0)", base: https))
        XCTAssertNil(KazumiURL.resolve("#", base: page))
    }

    // MARK: - Isolation and diagnostics

    func testSingleSourceFailureIsolation() throws {
        let good = try makeSource("lmm_rule.json")
        let bad = try makeSource("giri_rule.json")
        let subject = OnlineSubject(
            source: good,
            title: "可用结果",
            url: URL(string: "https://www.lmm22.com/index.php/vod/detail/id/42.html"),
            sourceToken: "42"
        )

        let outcome = OnlineSearchMerger.makeOutcome(
            results: [
                OnlineSearchSourceResult(
                    source: bad,
                    subjects: [],
                    error: NSError(domain: "KazumiTest", code: 500)
                ),
                OnlineSearchSourceResult(
                    source: good,
                    subjects: [subject],
                    error: nil
                )
            ],
            sourceCount: 2,
            pinnedSourceIDs: []
        )

        XCTAssertEqual(outcome.subjects.map(\.title), ["可用结果"])
        XCTAssertEqual(outcome.failures.count, 1)
        XCTAssertNotNil(outcome.failures["giriGiriLove"])
        XCTAssertEqual(outcome.sourceCount, 2)
    }

    func testRuleParserReportsUnsupportedReasonAndKeepsUnknownFields() throws {
        let invalid = """
        {
          "name": "BrokenAPI",
          "searchMode": "api",
          "chapterMode": "xpath",
          "searchURL": "",
          "chapterRoads": "//div",
          "chapterResult": "//a",
          "useLegacyParser": true,
          "muliSources": true,
          "useWebview": true
        }
        """
        switch try parseRuleResult(json: invalid) {
        case .loaded:
            XCTFail("缺少 searchApiConfig 的 API 规则不应被加载")
        case .skipped(let name, let reason):
            XCTAssertEqual(name, "BrokenAPI")
            XCTAssertTrue(reason.contains("searchApiConfig"))
        }

        let valid = """
        {
          "name": "MixedAPI",
          "version": "1.0",
          "baseURL": "",
          "usePost": true,
          "useLegacyParser": true,
          "muliSources": true,
          "useWebview": true,
          "antiCrawlerConfig": { "enabled": true },
          "searchMode": "api",
          "chapterMode": "api",
          "searchApiConfig": {
            "request": { "method": "GET", "url": "https://api.example.com/search", "query": { "q": "@keyword" } },
            "listPath": "$[*]",
            "namePath": "$.name",
            "sourcePath": "$.id"
          },
          "chapterApiConfig": {
            "request": { "method": "GET", "url": "https://api.example.com/detail", "query": { "id": "@source" } },
            "format": "nested",
            "roadsPath": "$.data[*]",
            "episodesPath": "$.episodes[*]",
            "episodeNamePath": "$.name",
            "episodeUrlPath": "$.url"
          }
        }
        """
        switch try parseRuleResult(json: valid) {
        case .loaded(let source):
            XCTAssertEqual(source.name, "MixedAPI")
            XCTAssertTrue(source.detail.contains("API 搜索"))
            XCTAssertTrue(source.detail.contains("API 选集"))
            XCTAssertTrue(source.detail.contains("反爬"))
            XCTAssertNil(source.baseURL)
            XCTAssertEqual(source.kazumiAPI?.usePost, true)
        case .skipped(_, let reason):
            XCTFail("未知字段不应导致规则失败：\(reason)")
        }
    }

    // MARK: - Helpers

    private func makeClient() -> OnlineHTTPClient {
        let configuration = OnlineHTTPClient.defaultConfiguration()
        configuration.protocolClasses = [StubURLProtocol.self]
        return OnlineHTTPClient(configuration: configuration)
    }

    private func makeSource(_ fixture: String) throws -> OnlineMediaSource {
        let data = try fixtureData(fixture)
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: data) as? [String: Any]
        )
        switch KazumiRuleParser.parse(object, index: 0) {
        case .loaded(let source):
            return source
        case .skipped(let name, let reason):
            throw NSError(
                domain: "KazumiTest",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(name): \(reason)"]
            )
        }
    }

    private func makeSource(json: String) throws -> OnlineMediaSource {
        switch try parseRuleResult(json: json) {
        case .loaded(let source):
            return source
        case .skipped(let name, let reason):
            throw NSError(
                domain: "KazumiTest",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "\(name): \(reason)"]
            )
        }
    }

    private func parseRuleResult(json: String) throws -> KazumiRuleParseResult {
        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(
                with: try XCTUnwrap(json.data(using: .utf8))
            ) as? [String: Any]
        )
        return KazumiRuleParser.parse(object, index: 0)
    }

    private func fixtureData(_ name: String) throws -> Data {
        let directory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/Kazumi", isDirectory: true)
        return try Data(contentsOf: directory.appendingPathComponent(name))
    }

    private static func bodyData(of request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
        defer { buffer.deallocate() }
        while stream.hasBytesAvailable {
            let read = stream.read(buffer, maxLength: bufferSize)
            if read <= 0 { break }
            data.append(buffer, count: read)
        }
        return data
    }
}
