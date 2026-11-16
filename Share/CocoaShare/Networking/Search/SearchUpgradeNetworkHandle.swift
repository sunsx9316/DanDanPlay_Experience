//
//  SearchUpgradeNetworkHandle.swift
//  AniXPlayer
//
//  macOS：搜索升级接口（Bearer + 401 刷新），全部使用 async/await。
//

import Foundation

final class SearchUpgradeNetworkHandle {

    // MARK: - 动画搜索

    static func searchAnime(keyword: String) async throws -> SearchUpgradeAnimeResponse {
        let environment = APIEnvironment.current()
        let url = try SearchUpgradeRequest.animeURL(keyword: keyword, environment: environment)
        return try await get(url: url, environment: environment)
    }

    // MARK: - 剧集搜索

    static func searchEpisodes(anime: String, episode: String? = nil) async throws -> SearchUpgradeEpisodesResponse {
        let environment = APIEnvironment.current()
        let url = try SearchUpgradeRequest.episodesURL(anime: anime, episode: episode, environment: environment)
        return try await get(url: url, environment: environment)
    }

    // MARK: - 标签搜索

    static func searchByTags(tags: [String]) async throws -> SearchUpgradeBangumiResponse {
        let environment = APIEnvironment.current()
        let url = try SearchUpgradeRequest.tagsURL(tags: tags, environment: environment)
        return try await get(url: url, environment: environment)
    }

    static func searchByTags(rawTags: String) async throws -> SearchUpgradeBangumiResponse {
        let environment = APIEnvironment.current()
        let url = try SearchUpgradeRequest.tagsURL(rawTags: rawTags, environment: environment)
        return try await get(url: url, environment: environment)
    }

    // MARK: - 高级搜索

    static func advancedConfig(source: String = SearchUpgradeRequest.defaultSource) async throws -> SearchUpgradeAdvancedConfigResponse {
        let environment = APIEnvironment.current()
        let url = try SearchUpgradeRequest.advancedConfigURL(source: source, environment: environment)
        return try await get(url: url, environment: environment)
    }

    static func advancedSearch(_ query: SearchUpgradeAdvancedQuery) async throws -> SearchUpgradeBangumiResponse {
        let environment = APIEnvironment.current()
        let url = try SearchUpgradeRequest.advancedSearchURL(query: query, environment: environment)
        return try await get(url: url, environment: environment)
    }

    // MARK: - Private

    private static func get<T: Decodable & SearchUpgradeServerResponse>(
        url: URL,
        environment: APIEnvironment
    ) async throws -> T {
        let request = APIClient.jsonRequest(
            url: url,
            method: .get,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )
        let response: T = try await AuthenticatedAPIClient().send(request)
        if !response.success {
            throw SearchUpgradeError.server(response.errorMessage)
        }
        return response
    }
}
