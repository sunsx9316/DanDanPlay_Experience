//
//  PlayHistoryNetworkHandle.swift
//  AniXPlayer
//
//  macOS：播放历史接口（Bearer + 401 刷新）。
//

import Foundation

enum PlayHistoryError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("播放历史操作失败", comment: "") : message
        }
    }
}

final class PlayHistoryNetworkHandle {
    static func fetch() async throws -> PlayHistoryResponse {
        let environment = APIEnvironment.current()
        guard let url = environment.makeURL("/playhistory") else {
            throw APIError.invalidURL
        }
        let request = APIClient.jsonRequest(url: url, method: .get, userAgent: environment.userAgent)
        let response: PlayHistoryResponse = try await AuthenticatedAPIClient().send(request)
        if !response.success {
            throw PlayHistoryError.server(response.errorMessage)
        }
        return response
    }

    static func report(episodeId: Int, addToFavorite: Bool = false, rating: Int = 0) async throws {
        let environment = APIEnvironment.current()
        guard let url = environment.makeURL("/playhistory") else {
            throw APIError.invalidURL
        }
        let body = try JSONEncoder().encode(
            AddPlayHistoryRequest(episodeId: episodeId, addToFavorite: addToFavorite, rating: rating)
        )
        let request = APIClient.jsonRequest(
            url: url,
            method: .post,
            body: body,
            userAgent: environment.userAgent
        )
        let data = try await AuthenticatedAPIClient().send(request)
        let response = try JSONDecoder().decode(PlayHistoryReportResponse.self, from: data)
        if !response.success {
            throw PlayHistoryError.server(response.errorMessage)
        }
    }
}

private struct PlayHistoryReportResponse: Decodable {
    let success: Bool
    let errorMessage: String

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage
    }
}
