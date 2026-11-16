//
//  SubtitleBatchPlanner.swift
//  AniXPlayer
//
//  macOS only：AI 字幕翻译的文本去重与分批策略，对齐 Windows TranslationWindowViewModel。
//

import Foundation

enum TranslationBatchMode: Equatable {
    /// Azure 翻译：1 万字符 / 请求，不限制行数。
    case azure
    /// ChatGPT 慢速模式：250 字符 / 5 行。
    case chatGPTSlow
    /// ChatGPT 正常模式：500 字符 / 15 行。
    case chatGPTNormal

    var displayName: String {
        switch self {
        case .azure:
            return "Azure"
        case .chatGPTSlow:
            return NSLocalizedString("慢速模式", comment: "")
        case .chatGPTNormal:
            return NSLocalizedString("快速模式", comment: "")
        }
    }
}

struct SubtitleBatchPlan: Equatable {
    let mode: TranslationBatchMode
    /// 已去重、非空的待翻译文本。
    let texts: [String]
    let batches: [[String]]
    let maxCharactersPerBatch: Int
    let maxLinesPerBatch: Int
}

enum SubtitleBatchPlanner {
    static let azureMaxCharacters = 10_000
    static let chatGPTNormalMaxCharacters = 500
    static let chatGPTNormalMaxLines = 15
    static let chatGPTSlowMaxCharacters = 250
    static let chatGPTSlowMaxLines = 5

    /// 去重：trim 后非空，保持首次出现顺序。
    static func deduplicatedTexts(from texts: [String]) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for text in texts {
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if seen.insert(trimmed).inserted {
                result.append(trimmed)
            }
        }
        return result
    }

    /// - Parameters:
    ///   - texts: 待翻译文本（内部会去重）。
    ///   - serviceID: 1 = Azure，其余按大模型处理。
    ///   - totalLineCount: 整个字幕的行数（包含已翻译行），用于判断慢速/正常模式。
    static func plan(texts: [String], serviceID: Int, totalLineCount: Int) -> SubtitleBatchPlan {
        let pending = deduplicatedTexts(from: texts)

        let mode: TranslationBatchMode
        let maxCharacters: Int
        let maxLines: Int

        if serviceID == 1 {
            mode = .azure
            maxCharacters = azureMaxCharacters
            maxLines = Int.max
        } else if pending.count < 100 || pending.count * 4 < totalLineCount {
            // 与 Windows 完全一致：未翻译条数 < 100，或未翻译占比 < 25% 时用慢速模式。
            mode = .chatGPTSlow
            maxCharacters = chatGPTSlowMaxCharacters
            maxLines = chatGPTSlowMaxLines
        } else {
            mode = .chatGPTNormal
            maxCharacters = chatGPTNormalMaxCharacters
            maxLines = chatGPTNormalMaxLines
        }

        return SubtitleBatchPlan(
            mode: mode,
            texts: pending,
            batches: split(pending, maxCharacters: maxCharacters, maxLines: maxLines),
            maxCharactersPerBatch: maxCharacters,
            maxLinesPerBatch: maxLines
        )
    }

    /// Windows SplitTexts 的等价实现：先判断再加入，单条超长文本独占一批。
    static func split(_ texts: [String], maxCharacters: Int, maxLines: Int) -> [[String]] {
        var result: [[String]] = []
        var current: [String] = []
        var currentCharacters = 0

        for text in texts {
            if !current.isEmpty &&
                (currentCharacters + text.count > maxCharacters || current.count >= maxLines) {
                result.append(current)
                current = []
                currentCharacters = 0
            }

            currentCharacters += text.count
            current.append(text)
        }

        if !current.isEmpty {
            result.append(current)
        }

        return result
    }
}
