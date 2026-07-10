//
//  TimelineItemCollectionViewCell.swift
//  AniXPlayer
//
//  tvOS 新番时间表 Cell — 继承 AnimeListCollectionViewCell
//

import UIKit

extension BangumiIntro: AnimeListItem {
    var hasRating: Bool { true }
    var typeDescription: String { "" }
}

class TimelineItemCollectionViewCell: AnimeListCollectionViewCell { }
