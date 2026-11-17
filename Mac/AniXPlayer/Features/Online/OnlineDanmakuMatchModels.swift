//
//  OnlineDanmakuMatchModels.swift
//  AniXPlayer
//
//  macOS：在线播放前「选择弹幕库」的纯逻辑。
//

import Foundation

/// 在线播放前弹幕选择的结果。
enum OnlineDanmakuMatchOutcome {
    /// 用户选定了某个弹幕库条目。
    case matched(Match)
    /// 用户选择直接播放，不加载弹幕。
    case directPlay
    /// 用户取消，本次播放不应开始。
    case cancelled
}

/// 在线剧集用于弹幕匹配的虚拟文件名。
enum OnlineDanmakuMatchQuery {

    /// 去掉虚拟文件名末尾的 `.mp4`；其他点号（例如「1.5 话」）保持不变。
    static func normalizeVirtualName(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.lowercased().hasSuffix(".mp4") else { return trimmed }
        return String(trimmed.dropLast(4)).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 对齐 Windows 版：`作品名 + 剧集名`，不带扩展名。
    static func keyword(subjectTitle: String, episodeTitle: String) -> String {
        return normalizeVirtualName("\(subjectTitle) \(episodeTitle)")
    }
}
