//
//  SubtitleTranslationEngine.swift
//  AniXPlayer
//
//  macOS only：字幕翻译批处理编排。
//
//  - 最多 4 个并发请求；
//  - 单批失败不影响其他批次，已返回的译文全部保留；
//  - 支持取消，取消后返回已有结果。
//

import Foundation

struct SubtitleTranslationBatchFailure: Equatable {
    /// 从 1 开始的批次序号。
    let batchNumber: Int
    let errorCode: Int?
    let message: String
}

struct SubtitleTranslationEvent {
    let response: SubtitleTranslateResponse?
    let texts: [String]
    let failure: SubtitleTranslationBatchFailure?
    let completedBatchCount: Int
    let totalBatchCount: Int
}

struct SubtitleTranslationOutcome {
    var translations: [String: String] = [:]
    var failures: [SubtitleTranslationBatchFailure] = []
    var usage: Int = 0
    var countRemain: Int?
    var hasContentFilterFailure = false
    var completedBatchCount = 0
    var totalBatchCount = 0
    var pendingTextCount = 0
    var wasCancelled = false
    var planMode: TranslationBatchMode?

    var hasFailure: Bool { !failures.isEmpty }
    var hasReachLimitFailure: Bool {
        failures.contains { $0.errorCode == TranslationErrorCode.reachLimit }
    }
}

final class SubtitleTranslationEngine {
    typealias EventHandler = @MainActor (SubtitleTranslationEvent) -> Void

    private let api: SubtitleTranslationAPIProviding
    private let maxConcurrentBatches: Int

    init(
        api: SubtitleTranslationAPIProviding = SubtitleTranslationAPIClient(),
        maxConcurrentBatches: Int = 4
    ) {
        self.api = api
        self.maxConcurrentBatches = max(1, maxConcurrentBatches)
    }

    func translate(
        texts: [String],
        totalLineCount: Int,
        serviceID: Int,
        fromLanguage: String,
        toLanguage: String,
        fileName: String,
        onEvent: EventHandler? = nil
    ) async -> SubtitleTranslationOutcome {
        let plan = SubtitleBatchPlanner.plan(
            texts: texts,
            serviceID: serviceID,
            totalLineCount: totalLineCount
        )

        var outcome = SubtitleTranslationOutcome()
        outcome.totalBatchCount = plan.batches.count
        outcome.pendingTextCount = plan.texts.count
        outcome.planMode = plan.mode

        guard !plan.batches.isEmpty else {
            return outcome
        }

        if Task.isCancelled {
            outcome.wasCancelled = true
            return outcome
        }

        await withTaskGroup(of: BatchOutput.self) { group in
            var nextBatchIndex = 0
            let initialCount = min(maxConcurrentBatches, plan.batches.count)

            for index in 0..<initialCount {
                addBatch(
                    index: index,
                    plan: plan,
                    serviceID: serviceID,
                    fromLanguage: fromLanguage,
                    toLanguage: toLanguage,
                    fileName: fileName,
                    group: &group
                )
            }
            nextBatchIndex = initialCount

            var completed = 0
            while let output = await group.next() {
                if output.wasCancelled {
                    outcome.wasCancelled = true
                    group.cancelAll()
                    break
                }

                completed += 1
                outcome.completedBatchCount = completed

                if let response = output.response {
                    merge(response: response, into: &outcome, batchNumber: output.index + 1)
                } else if let failure = output.failure {
                    outcome.failures.append(failure)
                }

                if let onEvent = onEvent {
                    let event = SubtitleTranslationEvent(
                        response: output.response,
                        texts: output.texts,
                        failure: output.failure,
                        completedBatchCount: completed,
                        totalBatchCount: plan.batches.count
                    )
                    await MainActor.run {
                        onEvent(event)
                    }
                }

                if Task.isCancelled {
                    outcome.wasCancelled = true
                    group.cancelAll()
                    break
                }

                if nextBatchIndex < plan.batches.count {
                    addBatch(
                        index: nextBatchIndex,
                        plan: plan,
                        serviceID: serviceID,
                        fromLanguage: fromLanguage,
                        toLanguage: toLanguage,
                        fileName: fileName,
                        group: &group
                    )
                    nextBatchIndex += 1
                }
            }

            if Task.isCancelled {
                outcome.wasCancelled = true
                group.cancelAll()
            }
        }

        return outcome
    }

    // MARK: - Private

    private struct BatchOutput {
        let index: Int
        let texts: [String]
        let response: SubtitleTranslateResponse?
        let failure: SubtitleTranslationBatchFailure?
        let wasCancelled: Bool
    }

    private func addBatch(
        index: Int,
        plan: SubtitleBatchPlan,
        serviceID: Int,
        fromLanguage: String,
        toLanguage: String,
        fileName: String,
        group: inout TaskGroup<BatchOutput>
    ) {
        let texts = plan.batches[index]
        let request = SubtitleTranslateRequest(
            texts: texts,
            fromLanguage: fromLanguage,
            toLanguage: toLanguage,
            fileName: fileName,
            service: serviceID
        )
        let api = self.api

        group.addTask {
            if Task.isCancelled {
                return BatchOutput(index: index, texts: texts, response: nil, failure: nil, wasCancelled: true)
            }

            do {
                let response = try await api.translate(request)
                return BatchOutput(
                    index: index,
                    texts: texts,
                    response: response,
                    failure: nil,
                    wasCancelled: false
                )
            } catch {
                if Task.isCancelled || Self.isCancellation(error) {
                    return BatchOutput(index: index, texts: texts, response: nil, failure: nil, wasCancelled: true)
                }
                let failure = SubtitleTranslationBatchFailure(
                    batchNumber: index + 1,
                    errorCode: nil,
                    message: error.localizedDescription
                )
                return BatchOutput(
                    index: index,
                    texts: texts,
                    response: nil,
                    failure: failure,
                    wasCancelled: false
                )
            }
        }
    }

    private func merge(
        response: SubtitleTranslateResponse,
        into outcome: inout SubtitleTranslationOutcome,
        batchNumber: Int
    ) {
        outcome.usage += response.usage
        if let countRemain = response.countRemain {
            // 多批并发时完成顺序不确定；取最小值，避免额度已耗尽却显示旧余额。
            outcome.countRemain = outcome.countRemain.map { min($0, countRemain) } ?? countRemain
        }

        for (source, translated) in response.translation {
            guard !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            outcome.translations[source] = translated
        }

        guard !response.success else { return }

        if response.errorCode == TranslationErrorCode.chatGPTContentFilter {
            outcome.hasContentFilterFailure = true
        }
        let message: String
        if let errorMessage = response.errorMessage, !errorMessage.isEmpty {
            message = errorMessage
        } else {
            message = String(
                format: NSLocalizedString("翻译批次失败（错误码 %d）", comment: ""),
                response.errorCode
            )
        }
        outcome.failures.append(SubtitleTranslationBatchFailure(
            batchNumber: batchNumber,
            errorCode: response.errorCode,
            message: message
        ))
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if error is CancellationError {
            return true
        }
        if let apiError = error as? APIError, case .cancelled = apiError {
            return true
        }
        if let urlError = error as? URLError, urlError.code == .cancelled {
            return true
        }
        return false
    }
}
