//
//  SummaryModels.swift
//  AniXPlayer
//
//  macOS only：AI 视频总结的请求/响应模型。
//

import Foundation

/// 单条转录文本。`start` 格式为 `mm:ss`（不足 1 小时）或 `hh:mm:ss`。
struct SummaryTranscription: Codable, Equatable, Hashable {
    let start: String
    let content: String
}

struct SummaryVideoRequest: Codable, Equatable {
    let fileName: String
    let fileHash: String
    let videoTitle: String
    let videoSubtitle: String
    let transcriptions: [SummaryTranscription]

    init(
        fileName: String = "",
        fileHash: String = "",
        videoTitle: String = "",
        videoSubtitle: String = "",
        transcriptions: [SummaryTranscription] = []
    ) {
        self.fileName = fileName
        self.fileHash = fileHash
        self.videoTitle = videoTitle
        self.videoSubtitle = videoSubtitle
        self.transcriptions = transcriptions
    }
}

struct SummaryTopic: Codable, Equatable {
    let order: Int
    let title: String
    let parts: [SummaryTopicPart]

    init(order: Int = 0, title: String = "", parts: [SummaryTopicPart] = []) {
        self.order = order
        self.title = title
        self.parts = parts
    }

    private enum CodingKeys: String, CodingKey {
        case order
        case title
        case parts
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        order = try container.decodeIfPresent(Int.self, forKey: .order) ?? 0
        title = try container.decodeIfPresent(String.self, forKey: .title) ?? ""
        parts = try container.decodeIfPresent([SummaryTopicPart].self, forKey: .parts) ?? []
    }
}

struct SummaryTopicPart: Codable, Equatable {
    let start: String
    let content: String

    init(start: String = "", content: String = "") {
        self.start = start
        self.content = content
    }

    private enum CodingKeys: String, CodingKey {
        case start
        case content
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        start = try container.decodeIfPresent(String.self, forKey: .start) ?? ""
        content = try container.decodeIfPresent(String.self, forKey: .content) ?? ""
    }
}

/// `/api/v2/ai/summary` 的响应。服务端错误通常也返回 HTTP 200，需要读取 `errorCode`。
struct SummaryVideoResponse: Codable, Equatable {
    let success: Bool?
    let errorCode: Int?
    let errorMessage: String?
    let summaryId: Int?
    let topics: [SummaryTopic]
    let summary: String
    let usage: Int?
    let countRemain: Int?

    /// `success` 可能缺省；只以非 0 的 `errorCode` 或显式 `success == false` 判失败。
    var isSuccess: Bool {
        return (errorCode ?? 0) == 0 && success != false
    }

    var hasContent: Bool {
        if !summary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return true
        }
        return topics.contains { topic in
            topic.parts.contains { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        }
    }

    init(
        success: Bool? = nil,
        errorCode: Int? = nil,
        errorMessage: String? = nil,
        summaryId: Int? = nil,
        topics: [SummaryTopic] = [],
        summary: String = "",
        usage: Int? = nil,
        countRemain: Int? = nil
    ) {
        self.success = success
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.summaryId = summaryId
        self.topics = topics
        self.summary = summary
        self.usage = usage
        self.countRemain = countRemain
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case errorCode
        case errorMessage
        case summaryId
        case topics
        case summary
        case usage
        case countRemain
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode)
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        summaryId = try container.decodeIfPresent(Int.self, forKey: .summaryId)
        topics = try container.decodeIfPresent([SummaryTopic].self, forKey: .topics) ?? []
        summary = try container.decodeIfPresent(String.self, forKey: .summary) ?? ""
        usage = try container.decodeIfPresent(Int.self, forKey: .usage)
        countRemain = try container.decodeIfPresent(Int.self, forKey: .countRemain)
    }
}

/// 把结构化总结转换为 Markdown（与 Windows 客户端格式保持一致）。
enum SummaryMarkdown {
    static func make(from response: SummaryVideoResponse) -> String {
        return make(summary: response.summary, topics: response.topics)
    }

    static func make(summary: String, topics: [SummaryTopic]) -> String {
        var lines: [String] = []

        let summaryText = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        if !summaryText.isEmpty {
            lines.append("**\(summaryText)**")
            lines.append("")
        }

        for topic in topics.sorted(by: { $0.order < $1.order }) {
            let title = topic.title.trimmingCharacters(in: .whitespacesAndNewlines)
            if !title.isEmpty {
                lines.append("**\(topic.order). \(title)**")
                lines.append("")
            }

            for part in topic.parts {
                let content = part.content.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else { continue }
                let start = part.start.trimmingCharacters(in: .whitespacesAndNewlines)
                if start.isEmpty {
                    lines.append("- \(content)")
                } else {
                    lines.append("- [\(start)](\(start)) \(content)")
                }
            }

            lines.append("")
        }

        return lines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

/// 接口与本地缓存约定的时间格式。
enum SummaryTranscriptTime {
    static func format(_ seconds: TimeInterval) -> String {
        let total = max(0, Int(seconds.rounded(.down)))
        let hours = total / 3600
        let minutes = (total % 3600) / 60
        let secs = total % 60

        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, secs)
        }
        return String(format: "%02d:%02d", minutes, secs)
    }
}
