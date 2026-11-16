//
//  BangumiDetailDateFormatter.swift
//  AniXPlayer
//
//  macOS：详情页统一日期格式，避免展示到秒。
//

import Foundation

enum BangumiDetailDateFormatter {

    static let day: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    static let minute: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        return formatter
    }()
}
