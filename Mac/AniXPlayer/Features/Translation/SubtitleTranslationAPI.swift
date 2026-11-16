//
//  SubtitleTranslationAPI.swift
//  AniXPlayer
//
//  macOS only：AI 字幕翻译接口。使用现有 Bearer + 401 刷新链路。
//

import Foundation

protocol SubtitleTranslationAPIProviding {
    func translate(_ request: SubtitleTranslateRequest) async throws -> SubtitleTranslateResponse
    func fetchServices() async throws -> SubtitleServiceListResponse
    func fetchUsage() async throws -> SubtitleServiceUsageResponse
}

final class SubtitleTranslationAPIClient: SubtitleTranslationAPIProviding {
    private let client: AuthenticatedAPIClient
    private let environment: APIEnvironment
    private let encoder = JSONEncoder()

    init(
        client: AuthenticatedAPIClient? = nil,
        environment: APIEnvironment = APIEnvironment.current()
    ) {
        // AI 翻译单次 1 万字符可能超过默认 30 秒资源超时，这里给翻译请求更长的窗口。
        self.client = client ?? Self.makeDefaultClient()
        self.environment = environment
    }

    private static func makeDefaultClient() -> AuthenticatedAPIClient {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 120
        configuration.timeoutIntervalForResource = 300
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        let session = URLSession(configuration: configuration)
        return AuthenticatedAPIClient(client: APIClient(session: session))
    }

    func translate(_ request: SubtitleTranslateRequest) async throws -> SubtitleTranslateResponse {
        guard let url = environment.makeURL("/ai/translate") else {
            throw APIError.invalidURL
        }
        let body = try encoder.encode(request)
        let urlRequest = APIClient.jsonRequest(
            url: url,
            method: .post,
            body: body,
            userAgent: environment.userAgent,
            timeout: 90
        )
        return try await client.send(urlRequest)
    }

    func fetchServices() async throws -> SubtitleServiceListResponse {
        guard let url = environment.makeURL("/ai/translate/service") else {
            throw APIError.invalidURL
        }
        let request = APIClient.jsonRequest(
            url: url,
            userAgent: environment.userAgent,
            timeout: 20
        )
        return try await client.send(request)
    }

    func fetchUsage() async throws -> SubtitleServiceUsageResponse {
        guard let url = environment.makeURL("/ai/translate/usage") else {
            throw APIError.invalidURL
        }
        let request = APIClient.jsonRequest(
            url: url,
            userAgent: environment.userAgent,
            timeout: 20
        )
        return try await client.send(request)
    }
}
