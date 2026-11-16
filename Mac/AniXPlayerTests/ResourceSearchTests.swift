import XCTest

final class ResourceSearchTests: XCTestCase {

    override func tearDown() {
        StubURLProtocol.handler = nil
        super.tearDown()
    }

    // MARK: - Decoding

    func testDecodesResourceListAndDefaults() throws {
        let json = """
        {
          "hasMore": true,
          "resources": [
            {
              "title": "葬送的芙莉莲 01",
              "typeId": 31,
              "typeName": "动画/季度全集",
              "subgroupId": 669,
              "subgroupName": "喵萌奶茶屋",
              "magnet": "magnet:?xt=urn:btih:ABC",
              "torrentUrl": "https://example.com/a.torrent",
              "pageUrl": "https://example.com/a",
              "fileSize": "7.6GB",
              "publishDate": "2026-10-17 23:42:00"
            },
            {
              "title": "只有标题"
            }
          ]
        }
        """.data(using: .utf8)!

        let response = try JSONDecoder().decode(ResourceSearchResponse.self, from: json)
        XCTAssertTrue(response.hasMore)
        XCTAssertEqual(response.resources.count, 2)
        XCTAssertEqual(response.resources[0].typeId, 31)
        XCTAssertEqual(response.resources[0].subgroupId, 669)
        XCTAssertEqual(response.resources[0].downloadSource, "magnet:?xt=urn:btih:ABC")
        XCTAssertEqual(response.resources[1].title, "只有标题")
        XCTAssertEqual(response.resources[1].typeId, 0)
        XCTAssertNil(response.resources[1].downloadSource)
        XCTAssertTrue(response.resources[1].typeName.isEmpty)
        XCTAssertTrue(response.resources[1].subgroupName.isEmpty)
    }

    // MARK: - Filter

    func testFilterByTypeAndSubgroup() {
        let items = [
            makeItem(title: "A", typeId: 31, subgroupId: 669),
            makeItem(title: "B", typeId: 2, subgroupId: 669),
            makeItem(title: "C", typeId: 31, subgroupId: 17),
        ]

        XCTAssertEqual(ResourceSearchFilter().apply(to: items).count, 3)
        XCTAssertEqual(
            ResourceSearchFilter(typeId: 31).apply(to: items).map(\.title),
            ["A", "C"]
        )
        XCTAssertEqual(
            ResourceSearchFilter(subgroupId: 669).apply(to: items).map(\.title),
            ["A", "B"]
        )
        XCTAssertEqual(
            ResourceSearchFilter(typeId: 31, subgroupId: 669).apply(to: items).map(\.title),
            ["A"]
        )
    }

    func testDownloadSourceFallsBackToTorrent() {
        let magnetItem = makeItem(
            title: "magnet",
            magnet: " magnet:?xt=urn:btih:ABC ",
            torrentUrl: "https://example.com/a.torrent"
        )
        let torrentItem = makeItem(
            title: "torrent",
            magnet: "",
            torrentUrl: " https://example.com/b.torrent "
        )
        let noSourceItem = makeItem(title: "none")

        XCTAssertEqual(magnetItem.downloadSource, "magnet:?xt=urn:btih:ABC")
        XCTAssertEqual(torrentItem.downloadSource, "https://example.com/b.torrent")
        XCTAssertNil(noSourceItem.downloadSource)
    }

    // MARK: - Service

    func testServiceBuildsQueryAndDecodesResponse() async throws {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubURLProtocol.self]
        let client = APIClient(session: URLSession(configuration: configuration))
        let service = ResourceSearchService(
            client: client,
            baseURL: URL(string: "https://res.example.com")!
        )

        StubURLProtocol.handler = { request in
            XCTAssertEqual(request.url?.path, "/list")
            let components = URLComponents(url: request.url!, resolvingAgainstBaseURL: false)!
            let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map {
                ($0.name, $0.value ?? "")
            })
            XCTAssertEqual(query["keyword"], "芙莉莲")
            XCTAssertEqual(query["type"], "31")
            XCTAssertEqual(query["subgroup"], "669")
            XCTAssertNotNil(query["r"])

            let body = """
            {
              "hasMore": false,
              "resources": [
                {
                  "title": "结果",
                  "magnet": "magnet:?xt=urn:btih:DEF",
                  "fileSize": "1.2GB"
                }
              ]
            }
            """.data(using: .utf8)!
            return (200, ["Content-Type": "application/json"], body)
        }

        let response = try await service.search(keyword: "芙莉莲", typeId: 31, subgroupId: 669)
        XCTAssertFalse(response.hasMore)
        XCTAssertEqual(response.resources.count, 1)
        XCTAssertEqual(response.resources[0].title, "结果")
        XCTAssertEqual(response.resources[0].downloadSource, "magnet:?xt=urn:btih:DEF")
    }

    // MARK: - Helpers

    private func makeItem(
        title: String,
        typeId: Int = 0,
        subgroupId: Int = 0,
        magnet: String = "",
        torrentUrl: String? = nil
    ) -> ResourceSearchItem {
        ResourceSearchItem(
            title: title,
            typeId: typeId,
            subgroupId: subgroupId,
            magnet: magnet,
            torrentUrl: torrentUrl
        )
    }
}
