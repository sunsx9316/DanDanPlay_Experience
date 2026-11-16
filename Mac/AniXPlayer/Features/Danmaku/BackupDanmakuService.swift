//
//  BackupDanmakuService.swift
//  AniXPlayer
//
//  macOS only：会员补充弹幕。
//
//  当前服务端没有独立的 macOS「备用弹幕」接口；这里重新拉取
//  `/comment/{episodeId}?withRelated=true`（绕过本地缓存），
//  再与正在播放的弹幕按 (时间, 模式, 颜色, 文本) 去重合并。
//

import Foundation
import ANXLog

@MainActor
final class BackupDanmakuService {
    struct MergeResult {
        let danmakus: DanmakuMapResult
        let addedCount: Int
        let totalCount: Int
    }

    static let shared = BackupDanmakuService()

    private init() {}

    /// 重新拉取关联弹幕并合并到现有弹幕中。
    func reloadAssociatedDanmaku(episodeId: Int, existing: DanmakuMapResult) async throws -> MergeResult {
        ANX.logInfo(.HTTP, "[BackupDanmaku] 请求补充弹幕 episodeId: \(episodeId)")
        let comments = try await fetchComments(episodeId: episodeId)
        let result = merge(existing: existing, fetched: comments)
        ANX.logInfo(
            .HTTP,
            "[BackupDanmaku] 补充弹幕完成，服务端返回 \(comments.count) 条，新增 \(result.addedCount) 条，总计 \(result.totalCount) 条"
        )
        return result
    }

    func merge(existing: DanmakuMapResult, fetched: [Comment]) -> MergeResult {
        var existingMap = DanmakuMapResult()
        var existingKeys = Set<BackupDanmakuKey>()
        var existingCount = 0

        for entities in existing.values {
            for entity in entities {
                existingCount += 1
                let time = entity.rawComment?.time ?? entity.originAppearTime ?? entity.appearTime
                let bucket = UInt(max(0, time.rounded(.down)))
                existingMap[bucket, default: []].append(entity)

                if let rawComment = entity.rawComment {
                    existingKeys.insert(BackupDanmakuKey(comment: rawComment))
                }
            }
        }

        let fetchedKeys = fetched.map { BackupDanmakuKey(comment: $0) }
        let plan = BackupDanmakuMerger.plan(existing: existingKeys, fetched: fetchedKeys)

        var merged = existingMap
        for index in plan.addedIndices {
            let comment = fetched[index]
            let entity = DanmakuManager.shared.conver(comment)
            let bucket = UInt(max(0, comment.time.rounded(.down)))
            merged[bucket, default: []].append(entity)
        }

        /// 字典本身无序，按时间重建一份，便于调用方/调试按时间观察。
        var sortedMap = DanmakuMapResult()
        for key in merged.keys.sorted() {
            sortedMap[key] = merged[key]
        }

        return MergeResult(
            danmakus: sortedMap,
            addedCount: plan.addedCount,
            totalCount: existingCount + plan.addedCount
        )
    }

    // MARK: - Network

    private func fetchComments(episodeId: Int) async throws -> [Comment] {
        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[Comment], Error>) in
            CommentNetworkHandle.getDanmaku(
                with: episodeId,
                withRelated: true,
                forceRefresh: true
            ) { collection, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: collection?.collection ?? [])
                }
            }
        }
    }
}

private extension BackupDanmakuKey {
    init(comment: Comment) {
        self.init(
            timeMilliseconds: Int((max(0, comment.time) * 1000).rounded()),
            mode: comment.mode.rawValue,
            color: comment.color.anxRgbValue,
            message: comment.message
        )
    }
}
