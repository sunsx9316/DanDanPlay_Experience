//
//  BangumiQueueNetworkHandle.swift
//  AniXPlayer
//
//  macOS：追番队列接口（Bearer + 401 刷新）。
//

import Foundation

enum BangumiQueueError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("追番队列加载失败", comment: "") : message
        }
    }
}

final class BangumiQueueNetworkHandle {
    private let client: AuthenticatedAPIClient
    private let environment: APIEnvironment

    init(
        client: AuthenticatedAPIClient = AuthenticatedAPIClient(),
        environment: APIEnvironment = .current()
    ) {
        self.client = client
        self.environment = environment
    }

    /// GET /bangumi/queue/intro
    static func fetchIntro() async throws -> BangumiQueueIntroResponse {
        try await BangumiQueueNetworkHandle().loadIntro()
    }

    /// GET /bangumi/queue/details
    static func fetchDetails() async throws -> BangumiQueueDetailsResponse {
        try await BangumiQueueNetworkHandle().loadDetails()
    }

    func loadIntro() async throws -> BangumiQueueIntroResponse {
        guard let url = environment.makeURL("/bangumi/queue/intro") else {
            throw APIError.invalidURL
        }
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        let data = try await client.send(request)
        let response = try Self.decode(BangumiQueueIntroResponse.self, from: data)
        guard response.success else {
            throw BangumiQueueError.server(response.errorMessage)
        }
        return response
    }

    func loadDetails() async throws -> BangumiQueueDetailsResponse {
        guard let url = environment.makeURL("/bangumi/queue/details") else {
            throw APIError.invalidURL
        }
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        let data = try await client.send(request)
        let response = try Self.decode(BangumiQueueDetailsResponse.self, from: data)
        guard response.success else {
            throw BangumiQueueError.server(response.errorMessage)
        }
        return response
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
