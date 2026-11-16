//
//  DanmakuListLogic.swift
//  AniXPlayer
//
//  macOS only：弹幕列表的排序、搜索与屏蔽状态计算（纯逻辑，便于单测）。
//

import Foundation

/// 弹幕列表中的一行。
///
/// 只保留展示需要的字段，避免列表窗口长期持有渲染实体。
struct DanmakuListEntry: Equatable {

    /// 排序/显示使用的时间（秒）。
    let time: TimeInterval

    /// 弹幕文本。
    let text: String

    /// 是否已被屏蔽（加载时的过滤结果，或当前屏蔽规则命中）。
    let isFiltered: Bool

    /// 发送者 userId；模型只按文本屏蔽时用于展示/后续扩展。
    let userId: String

    /// 弹幕来源。
    let source: String

    /// 弹幕 cid；暂不支持按单条删除，保留用于后续任务。
    let commentId: Int

    func withFiltered(_ isFiltered: Bool) -> DanmakuListEntry {
        return DanmakuListEntry(
            time: time,
            text: text,
            isFiltered: isFiltered,
            userId: userId,
            source: source,
            commentId: commentId
        )
    }
}

/// `FilterDanmaku` 的轻量副本，避免纯逻辑依赖 AppKit / 弹幕渲染模块。
struct DanmakuListFilterRule: Equatable {
    let text: String
    let isRegularExpression: Bool
    let isEnabled: Bool
}

enum DanmakuListLogic {

    // MARK: - 时间

    /// 列表使用的时间：优先原始出现时间，其次弹幕数据时间，最后渲染时间。
    static func resolvedTime(
        originAppearTime: TimeInterval?,
        rawCommentTime: TimeInterval?,
        appearTime: TimeInterval?
    ) -> TimeInterval {
        return originAppearTime ?? rawCommentTime ?? appearTime ?? 0
    }

    /// 表格时间列：不足 1 小时显示 mm:ss，超过 1 小时显示 h:mm:ss。
    static func formattedTime(_ time: TimeInterval) -> String {
        let totalSeconds = max(0, Int(time))
        let hours = totalSeconds / 3_600
        let minutes = (totalSeconds % 3_600) / 60
        let seconds = totalSeconds % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    // MARK: - 屏蔽

    /// 与 `PlayerDanmakuProducer.isMatch` 保持一致：正则或完全相等，禁用规则跳过。
    static func matchesFilter(text: String, rules: [DanmakuListFilterRule]) -> Bool {
        for rule in rules {
            guard rule.isEnabled else { continue }

            if rule.isRegularExpression {
                if text.range(of: rule.text, options: .regularExpression) != nil {
                    return true
                }
            } else if text == rule.text {
                return true
            }
        }
        return false
    }

    // MARK: - 排序与搜索

    static func sorted(_ entries: [DanmakuListEntry]) -> [DanmakuListEntry] {
        return entries.enumerated().sorted { lhs, rhs in
            if lhs.element.time != rhs.element.time {
                return lhs.element.time < rhs.element.time
            }
            // 时间相同时保持原始顺序，结果可预期。
            return lhs.offset < rhs.offset
        }.map { $0.element }
    }

    /// 排序并合并「加载时过滤结果 + 当前屏蔽规则」。
    static func prepared(_ entries: [DanmakuListEntry], filterRules: [DanmakuListFilterRule]) -> [DanmakuListEntry] {
        return sorted(entries).map { entry in
            let isFiltered = entry.isFiltered || matchesFilter(text: entry.text, rules: filterRules)
            return entry.withFiltered(isFiltered)
        }
    }

    /// 按文本搜索；大小写、变音符号不敏感，空关键词返回全部。
    static func searched(_ entries: [DanmakuListEntry], text: String) -> [DanmakuListEntry] {
        let keyword = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !keyword.isEmpty else { return entries }

        return entries.filter { entry in
            entry.text.range(
                of: keyword,
                options: [.caseInsensitive, .diacriticInsensitive]
            ) != nil
        }
    }

    static func filteredCount(_ entries: [DanmakuListEntry]) -> Int {
        return entries.lazy.filter { $0.isFiltered }.count
    }
}
