//
//  PlayHistoryModels.swift
//  AniXPlayer
//
//  macOS：服务端播放历史。字段对齐 Windows UserPlayHistoryResponse。
//

import Foundation

struct PlayHistoryEpisode: Decodable {
    let episodeId: Int
    let episodeTitle: String
    let episodeNumber: String
    let lastWatched: Date?

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        episodeId = (try? c.decodeIfPresent(Int.self, forKey: .episodeId)) ?? 0
        episodeTitle = (try? c.decodeIfPresent(String.self, forKey: .episodeTitle)) ?? ""
        episodeNumber = (try? c.decodeIfPresent(String.self, forKey: .episodeNumber)) ?? ""
        let raw = try? c.decodeIfPresent(String.self, forKey: .lastWatched)
        lastWatched = raw.flatMap { DDPDateParser.parse($0) }
    }

    private enum CodingKeys: String, CodingKey {
        case episodeId, episodeTitle, episodeNumber, lastWatched
    }
}

struct PlayHistoryAnime: Decodable {
    let animeId: Int
    let animeTitle: String
    let typeDescription: String
    let imageUrl: String
    let isOnAir: Bool
    let episodes: [PlayHistoryEpisode]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        animeId = (try? c.decodeIfPresent(Int.self, forKey: .animeId)) ?? 0
        animeTitle = (try? c.decodeIfPresent(String.self, forKey: .animeTitle)) ?? ""
        typeDescription = (try? c.decodeIfPresent(String.self, forKey: .typeDescription)) ?? ""
        imageUrl = (try? c.decodeIfPresent(String.self, forKey: .imageUrl)) ?? ""
        isOnAir = (try? c.decodeIfPresent(Bool.self, forKey: .isOnAir)) ?? false
        episodes = (try? c.decodeIfPresent([PlayHistoryEpisode].self, forKey: .episodes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case animeId, animeTitle, typeDescription, imageUrl, isOnAir, episodes
    }
}

struct PlayHistoryResponse: Decodable {
    let success: Bool
    let errorMessage: String
    let animes: [PlayHistoryAnime]

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? c.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? c.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
        animes = (try? c.decodeIfPresent([PlayHistoryAnime].self, forKey: .animes)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage
        case animes = "playHistoryAnimes"
    }
}

struct AddPlayHistoryRequest: Encodable {
    let episodeIdList: [Int]
    let addToFavorite: Bool
    let rating: Int

    init(episodeId: Int, addToFavorite: Bool = false, rating: Int = 0) {
        self.episodeIdList = [episodeId]
        self.addToFavorite = addToFavorite
        self.rating = rating
    }
}
