import XCTest

final class PlayHistoryTests: XCTestCase {
    func testDecodesPlayHistoryResponse() throws {
        let json = """
        {
          "success": true,
          "errorCode": 0,
          "playHistoryAnimes": [
            {
              "animeId": 123,
              "animeTitle": "测试番剧",
              "type": "tvseries",
              "typeDescription": "TV",
              "imageUrl": "https://example.com/a.jpg",
              "isOnAir": true,
              "episodes": [
                {
                  "episodeId": 456,
                  "episodeTitle": "第1话",
                  "episodeNumber": "1",
                  "lastWatched": "2026-11-16T09:30:00+08:00"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlayHistoryResponse.self, from: json)
        XCTAssertTrue(response.success)
        XCTAssertEqual(response.animes.count, 1)
        XCTAssertEqual(response.animes[0].animeId, 123)
        XCTAssertEqual(response.animes[0].animeTitle, "测试番剧")
        XCTAssertEqual(response.animes[0].episodes.count, 1)
        XCTAssertEqual(response.animes[0].episodes[0].episodeId, 456)
        XCTAssertNotNil(response.animes[0].episodes[0].lastWatched)
    }

    func testDecodesMissingOptionalFields() throws {
        let json = """
        {"success": true, "playHistoryAnimes": [{"animeId": 1, "animeTitle": "A"}]}
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlayHistoryResponse.self, from: json)
        XCTAssertEqual(response.animes[0].animeId, 1)
        XCTAssertTrue(response.animes[0].episodes.isEmpty)
        XCTAssertFalse(response.animes[0].isOnAir)
    }

    func testDecodesAirDateAndEpisodeStatus() throws {
        let json = """
        {
          "success": true,
          "playHistoryAnimes": [
            {
              "animeId": 1,
              "animeTitle": "测试番剧",
              "episodes": [
                {
                  "episodeId": 10001,
                  "episodeTitle": "第 1 话 起航",
                  "episodeNumber": "1",
                  "airDate": "2026-11-20T12:00:00+08:00"
                },
                {
                  "episodeId": 10002,
                  "episodeTitle": "第 2 话 远方",
                  "episodeNumber": "2",
                  "lastWatched": "2026-11-16T09:30:00+08:00",
                  "airDate": "2026-11-27T12:00:00+08:00"
                }
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlayHistoryResponse.self, from: json)
        let episodes = response.animes[0].episodes
        XCTAssertEqual(episodes.count, 2)
        XCTAssertEqual(episodes[0].episodeNumber, "1")
        XCTAssertNil(episodes[0].lastWatched)
        XCTAssertEqual(
            episodes[0].airDate,
            ISO8601DateFormatter().date(from: "2026-11-20T04:00:00Z")
        )
        XCTAssertEqual(
            episodes[0].status(now: ISO8601DateFormatter().date(from: "2026-11-19T00:00:00Z")!),
            .notOnAir
        )
        XCTAssertEqual(
            episodes[1].status(now: ISO8601DateFormatter().date(from: "2026-11-19T00:00:00Z")!),
            .watched
        )
    }

    func testDecodesMissingOrInvalidAirDateWithoutError() throws {
        let json = """
        {
          "success": true,
          "playHistoryAnimes": [
            {
              "animeId": 2,
              "animeTitle": "旧响应",
              "episodes": [
                {"episodeId": 20001, "episodeTitle": "第 1 话", "episodeNumber": "1"},
                {"episodeId": 20002, "episodeTitle": "第 2 话", "episodeNumber": "2", "airDate": "不是日期"}
              ]
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(PlayHistoryResponse.self, from: json)
        let episodes = response.animes[0].episodes
        XCTAssertNil(episodes[0].airDate)
        XCTAssertNil(episodes[1].airDate)
        XCTAssertEqual(episodes[0].status(now: Date()), .notWatched)
        XCTAssertEqual(episodes[1].status(now: Date()), .notWatched)
    }

    func testEpisodeStatusResolution() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let past = now.addingTimeInterval(-3600)
        let future = now.addingTimeInterval(3600)

        XCTAssertEqual(
            PlayHistoryEpisodeStatus.resolve(lastWatched: past, airDate: future, now: now),
            .watched
        )
        XCTAssertEqual(
            PlayHistoryEpisodeStatus.resolve(lastWatched: now, airDate: nil, now: now),
            .watched
        )
        XCTAssertEqual(
            PlayHistoryEpisodeStatus.resolve(lastWatched: nil, airDate: future, now: now),
            .notOnAir
        )
        XCTAssertEqual(
            PlayHistoryEpisodeStatus.resolve(lastWatched: nil, airDate: past, now: now),
            .notWatched
        )
        XCTAssertEqual(
            PlayHistoryEpisodeStatus.resolve(lastWatched: nil, airDate: nil, now: now),
            .notWatched
        )
        XCTAssertEqual(
            PlayHistoryEpisodeStatus.resolve(lastWatched: nil, airDate: now, now: now),
            .notWatched
        )
    }

    func testChipTitleUsesEpisodeNumberFirst() {
        XCTAssertEqual(
            PlayHistoryEpisode.chipTitle(
                episodeNumber: "12",
                episodeId: 19001,
                episodeTitle: "SP1 特别篇"
            ),
            "12"
        )
        XCTAssertEqual(
            PlayHistoryEpisode.chipTitle(
                episodeNumber: "  ",
                episodeId: 12345,
                episodeTitle: "第 5 话"
            ),
            "2345"
        )
    }

    func testChipTitleDerivesFromEpisodeIdAndTitle() {
        XCTAssertEqual(
            PlayHistoryEpisode.chipTitle(
                episodeNumber: "",
                episodeId: 19001,
                episodeTitle: "SP1 特别篇"
            ),
            "SP1"
        )
        XCTAssertEqual(
            PlayHistoryEpisode.chipTitle(
                episodeNumber: "",
                episodeId: 19002,
                episodeTitle: "特别篇"
            ),
            "特别篇"
        )
        XCTAssertEqual(
            PlayHistoryEpisode.chipTitle(
                episodeNumber: "",
                episodeId: 19003,
                episodeTitle: "   "
            ),
            "#19003"
        )
    }

    func testRowLayoutKeepsPosterHeightAndMinimumRowHeight() {
        XCTAssertEqual(PlayHistoryRowLayout.posterWidth, 100)
        XCTAssertEqual(PlayHistoryRowLayout.posterHeight, 150)
        XCTAssertEqual(PlayHistoryRowLayout.rowHeight(chipContentHeight: 0), 174)
        XCTAssertEqual(PlayHistoryRowLayout.rowHeight(chipContentHeight: 60), 174)
        XCTAssertGreaterThan(PlayHistoryRowLayout.rowHeight(chipContentHeight: 200), 174)
        XCTAssertEqual(PlayHistoryRowLayout.contentWidth(for: 900), 754)
    }

    func testChipFlowWrapsWithoutExceedingAvailableWidth() {
        XCTAssertEqual(
            PlayHistoryRowLayout.flowHeight(chipWidths: [80, 80], availableWidth: 200),
            24
        )
        XCTAssertEqual(
            PlayHistoryRowLayout.flowHeight(chipWidths: [100, 100], availableWidth: 200),
            54
        )
        XCTAssertEqual(
            PlayHistoryRowLayout.flowHeight(chipWidths: [500], availableWidth: 200),
            24
        )
        XCTAssertEqual(
            PlayHistoryRowLayout.flowHeight(chipWidths: [], availableWidth: 200),
            0
        )
    }

    func testAddPlayHistoryRequestEncoding() throws {
        let data = try JSONEncoder().encode(AddPlayHistoryRequest(episodeId: 789))
        let object = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        XCTAssertEqual(object?["episodeIdList"] as? [Int], [789])
        XCTAssertEqual(object?["addToFavorite"] as? Bool, false)
        XCTAssertEqual(object?["rating"] as? Int, 0)
    }

    func testServerErrorIsExposed() throws {
        let json = """
        {"success": false, "errorMessage": "没有权限"}
        """.data(using: .utf8)!
        let response = try JSONDecoder().decode(PlayHistoryResponse.self, from: json)
        XCTAssertFalse(response.success)
        XCTAssertEqual(response.errorMessage, "没有权限")
    }
}
