//
//  HomePageService.swift
//  AniXPlayer
//
//  macOS：首页 / 新番 / 在线搜索的 async 接口（Bearer + 401 刷新）。
//  旧 HomePageNetworkHandle 继续保留给旧界面使用。
//

import Foundation

enum HomePageServiceError: LocalizedError {
    case server(String)
    case emptyKeyword

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("首页数据加载失败", comment: "") : message
        case .emptyKeyword:
            return NSLocalizedString("请输入搜索关键词", comment: "")
        }
    }
}

/// `/bangumi/shin` 与 `/bangumi/season/anime/{year}/{month}` 的响应。
struct HomePageBangumiListResponse: Decodable {
    let success: Bool
    let errorMessage: String
    let bangumiList: [BangumiIntro]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        bangumiList = (try? container.decodeIfPresent([BangumiIntro].self, forKey: .bangumiList)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, bangumiList
    }
}

/// `/homePage` 顶层成功标志；旧服务端不返回该字段时按成功处理。
private struct HomePageEnvelope: Decodable {
    let success: Bool
    let errorMessage: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage
    }
}

final class HomePageService {
    private let client: AuthenticatedAPIClient
    private let environment: APIEnvironment

    init(
        client: AuthenticatedAPIClient = AuthenticatedAPIClient(),
        environment: APIEnvironment = .current()
    ) {
        self.client = client
        self.environment = environment
    }

    // MARK: - Homepage

    static func fetchHomepage(filterAdultContent: Bool = true) async throws -> Homepage {
        try await HomePageService().loadHomepage(filterAdultContent: filterAdultContent)
    }

    func loadHomepage(filterAdultContent: Bool = true) async throws -> Homepage {
        let data = try await get(
            path: "/homePage",
            queryItems: [
                URLQueryItem(name: "filterAdultContent", value: filterAdultContent ? "true" : "false")
            ]
        )

        if let envelope = try? JSONDecoder().decode(HomePageEnvelope.self, from: data),
           !envelope.success {
            throw HomePageServiceError.server(envelope.errorMessage)
        }

        do {
            return try JSONDecoder().decode(Homepage.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    // MARK: - Shin bangumi

    static func fetchShinBangumi(filterAdultContent: Bool = true) async throws -> [BangumiIntro] {
        try await HomePageService().loadShinBangumi(filterAdultContent: filterAdultContent)
    }

    func loadShinBangumi(filterAdultContent: Bool = true) async throws -> [BangumiIntro] {
        let data = try await get(
            path: "/bangumi/shin",
            queryItems: [
                URLQueryItem(name: "filterAdultContent", value: filterAdultContent ? "true" : "false")
            ]
        )
        return try decodeBangumiList(data)
    }

    // MARK: - Season bangumi

    static func fetchSeasonBangumi(
        year: Int,
        month: Int,
        filterAdultContent: Bool = true
    ) async throws -> [BangumiIntro] {
        try await HomePageService().loadSeasonBangumi(
            year: year,
            month: month,
            filterAdultContent: filterAdultContent
        )
    }

    func loadSeasonBangumi(
        year: Int,
        month: Int,
        filterAdultContent: Bool = true
    ) async throws -> [BangumiIntro] {
        let data = try await get(
            path: "/bangumi/season/anime/\(year)/\(month)",
            queryItems: [
                URLQueryItem(name: "filterAdultContent", value: filterAdultContent ? "true" : "false")
            ]
        )
        return try decodeBangumiList(data)
    }

    // MARK: - Search

    static func searchEpisodes(keyword: String) async throws -> SearchResult {
        try await HomePageService().loadSearchEpisodes(keyword: keyword)
    }

    func loadSearchEpisodes(keyword: String) async throws -> SearchResult {
        let trimmed = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw HomePageServiceError.emptyKeyword
        }

        let data = try await get(
            path: "/search/episodes",
            queryItems: [URLQueryItem(name: "anime", value: trimmed)]
        )

        let result: SearchResult
        do {
            result = try JSONDecoder().decode(SearchResult.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }

        // 旧 SearchNetworkHandle 在回调里补标题，新接口保持一致。
        for collection in result.collection {
            collection.collection.forEach { $0.animeTitle = collection.animeTitle }
        }
        return result
    }

    // MARK: - Private

    private func decodeBangumiList(_ data: Data) throws -> [BangumiIntro] {
        let response: HomePageBangumiListResponse
        do {
            response = try JSONDecoder().decode(HomePageBangumiListResponse.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
        guard response.success else {
            throw HomePageServiceError.server(response.errorMessage)
        }
        return response.bangumiList
    }

    private func get(path: String, queryItems: [URLQueryItem]) async throws -> Data {
        guard let baseURL = environment.makeURL(path),
              var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false) else {
            throw APIError.invalidURL
        }
        components.queryItems = queryItems
        guard let url = components.url else {
            throw APIError.invalidURL
        }

        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        return try await client.send(request)
    }
}
