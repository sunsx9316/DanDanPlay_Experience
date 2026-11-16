//
//  SearchUpgradeTests.swift
//  AniXPlayerTests
//
//  搜索升级：JSON 解码、URL/query 构造、标签归一化、排序映射与边界。
//

import XCTest

final class SearchUpgradeTests: XCTestCase {

    private let environment = APIEnvironment(host: "https://api.example.com/", clientId: "test-client")

    // MARK: - JSON 解码

    func testDecodesAnimeSearchResponse() throws {
        let json = """
        {
          "success": true,
          "errorCode": 0,
          "animes": [
            {
              "animeId": 101,
              "bangumiId": "bg-101",
              "animeTitle": "测试动画",
              "type": "tvseries",
              "typeDescription": "TV 动画",
              "imageUrl": "https://example.com/poster.jpg",
              "startDate": "2024-04-01T00:00:00+08:00",
              "episodeCount": 12,
              "rating": 8.6,
              "isFavorited": true
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SearchUpgradeAnimeResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.animes.count, 1)
        XCTAssertEqual(response.animes[0].animeId, 101)
        XCTAssertEqual(response.animes[0].bangumiId, "bg-101")
        XCTAssertEqual(response.animes[0].animeTitle, "测试动画")
        XCTAssertEqual(response.animes[0].type, "tvseries")
        XCTAssertEqual(response.animes[0].typeDescription, "TV 动画")
        XCTAssertEqual(response.animes[0].episodeCount, 12)
        XCTAssertEqual(response.animes[0].rating, 8.6, accuracy: 0.0001)
        XCTAssertTrue(response.animes[0].isFavorited)
        XCTAssertNotNil(response.animes[0].startDate)
    }

    func testDecodesEpisodesSearchResponseWithHasMore() throws {
        let json = """
        {
          "success": true,
          "hasMore": true,
          "animes": [
            {
              "animeId": 202,
              "animeTitle": "剧集动画",
              "type": "tvseries",
              "typeDescription": "TV",
              "episodes": [
                { "episodeId": 9001, "episodeTitle": "第1话" },
                { "episodeId": 9002, "episodeTitle": "第2话" }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SearchUpgradeEpisodesResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.animes.count, 1)
        XCTAssertEqual(response.animes[0].animeId, 202)
        XCTAssertEqual(response.animes[0].episodes.count, 2)
        XCTAssertEqual(response.animes[0].episodes[1].episodeId, 9002)
        XCTAssertEqual(response.animes[0].episodes[1].episodeTitle, "第2话")
    }

    func testDecodesEpisodesSearchResponseDefaultsHasMoreToFalse() throws {
        let json = """
        {"success": true, "animes": [{"animeId": 1, "animeTitle": "A", "episodes": []}]}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SearchUpgradeEpisodesResponse.self, from: json)
        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.animes[0].episodes.count, 0)
    }

    func testDecodesTagSearchResponse() throws {
        let json = """
        {
          "success": true,
          "bangumis": [
            {
              "animeId": 303,
              "bangumiId": "bg-303",
              "animeTitle": "标签动画",
              "type": "movie",
              "typeDescription": "剧场版",
              "imageUrl": "https://example.com/b.jpg",
              "episodeCount": 1,
              "rating": 9.1,
              "rank": 1,
              "searchKeyword": "科幻,机战",
              "isOnAir": false,
              "isRestricted": true,
              "intro": "简介"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SearchUpgradeBangumiResponse.self, from: json)
        XCTAssertEqual(response.bangumis.count, 1)
        XCTAssertEqual(response.bangumis[0].animeId, 303)
        XCTAssertEqual(response.bangumis[0].rank, 1)
        XCTAssertEqual(response.bangumis[0].searchKeyword, "科幻,机战")
        XCTAssertTrue(response.bangumis[0].isRestricted)
        XCTAssertEqual(response.bangumis[0].intro, "简介")
    }

    func testDecodesAdvancedConfigResponse() throws {
        let json = """
        {
          "success": true,
          "types": [{ "key": 1, "value": "TV" }, { "key": 2, "value": "剧场版" }],
          "tags": [{ "key": 10, "value": "科幻" }],
          "sorts": [{ "key": 6, "value": "评分（由高到低）" }],
          "minYear": 1990,
          "maxYear": 2026
        }
        """.data(using: .utf8)!

        let config = try JSONDecoder().decode(SearchUpgradeAdvancedConfigResponse.self, from: json)
        XCTAssertTrue(config.success)
        XCTAssertEqual(config.types.map(\.key), [1, 2])
        XCTAssertEqual(config.types.map(\.value), ["TV", "剧场版"])
        XCTAssertEqual(config.tags.first?.value, "科幻")
        XCTAssertEqual(config.sorts.first?.key, SearchUpgradeSort.rateDesc.rawValue)
        XCTAssertEqual(config.minYear, 1990)
        XCTAssertEqual(config.maxYear, 2026)
    }

    func testDecodesServerError() throws {
        let json = """
        {"success": false, "errorMessage": "关键词过长"}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(SearchUpgradeAnimeResponse.self, from: json)
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.errorMessage, "关键词过长")
        XCTAssertTrue(response.animes.isEmpty)
    }

    // MARK: - URL / query 构造

    func testAnimeURLTrimsKeywordAndBuildsQuery() throws {
        let url = try SearchUpgradeRequest.animeURL(keyword: "  进击的巨人  ", environment: environment)
        XCTAssertEqual(url.path, "/api/v2/search/anime")
        XCTAssertEqual(queryValue("keyword", in: url), "进击的巨人")
    }

    func testEpisodesURLOmitsEmptyEpisode() throws {
        let url = try SearchUpgradeRequest.episodesURL(anime: " 测试 ", episode: "   ", environment: environment)
        XCTAssertEqual(url.path, "/api/v2/search/episodes")
        XCTAssertEqual(queryValue("anime", in: url), "测试")
        XCTAssertNil(queryValue("episode", in: url))
    }

    func testEpisodesURLIncludesEpisode() throws {
        let url = try SearchUpgradeRequest.episodesURL(anime: "测试", episode: "第 1 话", environment: environment)
        XCTAssertEqual(queryValue("episode", in: url), "第 1 话")
    }

    func testTagsURLJoinsNormalizedTags() throws {
        let url = try SearchUpgradeRequest.tagsURL(rawTags: "科幻, 机战，科幻,  ", environment: environment)
        XCTAssertEqual(url.path, "/api/v2/search/tag")
        XCTAssertEqual(queryValue("tags", in: url), "科幻,机战")
    }

    func testTagsURLRejectsMoreThanTenTags() {
        let tags = (1...11).map { "tag\($0)" }
        XCTAssertThrowsError(try SearchUpgradeRequest.tagsURL(tags: tags, environment: environment)) { error in
            XCTAssertEqual(error as? SearchUpgradeError, .tooManyTags(max: 10))
        }
    }

    func testTagsURLRejectsEmptyTags() {
        XCTAssertThrowsError(try SearchUpgradeRequest.tagsURL(tags: ["  "], environment: environment)) { error in
            XCTAssertEqual(error as? SearchUpgradeError, .emptyTags)
        }
    }

    func testAdvancedConfigURLAlwaysIncludesDefaultSource() throws {
        let url = try SearchUpgradeRequest.advancedConfigURL(environment: environment)
        XCTAssertEqual(url.path, "/api/v2/search/adv/config")
        XCTAssertEqual(queryValue("source", in: url), "")
    }

    func testAdvancedSearchURLMapsAllSupportedParameters() throws {
        let query = try SearchUpgradeAdvancedQuery(
            source: "tmdb",
            keyword: " 动画 ",
            type: 2,
            tags: ["科幻", "机战"],
            year: 2024,
            month: 4,
            minRate: 6,
            maxRate: 9,
            restricted: false,
            sort: .rateDesc
        )
        let url = try SearchUpgradeRequest.advancedSearchURL(query: query, environment: environment)

        XCTAssertEqual(url.path, "/api/v2/search/adv")
        XCTAssertEqual(queryValue("source", in: url), "tmdb")
        XCTAssertEqual(queryValue("keyword", in: url), "动画")
        XCTAssertEqual(queryValue("type", in: url), "2")
        XCTAssertEqual(queryValue("tags", in: url), "科幻,机战")
        XCTAssertEqual(queryValue("year", in: url), "2024")
        XCTAssertEqual(queryValue("month", in: url), "4")
        XCTAssertEqual(queryValue("minRate", in: url), "6")
        XCTAssertEqual(queryValue("maxRate", in: url), "9")
        XCTAssertEqual(queryValue("restricted", in: url), "false")
        XCTAssertEqual(queryValue("sort", in: url), "6")
    }

    func testAdvancedSearchQueryOmitsEmptyOptionalValues() throws {
        let query = try SearchUpgradeAdvancedQuery(keyword: "   ")
        let url = try SearchUpgradeRequest.advancedSearchURL(query: query, environment: environment)

        XCTAssertNil(queryValue("keyword", in: url))
        XCTAssertNil(queryValue("type", in: url))
        XCTAssertNil(queryValue("tags", in: url))
        XCTAssertNil(queryValue("sort", in: url))
        XCTAssertEqual(queryValue("source", in: url), "")
    }

    func testEmptyKeywordThrows() {
        XCTAssertThrowsError(try SearchUpgradeRequest.animeURL(keyword: "   ", environment: environment)) { error in
            XCTAssertEqual(error as? SearchUpgradeError, .emptyKeyword)
        }
        XCTAssertThrowsError(try SearchUpgradeRequest.episodesURL(anime: "", environment: environment)) { error in
            XCTAssertEqual(error as? SearchUpgradeError, .emptyKeyword)
        }
    }

    // MARK: - 映射 / 默认值

    func testSortMappingMatchesWindowsSearchSort() {
        XCTAssertEqual(SearchUpgradeSort.allCases.count, 7)
        XCTAssertEqual(SearchUpgradeSort.defaultSort.rawValue, 0)
        XCTAssertEqual(SearchUpgradeSort.nameAsc.rawValue, 1)
        XCTAssertEqual(SearchUpgradeSort.nameDesc.rawValue, 2)
        XCTAssertEqual(SearchUpgradeSort.startDateAsc.rawValue, 3)
        XCTAssertEqual(SearchUpgradeSort.startDateDesc.rawValue, 4)
        XCTAssertEqual(SearchUpgradeSort.rateAsc.rawValue, 5)
        XCTAssertEqual(SearchUpgradeSort.rateDesc.rawValue, 6)
        XCTAssertEqual(SearchUpgradeSort(rawValue: 6), .rateDesc)
        XCTAssertNil(SearchUpgradeSort(rawValue: 99))
    }

    func testFallbackConfigIsUsable() {
        let fallback = SearchUpgradeAdvancedConfigResponse.fallback(
            referenceDate: Date(timeIntervalSince1970: 1_700_000_000)
        )
        XCTAssertEqual(fallback.sorts.count, 7)
        XCTAssertLessThanOrEqual(fallback.minYear, fallback.maxYear)
        XCTAssertGreaterThan(fallback.maxYear, 2000)
    }
}

private func queryValue(_ name: String, in url: URL) -> String? {
    URLComponents(url: url, resolvingAgainstBaseURL: false)?
        .queryItems?
        .first(where: { $0.name == name })?
        .value
}
