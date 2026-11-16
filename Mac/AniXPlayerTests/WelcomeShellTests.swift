import XCTest

final class WelcomeShellTests: XCTestCase {

    private var client: APIClient!
    private let environment = APIEnvironment(host: "https://api.dandanplay.net", clientId: "test-client")

    override func setUp() {
        super.setUp()
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        client = APIClient(session: URLSession(configuration: configuration))
    }

    override func tearDown() {
        StubURLProtocol.handler = nil
        client = nil
        super.tearDown()
    }

    // MARK: - Helpers

    private func makeBangumi(
        id: Int,
        title: String,
        airDay: Int,
        isFavorited: Bool = false,
        isOnAir: Bool = true,
        rating: Double = 8.0
    ) -> BangumiIntro {
        let object: [String: Any] = [
            "animeId": id,
            "bangumiId": "\(id)",
            "animeTitle": title,
            "imageUrl": "https://example.com/\(id).jpg",
            "searchKeyword": title,
            "isOnAir": isOnAir,
            "airDay": airDay,
            "isFavorited": isFavorited,
            "isRestricted": false,
            "rating": rating,
        ]
        let data = try! JSONSerialization.data(withJSONObject: object)
        return try! JSONDecoder().decode(BangumiIntro.self, from: data)
    }

    private func makeHomePageService() -> HomePageService {
        let authenticated = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "token-1" },
            refreshHandler: { "token-2" }
        )
        return HomePageService(client: authenticated, environment: environment)
    }

    private func makeSeason(year: Int, month: Int, name: String) -> BangumiSeason {
        let object: [String: Any] = ["year": year, "month": month, "seasonName": name]
        let data = try! JSONSerialization.data(withJSONObject: object)
        return try! JSONDecoder().decode(BangumiSeason.self, from: data)
    }

    private func fixedCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 8 * 3600)!
        calendar.locale = Locale(identifier: "en_US_POSIX")
        return calendar
    }

    private func fixedMonday() -> Date {
        let calendar = fixedCalendar()
        return calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2026,
            month: 11,
            day: 16,
            hour: 12
        ))!
    }

    // MARK: - Homepage decoding

    func testDecodesHomepageWithSeasonFields() throws {
        let json = """
        {
          "banners": [
            {"id": 1, "title": "公告", "description": "描述", "url": "https://example.com", "imageUrl": "https://example.com/a.jpg"}
          ],
          "bangumiQueueIntroList": [
            {"animeId": 11, "animeTitle": "未看", "episodeTitle": "第 3 话", "airDate": "2026-11-16", "imageUrl": "", "description": "今天更新", "isOnAir": true}
          ],
          "shinBangumiList": [
            {"animeId": 21, "animeTitle": "本季", "airDay": 1, "isFavorited": true, "rating": 8.6}
          ],
          "bangumiSeasons": [
            {"year": 2026, "month": 10, "seasonName": "2026年10月"}
          ],
          "shinBangumiOfCurrentSeason": [
            {"animeId": 31, "animeTitle": "当前季", "airDay": 2, "isFavorited": false, "rating": 7.5}
          ],
          "shinBangumiOfPreviousSeason": [
            {"animeId": 41, "animeTitle": "上一季", "airDay": 3, "isFavorited": false, "rating": 7.0}
          ]
        }
        """.data(using: .utf8)!

        let homepage = try JSONDecoder().decode(Homepage.self, from: json)
        XCTAssertEqual(homepage.banners.count, 1)
        XCTAssertEqual(homepage.banners[0].id, 1)
        XCTAssertEqual(homepage.bangumiQueueIntroList.count, 1)
        XCTAssertEqual(homepage.bangumiQueueIntroList[0].animeId, 11)
        XCTAssertEqual(homepage.shinBangumiList.count, 1)
        XCTAssertEqual(homepage.bangumiSeasons.count, 1)
        XCTAssertEqual(homepage.bangumiSeasons[0].year, 2026)
        XCTAssertEqual(homepage.shinBangumiOfCurrentSeason.count, 1)
        XCTAssertEqual(homepage.shinBangumiOfCurrentSeason[0].animeId, 31)
        XCTAssertEqual(homepage.shinBangumiOfPreviousSeason.count, 1)
        XCTAssertEqual(homepage.shinBangumiOfPreviousSeason[0].animeId, 41)
    }

    func testDecodesHomepageWithMissingFields() throws {
        let homepage = try JSONDecoder().decode(Homepage.self, from: Data("{}".utf8))
        XCTAssertTrue(homepage.banners.isEmpty)
        XCTAssertTrue(homepage.bangumiQueueIntroList.isEmpty)
        XCTAssertTrue(homepage.shinBangumiList.isEmpty)
        XCTAssertTrue(homepage.bangumiSeasons.isEmpty)
        XCTAssertTrue(homepage.shinBangumiOfCurrentSeason.isEmpty)
        XCTAssertTrue(homepage.shinBangumiOfPreviousSeason.isEmpty)
    }

    func testCurrentSeasonBangumiFallsBackToCurrentSeasonField() throws {
        let json = """
        {
          "shinBangumiList": [],
          "shinBangumiOfCurrentSeason": [
            {"animeId": 31, "animeTitle": "当前季", "airDay": 2}
          ]
        }
        """.data(using: .utf8)!
        let homepage = try JSONDecoder().decode(Homepage.self, from: json)
        let items = WelcomeShellDataMapper.currentSeasonBangumi(from: homepage)
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].animeId, 31)
    }

    // MARK: - Today / sorting

    func testCurrentAirDayUsesServiceConvention() {
        let airDay = WelcomeShellDataMapper.currentAirDay(now: fixedMonday(), calendar: fixedCalendar())
        XCTAssertEqual(airDay, 1, "周一应映射为 1（0 为周日）")
    }

    func testTodayFilterAndFavoritedFirstSort() {
        let items = [
            makeBangumi(id: 1, title: "Alpha", airDay: 1),
            makeBangumi(id: 2, title: "Beta", airDay: 1, isFavorited: true),
            makeBangumi(id: 3, title: "Gamma", airDay: 2),
        ]

        let today = WelcomeShellDataMapper.todayBangumi(
            items,
            now: fixedMonday(),
            calendar: fixedCalendar()
        )
        XCTAssertEqual(today.map(\.animeId), [2, 1], "已关注优先，其次标题排序")
    }

    func testScheduleFilterSearchAndFavoritedTab() {
        let items = [
            makeBangumi(id: 1, title: "Alpha Story", airDay: 1, isFavorited: true),
            makeBangumi(id: 2, title: "Alpha Zero", airDay: 1),
            makeBangumi(id: 3, title: "Beta", airDay: 2, isFavorited: true),
        ]

        let weekday = WelcomeShellDataMapper.filterBangumi(
            items,
            filter: .weekday(1),
            searchText: "alpha"
        )
        XCTAssertEqual(weekday.map(\.animeId), [1, 2])

        let favorited = WelcomeShellDataMapper.filterBangumi(items, filter: .favorited)
        XCTAssertEqual(favorited.map(\.animeId), [1, 3])

        let all = WelcomeShellDataMapper.filterBangumi(items, filter: .all)
        XCTAssertEqual(all.map(\.animeId), [1, 3, 2], "全部页同样保持已关注优先")
    }

    // MARK: - Seasons

    func testSeasonOptionsDeduplicateAndKeepServerOrder() {
        let seasons = [
            makeSeason(year: 2026, month: 10, name: "2026年10月"),
            makeSeason(year: 2025, month: 7, name: "2025年7月"),
            makeSeason(year: 2026, month: 10, name: "重复"),
        ]
        let options = WelcomeShellDataMapper.seasonOptions(seasons: seasons)
        XCTAssertEqual(options.count, 3)
        XCTAssertTrue(options[0].isCurrentSeason)
        XCTAssertEqual(options[1].year, 2026)
        XCTAssertEqual(options[1].month, 10)
        XCTAssertEqual(options[1].title, "2026年10月")
        XCTAssertEqual(options[2].year, 2025)
    }

    // MARK: - Recent playback

    func testRecentItemsDeduplicateByStandardizedPathAndTruncate() {
        var items: [WelcomeRecentItem] = []
        for index in 0..<12 {
            items.append(WelcomeRecentItem(
                path: "/tmp/video-\(index).mp4",
                lastOpened: TimeInterval(100 + index),
                progress: Double(index) / 20.0,
                bookmark: nil
            ))
        }
        // 同一路径的旧记录应被较新的记录取代。
        items.append(WelcomeRecentItem(
            path: "/tmp/../tmp/video-0.mp4",
            lastOpened: 999,
            progress: 0.9,
            bookmark: nil
        ))

        let result = WelcomeShellDataMapper.recentItems(items, limit: 10)
        XCTAssertEqual(result.count, 10)
        XCTAssertEqual(result[0].lastOpened, 999)
        XCTAssertEqual(result[0].path, "/tmp/../tmp/video-0.mp4")
        XCTAssertEqual(result[0].progress, 0.9)
        XCTAssertEqual(Set(result.map(\.path)).count, 10, "去重后的路径唯一")
        XCTAssertFalse(result.contains { $0.path == "/tmp/video-0.mp4" })
    }

    func testRecentItemsOverviewLimit() {
        let items = (0..<5).map { index in
            WelcomeRecentItem(
                path: "/tmp/a-\(index).mp4",
                lastOpened: TimeInterval(index),
                progress: nil,
                bookmark: nil
            )
        }
        let result = WelcomeShellDataMapper.recentItems(items, limit: 3)
        XCTAssertEqual(result.map(\.lastOpened), [4, 3, 2])
    }

    func testPlaybackPositionTextUsesMinutesOrHours() {
        XCTAssertTrue(
            WelcomeShellDataMapper.playbackPositionText(position: 65, duration: 100)?.hasSuffix("01:05") == true
        )
        XCTAssertTrue(
            WelcomeShellDataMapper.playbackPositionText(position: 754, duration: 2700)?.hasSuffix("12:34") == true
        )
        XCTAssertTrue(
            WelcomeShellDataMapper.playbackPositionText(position: 3661, duration: 7200)?.hasSuffix("1:01:01") == true
        )
        XCTAssertNil(WelcomeShellDataMapper.playbackPositionText(position: nil, duration: 100))
        XCTAssertNil(WelcomeShellDataMapper.playbackPositionText(position: 10, duration: 0))
    }

    func testRecentItemDecodesLegacyRecordWithoutPosition() throws {
        let json = """
        {"path":"/tmp/a.mp4","lastOpened":100,"progress":0.5,"bookmark":null}
        """.data(using: .utf8)!
        let item = try JSONDecoder().decode(WelcomeRecentItem.self, from: json)
        XCTAssertEqual(item.progress, 0.5)
        XCTAssertNil(item.position)
        XCTAssertNil(item.duration)
    }

    // MARK: - Queue mapping

    func testQueueCardsMapBothIntroModels() throws {
        let v2JSON = """
        {"animeId": 7, "animeTitle": "测试", "episodeTitle": "第 5 话", "airDate": "2026-11-16T12:00:00", "imageUrl": "", "description": "今天更新", "isOnAir": true}
        """.data(using: .utf8)!
        let v2 = try JSONDecoder().decode(BangumiQueueIntroV2.self, from: v2JSON)
        let v2Cards = WelcomeShellDataMapper.queueCards(from: [v2])
        XCTAssertEqual(v2Cards.count, 1)
        XCTAssertEqual(v2Cards[0].animeId, 7)
        XCTAssertEqual(v2Cards[0].airDateText, "2026-11-16")

        let legacyJSON = """
        {"animeId": 8, "animeTitle": "旧版", "episodeTitle": "第 2 话", "airDate": "2026-11-15", "imageUrl": "", "description": "昨天更新", "isOnAir": false}
        """.data(using: .utf8)!
        let legacy = try JSONDecoder().decode(BangumiQueueIntro.self, from: legacyJSON)
        let legacyCards = WelcomeShellDataMapper.queueCards(from: [legacy])
        XCTAssertEqual(legacyCards[0].airDateText, "2026-11-15")
        XCTAssertFalse(legacyCards[0].isOnAir)
    }

    // MARK: - Online search decoding

    func testDecodesSearchResultAndEpisodes() throws {
        let json = """
        {
          "hasMore": false,
          "animes": [
            {
              "animeId": 100,
              "animeTitle": "测试番剧",
              "type": "tvseries",
              "typeDescription": "TV",
              "episodes": [
                {"episodeId": 1001, "episodeTitle": "第 1 话"},
                {"episodeId": 1002, "episodeTitle": "第 2 话"}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let result = try JSONDecoder().decode(SearchResult.self, from: json)
        XCTAssertFalse(result.hasMore)
        XCTAssertEqual(result.collection.count, 1)
        XCTAssertEqual(result.collection[0].animeId, 100)
        XCTAssertEqual(result.collection[0].animeTitle, "测试番剧")
        XCTAssertEqual(result.collection[0].collection.count, 2)
        XCTAssertEqual(result.collection[0].collection[0].id, 1001)
        XCTAssertEqual(result.collection[0].collection[0].episodeTitle, "第 1 话")
        XCTAssertEqual(result.collection[0].collection[0].animeTitle, "", "标题由网络层补齐，解码阶段为空")
    }

    func testDecodesEmptySearchResult() throws {
        let result = try JSONDecoder().decode(SearchResult.self, from: Data("{}".utf8))
        XCTAssertFalse(result.hasMore)
        XCTAssertTrue(result.collection.isEmpty)
    }
}


// MARK: - HomePageService

extension WelcomeShellTests {

    func testHomePageServiceRequestsHomepageAndDecodesNewFields() async throws {
        var capturedPath: String?
        var capturedQuery: [String: String] = [:]
        var capturedAuth: String?

        StubURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedAuth = request.value(forHTTPHeaderField: "Authorization")
            if let components = request.url.flatMap({ URLComponents(url: $0, resolvingAgainstBaseURL: false) }) {
                for item in components.queryItems ?? [] {
                    capturedQuery[item.name] = item.value
                }
            }
            let body = """
            {
              "banners": [{"id": 1, "title": "公告"}],
              "shinBangumiOfCurrentSeason": [{"animeId": 31, "animeTitle": "当前季"}],
              "bangumiSeasons": [{"year": 2026, "month": 10, "seasonName": "2026年10月"}]
            }
            """
            return (200, [:], Data(body.utf8))
        }

        let homepage = try await makeHomePageService().loadHomepage()
        XCTAssertEqual(capturedPath, "/api/v2/homePage")
        XCTAssertEqual(capturedQuery["filterAdultContent"], "true")
        XCTAssertEqual(capturedAuth, "Bearer token-1")
        XCTAssertEqual(homepage.banners.count, 1)
        XCTAssertEqual(homepage.shinBangumiOfCurrentSeason.count, 1)
        XCTAssertEqual(homepage.bangumiSeasons.count, 1)
    }

    func testHomePageServiceRequestsShinBangumiAndSendsBearer() async throws {
        var capturedPath: String?
        StubURLProtocol.handler = { request in
            capturedPath = request.url?.path
            let body = #"{"success":true,"bangumiList":[{"animeId":7,"animeTitle":"新番","airDay":1}]}"#
            return (200, [:], Data(body.utf8))
        }

        let items = try await makeHomePageService().loadShinBangumi()
        XCTAssertEqual(capturedPath, "/api/v2/bangumi/shin")
        XCTAssertEqual(items.count, 1)
        XCTAssertEqual(items[0].animeId, 7)
    }

    func testHomePageServiceRequestsSeasonAndSurfacesServerError() async {
        StubURLProtocol.handler = { _ in
            let body = #"{"success":false,"errorMessage":"没有权限"}"#
            return (200, [:], Data(body.utf8))
        }

        do {
            _ = try await makeHomePageService().loadSeasonBangumi(year: 2026, month: 10)
            XCTFail("应当抛出服务端错误")
        } catch {
            XCTAssertEqual(error.localizedDescription, "没有权限")
        }
    }

    func testHomePageServiceSearchFillsEpisodeAnimeTitle() async throws {
        var capturedPath: String?
        var capturedKeyword: String?
        StubURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedKeyword = request.url
                .flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }?
                .queryItems?
                .first(where: { $0.name == "anime" })?
                .value
            let body = """
            {
              "animes": [
                {
                  "animeId": 100,
                  "animeTitle": "测试番剧",
                  "type": "tvseries",
                  "episodes": [{"episodeId": 1001, "episodeTitle": "第 1 话"}]
                }
              ]
            }
            """
            return (200, [:], Data(body.utf8))
        }

        let result = try await makeHomePageService().loadSearchEpisodes(keyword: " 测试 ")
        XCTAssertEqual(capturedPath, "/api/v2/search/episodes")
        XCTAssertEqual(capturedKeyword, "测试")
        XCTAssertEqual(result.collection.count, 1)
        XCTAssertEqual(result.collection[0].collection[0].animeTitle, "测试番剧")
    }
}
