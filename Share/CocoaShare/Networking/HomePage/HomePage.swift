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

/// 未看剧集
struct BangumiQueueIntro: Decodable {
    /// 作品编号
    @Default<Int> var animeId: Int
    
    /// 作品标题
    @Default<String> var animeTitle: String
    
    /// 最新一集的剧集标题
    @Default<String> var episodeTitle: String
    
    /// 剧集上映日期 （无小时分钟，当地时间）
    @Default<String> var airDate: String
    
    /// 海报图片地址
    @Default<String> var imageUrl: String
    
    /// 未看状态的说明 如“今天更新”，“昨天更新”，“有多集未看”等 ,
    @Default<String> var description: String
    
    /// 番剧是否在连载中
    @Default<Bool> var isOnAir: Bool
}

/// 新番列表
struct BangumiIntro: Decodable {
    /// 作品编号
    @Default<Int> var animeId: Int
    
    /// 作品标题
    @Default<String> var animeTitle: String
    
    /// 海报图片地址
    @Default<String> var imageUrl: String
    
    /// 搜索关键词
    @Default<String> var searchKeyword: String
    
    /// 是否正在连载中
    @Default<Bool> var isOnAir: Bool
    
    /// 周几上映，0代表周日，1-6代表周一至周六
    @Default<Int> var airDay: Int
    
    /// 当前用户是否已关注（无论是否为已弃番等附加状态）
    @Default<Bool> var isFavorited: Bool
    
    /// 是否为限制级别的内容（例如属于R18分级
    @Default<Bool> var isRestricted: Bool
    
    /// 番剧综合评分（综合多个来源的评分求出的加权平均值，0-10分）
    @Default<Double> var rating: Double
}

/// 动画番剧季度
struct BangumiSeason: Decodable {
    /// 年份
    @Default<Int> var year: Int
    
    /// 月份
    @Default<Int> var month: Int
    
    /// 季度名称
    @Default<String> var seasonName: String
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
