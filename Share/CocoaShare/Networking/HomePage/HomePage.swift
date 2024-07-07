//
//  HomePage.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation

/// 公告
struct BannerPageItem: Decodable {
    
    /// 公告ID
    @Default<Int> var id: Int
    
    /// 标题
    @Default<String> var title: String
    
    /// 子标题、描述 ,
    @Default<String> var description: String
    
    /// 落地页链接
    @Default<String> var url: String
    
    /// 图片地址
    @Default<String> var imageUrl: String
    
}

struct Homepage: Decodable {
    
    /// 公告列表
    @Default<[BannerPageItem]> var banners: [BannerPageItem]
    
    /// 未看剧集列表
    @Default<[BangumiQueueIntro]> var bangumiQueueIntroList: [BangumiQueueIntro]
    
    /// 新番列表
    @Default<[BangumiIntro]> var shinBangumiList: [BangumiIntro]
    
    /// 动画番剧季度列表
    @Default<[BangumiSeason]> var bangumiSeasons: [BangumiSeason]
    
}
