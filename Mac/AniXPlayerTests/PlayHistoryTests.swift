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
