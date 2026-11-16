//
//  UserDataTests.swift
//  AniXPlayerTests
//
//  收藏状态 / 评分 / 短评 / 追番队列的请求编码、解码与纯逻辑测试。
//

import Foundation
import XCTest

final class UserDataTests: XCTestCase {
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

    private func makeFavoriteService() -> FavoriteUserDataService {
        let authenticated = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "token-1" },
            refreshHandler: { "token-2" }
        )
        return FavoriteUserDataService(client: authenticated, environment: environment)
    }

    private func makeQueueHandle() -> BangumiQueueNetworkHandle {
        let authenticated = AuthenticatedAPIClient(
            client: client,
            tokenProvider: { "token-1" },
            refreshHandler: { "token-2" }
        )
        return BangumiQueueNetworkHandle(client: authenticated, environment: environment)
    }

    private func bodyData(from request: URLRequest) -> Data? {
        if let body = request.httpBody {
            return body
        }
        guard let stream = request.httpBodyStream else { return nil }
        stream.open()
        defer { stream.close() }

        var data = Data()
        let bufferSize = 4096
        var buffer = [UInt8](repeating: 0, count: bufferSize)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: bufferSize)
            if count <= 0 {
                break
            }
            data.append(contentsOf: buffer[0..<count])
        }
        return data
    }

    // MARK: - 请求编码 / 清空语义

    func testFavoriteRequestEncodingOmitsNilFields() throws {
        let full = UserAddFavoriteRequest(
            animeId: 42,
            favoriteStatus: .finished,
            rating: 8,
            comment: "  好看  "
        )
        let fullJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(full)) as? [String: Any]
        )
        XCTAssertEqual(fullJSON["animeId"] as? Int, 42)
        XCTAssertEqual(fullJSON["favoriteStatus"] as? String, "finished")
        XCTAssertEqual(fullJSON["rating"] as? Int, 8)
        XCTAssertEqual(fullJSON["comment"] as? String, "  好看  ")

        let partial = UserAddFavoriteRequest(animeId: 7, rating: 0, comment: nil)
        let partialJSON = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(partial)) as? [String: Any]
        )
        XCTAssertEqual(partialJSON["animeId"] as? Int, 7)
        XCTAssertEqual(partialJSON["rating"] as? Int, 0)
        XCTAssertNil(partialJSON["favoriteStatus"])
        XCTAssertNil(partialJSON["comment"])
    }

    func testCommentNormalizationPreservesClearSemantics() {
        XCTAssertNil(FavoriteUserDataService.normalizeComment(nil))
        XCTAssertEqual(FavoriteUserDataService.normalizeComment("  hello \n"), "hello")
        XCTAssertEqual(FavoriteUserDataService.normalizeComment(""), " ")
        XCTAssertEqual(FavoriteUserDataService.normalizeComment("   \n\t"), " ")
    }

    func testUpdateFavoriteEncodesTrimmedComment() async throws {
        var capturedMethod: String?
        var capturedPath: String?
        var capturedBody: [String: Any]?

        StubURLProtocol.handler = { [weak self] request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            if let data = self?.bodyData(from: request) {
                capturedBody = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
            }
            return (200, [:], Data(#"{"success":true}"#.utf8))
        }

        try await makeFavoriteService().updateFavorite(
            animeId: 9,
            favoriteStatus: .abandoned,
            rating: 7,
            comment: "  短评 \n"
        )

        XCTAssertEqual(capturedMethod, "POST")
        XCTAssertEqual(capturedPath, "/api/v2/favorite")
        XCTAssertEqual(capturedBody?["animeId"] as? Int, 9)
        XCTAssertEqual(capturedBody?["favoriteStatus"] as? String, "abandoned")
        XCTAssertEqual(capturedBody?["rating"] as? Int, 7)
        XCTAssertEqual(capturedBody?["comment"] as? String, "短评")
    }

    func testClearCommentSubmitsSingleSpace() async throws {
        var capturedComment: String?

        StubURLProtocol.handler = { [weak self] request in
            if let data = self?.bodyData(from: request),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                capturedComment = json["comment"] as? String
            }
            return (200, [:], Data(#"{"success":true}"#.utf8))
        }

        try await makeFavoriteService().updateFavorite(animeId: 10, comment: "   ")
        XCTAssertEqual(capturedComment, " ")
    }

    func testUpdateFavoriteServerErrorKeepsMessage() async {
        StubURLProtocol.handler = { _ in
            (200, [:], Data(#"{"success":false,"errorMessage":"没有权限"}"#.utf8))
        }

        do {
            try await makeFavoriteService().updateFavorite(animeId: 11, favoriteStatus: .favorited)
            XCTFail("success=false 时应抛出错误")
        } catch let error as FavoriteUserDataError {
            XCTAssertEqual(error, .server("没有权限"))
            XCTAssertEqual(error.localizedDescription, "没有权限")
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }

    func testCommentLongerThanLimitIsRejected() async {
        let longComment = String(repeating: "字", count: FavoriteUserDataService.maxCommentLength + 1)
        do {
            try await makeFavoriteService().updateFavorite(animeId: 12, comment: longComment)
            XCTFail("超长短评应被拒绝")
        } catch let error as FavoriteUserDataError {
            XCTAssertEqual(error, .commentTooLong)
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }

    // MARK: - 收藏列表 / 删除

    func testFetchFavoritesEncodesOnlyOnAirAndDecodesDates() async throws {
        var capturedPath: String?
        var capturedQuery: String?
        var capturedAuthorization: String?

        StubURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedQuery = request.url?.query
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            let json = """
            {
              "success": true,
              "errorCode": 0,
              "favorites": [
                {
                  "animeId": 123,
                  "animeTitle": "测试番剧",
                  "type": "tvseries",
                  "lastFavoriteTime": "2026-11-16T10:00:00.000",
                  "lastAirDate": "2026-11-15T22:30:00.000",
                  "lastWatchTime": "2026-11-14T20:00:00.000",
                  "imageUrl": "https://example.com/a.jpg",
                  "episodeTotal": 12,
                  "episodeWatched": 3,
                  "startDate": "2026-10-01T00:00:00.000",
                  "isOnAir": true,
                  "favoriteStatus": "favorited",
                  "userRating": 8,
                  "rating": 9.1
                }
              ]
            }
            """
            return (200, [:], Data(json.utf8))
        }

        let favorites = try await makeFavoriteService().fetchFavorites(onlyOnAir: true)

        XCTAssertEqual(capturedPath, "/api/v2/favorite")
        XCTAssertEqual(capturedQuery, "onlyOnAir=true")
        XCTAssertEqual(capturedAuthorization, "Bearer token-1")
        XCTAssertEqual(favorites.count, 1)
        XCTAssertEqual(favorites[0].animeId, 123)
        XCTAssertEqual(favorites[0].animeTitle, "测试番剧")
        XCTAssertEqual(favorites[0].favoriteStatus, .favorited)
        XCTAssertEqual(favorites[0].userRating, 8)
        XCTAssertNotNil(favorites[0].lastFavoriteTime)
        XCTAssertNotNil(favorites[0].lastAirDate)
        XCTAssertNotNil(favorites[0].lastWatchTime)
        XCTAssertNotNil(favorites[0].startDate)
    }

    func testRemoveFavoriteUsesDelete() async throws {
        var capturedMethod: String?
        var capturedPath: String?

        StubURLProtocol.handler = { request in
            capturedMethod = request.httpMethod
            capturedPath = request.url?.path
            return (200, [:], Data(#"{"success":true}"#.utf8))
        }

        try await makeFavoriteService().removeFavorite(animeId: 456)

        XCTAssertEqual(capturedMethod, "DELETE")
        XCTAssertEqual(capturedPath, "/api/v2/favorite/456")
    }

    func testFavoriteListServerErrorKeepsMessage() async {
        StubURLProtocol.handler = { _ in
            (200, [:], Data(#"{"success":false,"errorMessage":"请先登录"}"#.utf8))
        }

        do {
            _ = try await makeFavoriteService().fetchFavorites()
            XCTFail("success=false 时应抛出错误")
        } catch let error as FavoriteUserDataError {
            XCTAssertEqual(error, .server("请先登录"))
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }

    // MARK: - 追番队列

    func testQueueIntroDecodesDatesAndFields() async throws {
        var capturedPath: String?
        var capturedAuthorization: String?

        StubURLProtocol.handler = { request in
            capturedPath = request.url?.path
            capturedAuthorization = request.value(forHTTPHeaderField: "Authorization")
            let json = """
            {
              "success": true,
              "hasMore": true,
              "bangumiList": [
                {
                  "animeId": 321,
                  "animeTitle": "队列番剧",
                  "episodeTitle": "第 5 话",
                  "airDate": "2026-11-16",
                  "imageUrl": "https://example.com/q.jpg",
                  "description": "今天更新",
                  "isOnAir": true
                }
              ]
            }
            """
            return (200, [:], Data(json.utf8))
        }

        let response = try await makeQueueHandle().loadIntro()

        XCTAssertEqual(capturedPath, "/api/v2/bangumi/queue/intro")
        XCTAssertEqual(capturedAuthorization, "Bearer token-1")
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.bangumiList.count, 1)
        XCTAssertEqual(response.bangumiList[0].animeId, 321)
        XCTAssertEqual(response.bangumiList[0].episodeTitle, "第 5 话")
        XCTAssertEqual(response.bangumiList[0].description, "今天更新")
        XCTAssertNotNil(response.bangumiList[0].airDate)
    }

    func testQueueDetailsDecodesWatchedAndUnwatchedLists() async throws {
        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/api/v2/bangumi/queue/details")
            let json = """
            {
              "success": true,
              "bangumiList": [
                {
                  "animeId": 100,
                  "animeTitle": "追到一半",
                  "isOnAir": true,
                  "imageUrl": "https://example.com/100.jpg",
                  "searchKeyword": "追到一半",
                  "lastWatched": "2026-11-15T22:30:00+08:00",
                  "episodes": [
                    {
                      "episodeId": 1001,
                      "episodeTitle": "第 6 话",
                      "airDate": "2026-11-15"
                    },
                    {
                      "episodeId": 1002,
                      "episodeTitle": "第 7 话",
                      "airDate": "2026-11-16"
                    }
                  ]
                }
              ],
              "unwatchedBangumiList": [
                {
                  "animeId": 200,
                  "animeTitle": "只看过 PV",
                  "isOnAir": false,
                  "imageUrl": "https://example.com/200.jpg",
                  "searchKeyword": "只看过 PV",
                  "lastWatched": null,
                  "episodes": []
                }
              ]
            }
            """
            return (200, [:], Data(json.utf8))
        }

        let response = try await makeQueueHandle().loadDetails()

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.bangumiList.count, 1)
        XCTAssertEqual(response.unwatchedBangumiList.count, 1)
        XCTAssertEqual(response.bangumiList[0].animeId, 100)
        XCTAssertEqual(response.bangumiList[0].episodes.count, 2)
        XCTAssertNotNil(response.bangumiList[0].lastWatched)
        XCTAssertNotNil(response.bangumiList[0].episodes[0].airDate)
        XCTAssertEqual(response.bangumiList[0].latestEpisode?.episodeId, 1002)
        XCTAssertNil(response.unwatchedBangumiList[0].lastWatched)
        XCTAssertTrue(response.unwatchedBangumiList[0].episodes.isEmpty)
    }

    func testQueueDetailsServerErrorKeepsMessage() async {
        StubURLProtocol.handler = { _ in
            (200, [:], Data(#"{"success":false,"errorMessage":"登录已过期"}"#.utf8))
        }

        do {
            _ = try await makeQueueHandle().loadDetails()
            XCTFail("success=false 时应抛出错误")
        } catch let error as BangumiQueueError {
            XCTAssertEqual(error.localizedDescription, "登录已过期")
        } catch {
            XCTFail("错误类型不符: \(error)")
        }
    }

    func testQueueGroupingMergesAndSortsSections() {
        let now = Date(timeIntervalSince1970: 1_700_000_000)
        let watchedOld = BangumiQueueDetails(
            animeId: 1,
            animeTitle: "较早观看",
            lastWatched: now.addingTimeInterval(-3600),
            episodes: [BangumiQueueEpisode(episodeId: 11, episodeTitle: "第 2 话")]
        )
        let watchedNew = BangumiQueueDetails(
            animeId: 2,
            animeTitle: "最近观看",
            lastWatched: now,
            episodes: [BangumiQueueEpisode(episodeId: 21, episodeTitle: "第 9 话")]
        )
        let duplicate = BangumiQueueDetails(
            animeId: 1,
            animeTitle: "重复作品",
            lastWatched: nil
        )
        let followedOnAir = BangumiQueueDetails(
            animeId: 3,
            animeTitle: "连载中未看",
            isOnAir: true
        )
        let followedFinished = BangumiQueueDetails(
            animeId: 4,
            animeTitle: "已完结未看",
            isOnAir: false
        )

        let sections = BangumiQueueGrouping.sections(
            watched: [watchedOld, watchedNew],
            unwatched: [followedFinished, duplicate, followedOnAir]
        )

        XCTAssertEqual(sections.count, 2)
        XCTAssertEqual(sections[0].kind, .unwatched)
        XCTAssertEqual(sections[0].items.map(\.animeId), [2, 1])
        XCTAssertEqual(sections[1].kind, .followed)
        XCTAssertEqual(sections[1].items.map(\.animeId), [3, 4])

        let merged = BangumiQueueGrouping.mergedItems(
            watched: [watchedOld, watchedNew],
            unwatched: [followedFinished, duplicate, followedOnAir]
        )
        XCTAssertEqual(merged.map(\.animeId), [2, 1, 3, 4])
        XCTAssertEqual(Set(merged.map(\.animeId)).count, merged.count)
    }

    func testEmptyQueueProducesNoSections() {
        XCTAssertTrue(BangumiQueueGrouping.sections(watched: [], unwatched: []).isEmpty)
        XCTAssertTrue(BangumiQueueGrouping.mergedItems(watched: [], unwatched: []).isEmpty)
    }
}
