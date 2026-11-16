//
//  FavoriteUserDataService.swift
//  AniXPlayer
//
//  macOS：收藏状态 / 评分 / 短评（Bearer + 401 刷新）。
//  旧 FavoriteNetworkHandle 的回调接口保持不变，新界面使用这里的 async API。
//

import Foundation

/// POST /favorite 的请求体。
///
/// - `rating` 传 0 表示不修改当前分数；
/// - `comment` 传 nil/空字符串表示不修改；传至少一个空格表示清空；
/// - 未被赋值的可选字段不会出现在 JSON 中，避免覆盖服务端已有值。
struct UserAddFavoriteRequest: Encodable {
    let animeId: Int
    let favoriteStatus: FavoriteStatus?
    let rating: Int
    let comment: String?

    init(
        animeId: Int,
        favoriteStatus: FavoriteStatus? = nil,
        rating: Int = 0,
        comment: String? = nil
    ) {
        self.animeId = animeId
        self.favoriteStatus = favoriteStatus
        self.rating = rating
        self.comment = comment
    }
}

struct FavoriteListResponse: Decodable {
    let success: Bool
    let errorMessage: String
    let favorites: [UserFavoriteItem]

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        favorites = (try? container.decodeIfPresent([UserFavoriteItem].self, forKey: .favorites)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage, favorites
    }
}

struct FavoriteMutationResponse: Decodable {
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

enum FavoriteUserDataError: LocalizedError, Equatable {
    case server(String)
    case invalidAnimeId
    case invalidRating
    case commentTooLong

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("收藏操作失败", comment: "") : message
        case .invalidAnimeId:
            return NSLocalizedString("作品编号无效", comment: "")
        case .invalidRating:
            return NSLocalizedString("评分必须在 1-10 分之间", comment: "")
        case .commentTooLong:
            return NSLocalizedString("短评不能超过 500 个字符", comment: "")
        }
    }
}

/// 收藏相关的用户数据接口。
///
/// 服务端语义（与 Windows `UserAddFavoriteRequest` 一致）：
/// - `favoriteStatus` 为空表示不改状态；
/// - `rating` 为 0 表示不改分数；
/// - `comment` 为空表示不改，传空格表示清空。
final class FavoriteUserDataService {
    static let maxCommentLength = 500

    private let client: AuthenticatedAPIClient
    private let environment: APIEnvironment

    init(
        client: AuthenticatedAPIClient = AuthenticatedAPIClient(),
        environment: APIEnvironment = .current()
    ) {
        self.client = client
        self.environment = environment
    }

    /// GET /favorite
    func fetchFavorites(onlyOnAir: Bool? = nil) async throws -> [UserFavoriteItem] {
        guard let baseURL = environment.makeURL("/favorite") else {
            throw APIError.invalidURL
        }

        var url = baseURL
        if let onlyOnAir = onlyOnAir {
            var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
            components?.queryItems = [
                URLQueryItem(name: "onlyOnAir", value: onlyOnAir ? "true" : "false")
            ]
            guard let composed = components?.url else {
                throw APIError.invalidURL
            }
            url = composed
        }

        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )

        let data = try await client.send(request)
        let response = try Self.decode(FavoriteListResponse.self, from: data)
        guard response.success else {
            throw FavoriteUserDataError.server(response.errorMessage)
        }
        return response.favorites
    }

    /// POST /favorite
    func updateFavorite(
        animeId: Int,
        favoriteStatus: FavoriteStatus? = nil,
        rating: Int = 0,
        comment: String? = nil
    ) async throws {
        guard animeId > 0 else {
            throw FavoriteUserDataError.invalidAnimeId
        }
        guard (0...10).contains(rating) else {
            throw FavoriteUserDataError.invalidRating
        }

        let normalizedComment = Self.normalizeComment(comment)
        if let normalizedComment = normalizedComment,
           normalizedComment.count > Self.maxCommentLength {
            throw FavoriteUserDataError.commentTooLong
        }

        let status = favoriteStatus == .unknow ? nil : favoriteStatus
        let payload = UserAddFavoriteRequest(
            animeId: animeId,
            favoriteStatus: status,
            rating: rating,
            comment: normalizedComment
        )

        guard let url = environment.makeURL("/favorite") else {
            throw APIError.invalidURL
        }
        let body = try JSONEncoder().encode(payload)
        let request = APIClient.jsonRequest(
            url: url,
            method: .post,
            body: body,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )

        let data = try await client.send(request)
        let response = try Self.decode(FavoriteMutationResponse.self, from: data)
        guard response.success else {
            throw FavoriteUserDataError.server(response.errorMessage)
        }
    }

    /// DELETE /favorite/{animeId}
    func removeFavorite(animeId: Int) async throws {
        guard animeId > 0 else {
            throw FavoriteUserDataError.invalidAnimeId
        }
        guard let url = environment.makeURL("/favorite/\(animeId)") else {
            throw APIError.invalidURL
        }
        let request = APIClient.jsonRequest(
            url: url,
            method: .delete,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )

        let data = try await client.send(request)
        let response = try Self.decode(FavoriteMutationResponse.self, from: data)
        guard response.success else {
            throw FavoriteUserDataError.server(response.errorMessage)
        }
    }

    /// 客户端先 trim，同时保留「空内容 = 清空」的服务端语义。
    ///
    /// - nil：不修改；
    /// - 空串/纯空白：返回一个空格（服务端视为清空）；
    /// - 其他：返回 trim 后的文本。
    static func normalizeComment(_ comment: String?) -> String? {
        guard let comment = comment else { return nil }
        let trimmed = comment.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? " " : trimmed
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        do {
            return try JSONDecoder().decode(type, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }
}
