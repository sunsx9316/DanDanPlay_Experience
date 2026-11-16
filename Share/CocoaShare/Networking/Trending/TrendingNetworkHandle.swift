//
//  TrendingNetworkHandle.swift
//  AniXPlayer
//
//  macOS：排行榜接口（Bearer + 401 刷新）。
//

import Foundation

enum TrendingNetworkError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("排行榜数据加载失败", comment: "") : message
        }
    }
}

final class TrendingNetworkHandle {
    static let limit = 30

    static func fetch(
        mode: TrendingMetricMode,
        period: String = "week",
        scope: String = "current-season",
        filterAdultContent: Bool = true
    ) async throws -> TrendingResponse {
        let path: String
        switch mode {
        case .hot:
            path = "/trending/all/hot/\(period)"
        case .rising:
            path = "/trending/all/rising/\(period)"
        case .newAnime:
            path = "/trending/new-anime/hot/\(scope)"
        }

        let environment = APIEnvironment.current()
        guard let baseURL = environment.makeURL(path) else {
            throw APIError.invalidURL
        }

        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "filterAdultContent", value: filterAdultContent ? "true" : "false"),
            URLQueryItem(name: "limit", value: "\(limit)"),
        ]
        guard let url = components?.url else {
            throw APIError.invalidURL
        }

        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent,
            timeout: 20
        )

        let response: TrendingResponse = try await AuthenticatedAPIClient().send(request)
        if !response.success {
            throw TrendingNetworkError.server(response.errorMessage)
        }
        return response
    }
}
