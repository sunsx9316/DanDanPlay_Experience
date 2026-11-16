//
//  OnlineSearchMerger.swift
//  AniXPlayer
//
//  macOS：在线源并发搜索结果的合并逻辑。
//
//  单独拆出纯函数，便于测试“单源失败不影响其他源”；
//  OnlinePlaybackService 只负责发起请求。
//

import Foundation

struct OnlineSearchSourceResult {
    let source: OnlineMediaSource
    let subjects: [OnlineSubject]
    let error: Error?
}

enum OnlineSearchMerger {

    static func makeOutcome(
        results: [OnlineSearchSourceResult],
        sourceCount: Int,
        pinnedSourceIDs: Set<String>
    ) -> OnlineSearchOutcome {
        var failures: [String: String] = [:]
        var subjects: [OnlineSubject] = []
        var seen = Set<String>()

        let sorted = results.sorted { lhs, rhs in
            let lhsPinned = pinnedSourceIDs.contains(lhs.source.id)
            let rhsPinned = pinnedSourceIDs.contains(rhs.source.id)
            if lhsPinned != rhsPinned {
                return lhsPinned
            }
            if lhs.source.tier != rhs.source.tier {
                return lhs.source.tier < rhs.source.tier
            }
            if lhs.source.name != rhs.source.name {
                return lhs.source.name.localizedStandardCompare(rhs.source.name) == .orderedAscending
            }
            return false
        }

        for result in sorted {
            if let error = result.error {
                failures[result.source.name] = error.localizedDescription
                continue
            }
            for subject in result.subjects {
                guard seen.insert(subject.identityKey).inserted else { continue }
                subjects.append(subject)
            }
        }

        return OnlineSearchOutcome(
            subjects: Array(subjects.prefix(200)),
            failures: failures,
            sourceCount: sourceCount
        )
    }
}
