//
//  AnimeListItem+Extensions.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/10.
//

import Foundation

// MARK: - BangumiIntro

extension BangumiIntro: AnimeListItem {
    var typeDescription: String { "" }
}

// MARK: - UserFavoriteItem

extension UserFavoriteItem: AnimeListItem {
    var typeDescription: String { type.displayName }
    var isFavorited: Bool { favoriteStatus == .favorited }
}

// MARK: - SearchBangumiDetails

extension SearchBangumiDetails: AnimeListItem { }
