//
//  ResourceSearchService.swift
//  AniXPlayer
//
//  macOS：res.dandanplay.net 资源搜索接口。
//

import Foundation

enum ResourceSearchServiceError: LocalizedError {
    case invalidURL

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("资源搜索地址无效", comment: "")
        }
    }
}

final class ResourceSearchService {

    static let shared = ResourceSearchService()

    private let client: APIClient
    private let baseURL: URL

    init(client: APIClient = APIClient(), baseURL: URL? = nil) {
        self.client = client
        self.baseURL = baseURL ?? Self.defaultBaseURL
    }

    static var defaultBaseURL: URL {
        if let override = ProcessInfo.processInfo.environment["ANIX_RESOURCE_SEARCH_ENDPOINT"],
           let url = URL(string: override.trimmingCharacters(in: .whitespacesAndNewlines)),
           !override.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return url
        }
        return URL(string: "https://res.dandanplay.net")!
    }

    /// 与 Windows 版一致：`/list?keyword=...&type=...&subgroup=...&r=随机数`。
    func search(keyword: String, typeId: Int?, subgroupId: Int?) async throws -> ResourceSearchResponse {
        var queryItems = [URLQueryItem(name: "keyword", value: keyword)]
        if let typeId = typeId {
            queryItems.append(URLQueryItem(name: "type", value: String(typeId)))
        }
        if let subgroupId = subgroupId {
            queryItems.append(URLQueryItem(name: "subgroup", value: String(subgroupId)))
        }
        queryItems.append(URLQueryItem(name: "r", value: String(Int.random(in: 1...Int.max))))

        let url = try makeURL(path: "list", queryItems: queryItems)
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: APIEnvironment.current().userAgent
        )
        return try await client.send(request)
    }

    func fetchTypeOptions() async throws -> [ResourceSearchOption] {
        let url = try makeURL(path: "type", queryItems: [])
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: APIEnvironment.current().userAgent
        )
        let response: ResourceTypeListResponse = try await client.send(request)
        return response.types
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    func fetchSubgroupOptions() async throws -> [ResourceSearchOption] {
        let url = try makeURL(path: "subgroup", queryItems: [])
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: APIEnvironment.current().userAgent
        )
        let response: ResourceSubgroupListResponse = try await client.send(request)
        return response.subgroups
            .filter { !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }

    private func makeURL(path: String, queryItems: [URLQueryItem]) throws -> URL {
        let url = baseURL.appendingPathComponent(path)
        guard var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw ResourceSearchServiceError.invalidURL
        }
        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }
        guard let finalURL = components.url else {
            throw ResourceSearchServiceError.invalidURL
        }
        return finalURL
    }
}
