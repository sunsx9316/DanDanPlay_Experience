//
//  BackupDanmakuMerge.swift
//  AniXPlayer
//
//  macOS only：会员补充弹幕的去重合并（纯逻辑，便于单测）。
//

import Foundation

/// 弹幕去重键：出现时间、模式、颜色、文本。
struct BackupDanmakuKey: Hashable, Comparable {
    let timeMilliseconds: Int
    let mode: Int
    let color: Int
    let message: String

    init(timeMilliseconds: Int, mode: Int, color: Int, message: String) {
        self.timeMilliseconds = timeMilliseconds
        self.mode = mode
        self.color = color
        self.message = message
    }

    static func < (lhs: BackupDanmakuKey, rhs: BackupDanmakuKey) -> Bool {
        if lhs.timeMilliseconds != rhs.timeMilliseconds {
            return lhs.timeMilliseconds < rhs.timeMilliseconds
        }
        if lhs.mode != rhs.mode {
            return lhs.mode < rhs.mode
        }
        if lhs.color != rhs.color {
            return lhs.color < rhs.color
        }
        return lhs.message < rhs.message
    }
}

struct BackupDanmakuMergePlan {
    /// 新弹幕在 `fetched` 中的下标，按时间排序。
    let addedIndices: [Int]
    /// 新增弹幕的去重键，按时间排序。
    let addedKeys: [BackupDanmakuKey]

    var addedCount: Int {
        return addedKeys.count
    }
}

enum BackupDanmakuMerger {
    /// 计算需要追加的弹幕；`existing` 中已有的键（以及 `fetched` 内重复的键）会被跳过。
    static func plan(existing: Set<BackupDanmakuKey>, fetched: [BackupDanmakuKey]) -> BackupDanmakuMergePlan {
        var seen = existing
        var added: [(index: Int, key: BackupDanmakuKey)] = []

        for (index, key) in fetched.enumerated() {
            if seen.insert(key).inserted {
                added.append((index, key))
            }
        }

        added.sort { $0.key < $1.key }
        return BackupDanmakuMergePlan(
            addedIndices: added.map { $0.index },
            addedKeys: added.map { $0.key }
        )
    }

    /// 纯逻辑版本的合并结果：去重、按时间排序。
    static func merge(
        existing: [BackupDanmakuKey],
        fetched: [BackupDanmakuKey]
    ) -> (keys: [BackupDanmakuKey], addedCount: Int) {
        let plan = plan(existing: Set(existing), fetched: fetched)
        var merged = existing
        merged.append(contentsOf: plan.addedKeys)
        merged.sort()
        return (merged, plan.addedCount)
    }
}
