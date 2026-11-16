//
//  SubtitleTranslationModels.swift
//  AniXPlayer
//
//  macOS only：AI 字幕翻译的语言 / 服务 / 接口模型。
//

import Foundation

// MARK: - Request / Response

struct SubtitleTranslateRequest: Encodable, Equatable {
    /// 需要翻译的文本列表。
    let texts: [String]
    /// 源语言代码；空字符串表示自动检测。
    let fromLanguage: String
    /// 目标语言代码。
    let toLanguage: String
    /// 字幕文件名（包含扩展名）。
    let fileName: String
    /// 使用的翻译服务 id。
    let service: Int
}

struct SubtitleTranslateResponse: Decodable, Equatable {
    let success: Bool
    let errorCode: Int
    let errorMessage: String?
    /// 每个文本的翻译结果。
    let translation: [String: String]
    /// 目标语言。
    let language: String?
    /// 本次调用消耗的用量（调用次数 / 字符数量）。
    let usage: Int
    /// 当前用户本月（1 日 - 月底）接口剩余用量。
    let countRemain: Int?

    init(
        success: Bool,
        errorCode: Int = 0,
        errorMessage: String? = nil,
        translation: [String: String] = [:],
        language: String? = nil,
        usage: Int = 0,
        countRemain: Int? = nil
    ) {
        self.success = success
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.translation = translation
        self.language = language
        self.usage = usage
        self.countRemain = countRemain
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case errorCode
        case errorMessage
        case translation
        case language
        case usage
        case countRemain
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode) ?? 0
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        translation = try container.decodeIfPresent([String: String].self, forKey: .translation) ?? [:]
        language = try container.decodeIfPresent(String.self, forKey: .language)
        usage = try container.decodeIfPresent(Int.self, forKey: .usage) ?? 0
        countRemain = try container.decodeIfPresent(Int.self, forKey: .countRemain)
    }
}

struct SubtitleServiceItem: Decodable, Equatable {
    let id: Int
    let name: String
}

struct SubtitleServiceListResponse: Decodable, Equatable {
    let success: Bool
    let errorCode: Int
    let errorMessage: String?
    let services: [SubtitleServiceItem]

    init(
        success: Bool,
        errorCode: Int = 0,
        errorMessage: String? = nil,
        services: [SubtitleServiceItem] = []
    ) {
        self.success = success
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.services = services
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case errorCode
        case errorMessage
        case services
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode) ?? 0
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        services = try container.decodeIfPresent([SubtitleServiceItem].self, forKey: .services) ?? []
    }
}

struct SubtitleServiceUsageItem: Decodable, Equatable {
    let id: Int
    let name: String
    let usage: Int
    let remain: Int
    let total: Int

    init(id: Int, name: String, usage: Int, remain: Int, total: Int) {
        self.id = id
        self.name = name
        self.usage = usage
        self.remain = remain
        self.total = total
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case usage
        case remain
        case total
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(Int.self, forKey: .id) ?? 0
        name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        usage = try container.decodeIfPresent(Int.self, forKey: .usage) ?? 0
        remain = try container.decodeIfPresent(Int.self, forKey: .remain) ?? 0
        total = try container.decodeIfPresent(Int.self, forKey: .total) ?? 0
    }
}

struct SubtitleServiceUsageResponse: Decodable, Equatable {
    let success: Bool
    let errorCode: Int
    let errorMessage: String?
    let currentPeriod: String?
    let currentPeriodStart: String?
    let currentPeriodEnd: String?
    let services: [SubtitleServiceUsageItem]

    init(
        success: Bool,
        errorCode: Int = 0,
        errorMessage: String? = nil,
        currentPeriod: String? = nil,
        currentPeriodStart: String? = nil,
        currentPeriodEnd: String? = nil,
        services: [SubtitleServiceUsageItem] = []
    ) {
        self.success = success
        self.errorCode = errorCode
        self.errorMessage = errorMessage
        self.currentPeriod = currentPeriod
        self.currentPeriodStart = currentPeriodStart
        self.currentPeriodEnd = currentPeriodEnd
        self.services = services
    }

    private enum CodingKeys: String, CodingKey {
        case success
        case errorCode
        case errorMessage
        case currentPeriod
        case currentPeriodStart
        case currentPeriodEnd
        case services
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = try container.decodeIfPresent(Bool.self, forKey: .success) ?? false
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode) ?? 0
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage)
        currentPeriod = try container.decodeIfPresent(String.self, forKey: .currentPeriod)
        currentPeriodStart = Self.decodeDateString(container, key: .currentPeriodStart)
        currentPeriodEnd = Self.decodeDateString(container, key: .currentPeriodEnd)
        services = try container.decodeIfPresent([SubtitleServiceUsageItem].self, forKey: .services) ?? []
    }

    /// Windows 里 currentPeriodStart/End 是 DateTime；服务端可能返回 ISO 字符串，
    /// 这里只做展示，能用字符串就用字符串，避免时区解析失败导致整个额度展示不可用。
    private static func decodeDateString(
        _ container: KeyedDecodingContainer<CodingKeys>,
        key: CodingKeys
    ) -> String? {
        if let value = try? container.decodeIfPresent(String.self, forKey: key) {
            return value
        }
        if let value = try? container.decodeIfPresent(Date.self, forKey: key) {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            return formatter.string(from: value)
        }
        return nil
    }
}

// MARK: - Catalog

struct TranslationServiceOption: Equatable {
    let id: Int
    let name: String
}

enum TranslationServiceCatalog {
    /// 接口不可用时的内置默认列表（与 Windows 一致）。
    static let fallback: [TranslationServiceOption] = [
        TranslationServiceOption(id: 0, name: NSLocalizedString("默认", comment: "")),
        TranslationServiceOption(id: 1, name: NSLocalizedString("Azure翻译", comment: "")),
        TranslationServiceOption(id: 5, name: "GPT-4o"),
        TranslationServiceOption(id: 6, name: "GPT-4o mini"),
    ]

    static let defaultServiceID = 0
}

struct TranslationLanguageOption: Equatable {
    let code: String
    let displayName: String

    var menuTitle: String {
        code.isEmpty ? displayName : "\(displayName)（\(code)）"
    }
}

enum TranslationLanguages {
    /// 自动检测 + Azure/DeepL 支持的语言，与 Windows 的列表对齐。
    static let from: [TranslationLanguageOption] = [
        .init(code: "", displayName: NSLocalizedString("自动检测语言", comment: "")),
        .init(code: "JA", displayName: NSLocalizedString("日语", comment: "")),
        .init(code: "ZH", displayName: NSLocalizedString("中文", comment: "")),
        .init(code: "BG", displayName: NSLocalizedString("保加利亚语", comment: "")),
        .init(code: "CS", displayName: NSLocalizedString("捷克语", comment: "")),
        .init(code: "DA", displayName: NSLocalizedString("丹麦语", comment: "")),
        .init(code: "DE", displayName: NSLocalizedString("德语", comment: "")),
        .init(code: "EL", displayName: NSLocalizedString("希腊语", comment: "")),
        .init(code: "EN", displayName: NSLocalizedString("英语", comment: "")),
        .init(code: "ES", displayName: NSLocalizedString("西班牙语", comment: "")),
        .init(code: "ET", displayName: NSLocalizedString("爱沙尼亚语", comment: "")),
        .init(code: "FI", displayName: NSLocalizedString("芬兰语", comment: "")),
        .init(code: "FR", displayName: NSLocalizedString("法语", comment: "")),
        .init(code: "HU", displayName: NSLocalizedString("匈牙利语", comment: "")),
        .init(code: "ID", displayName: NSLocalizedString("印度尼西亚语", comment: "")),
        .init(code: "IT", displayName: NSLocalizedString("意大利语", comment: "")),
        .init(code: "KO", displayName: NSLocalizedString("韩语", comment: "")),
        .init(code: "LT", displayName: NSLocalizedString("立陶宛语", comment: "")),
        .init(code: "LV", displayName: NSLocalizedString("拉脱维亚语", comment: "")),
        .init(code: "NB", displayName: NSLocalizedString("挪威博克马尔语", comment: "")),
        .init(code: "NL", displayName: NSLocalizedString("荷兰语", comment: "")),
        .init(code: "PL", displayName: NSLocalizedString("波兰语", comment: "")),
        .init(code: "PT", displayName: NSLocalizedString("葡萄牙语", comment: "")),
        .init(code: "RO", displayName: NSLocalizedString("罗马尼亚语", comment: "")),
        .init(code: "RU", displayName: NSLocalizedString("俄语", comment: "")),
        .init(code: "SK", displayName: NSLocalizedString("斯洛伐克语", comment: "")),
        .init(code: "SL", displayName: NSLocalizedString("斯洛文尼亚语", comment: "")),
        .init(code: "SV", displayName: NSLocalizedString("瑞典语", comment: "")),
        .init(code: "TR", displayName: NSLocalizedString("土耳其语", comment: "")),
        .init(code: "UK", displayName: NSLocalizedString("乌克兰语", comment: "")),
    ]

    /// 目标语言：简体 / 繁体中文 + 与 Windows 一致的语言集合。
    static let to: [TranslationLanguageOption] = [
        .init(code: "ZH", displayName: NSLocalizedString("简体中文", comment: "")),
        .init(code: "ZHT", displayName: NSLocalizedString("繁体中文", comment: "")),
        .init(code: "BG", displayName: NSLocalizedString("保加利亚语", comment: "")),
        .init(code: "CS", displayName: NSLocalizedString("捷克语", comment: "")),
        .init(code: "DA", displayName: NSLocalizedString("丹麦语", comment: "")),
        .init(code: "DE", displayName: NSLocalizedString("德语", comment: "")),
        .init(code: "EL", displayName: NSLocalizedString("希腊语", comment: "")),
        .init(code: "EN", displayName: NSLocalizedString("英语", comment: "")),
        .init(code: "ES", displayName: NSLocalizedString("西班牙语", comment: "")),
        .init(code: "ET", displayName: NSLocalizedString("爱沙尼亚语", comment: "")),
        .init(code: "FI", displayName: NSLocalizedString("芬兰语", comment: "")),
        .init(code: "FR", displayName: NSLocalizedString("法语", comment: "")),
        .init(code: "HU", displayName: NSLocalizedString("匈牙利语", comment: "")),
        .init(code: "ID", displayName: NSLocalizedString("印度尼西亚语", comment: "")),
        .init(code: "IT", displayName: NSLocalizedString("意大利语", comment: "")),
        .init(code: "JA", displayName: NSLocalizedString("日语", comment: "")),
        .init(code: "KO", displayName: NSLocalizedString("韩语", comment: "")),
        .init(code: "LT", displayName: NSLocalizedString("立陶宛语", comment: "")),
        .init(code: "LV", displayName: NSLocalizedString("拉脱维亚语", comment: "")),
        .init(code: "NB", displayName: NSLocalizedString("挪威博克马尔语", comment: "")),
        .init(code: "NL", displayName: NSLocalizedString("荷兰语", comment: "")),
        .init(code: "PL", displayName: NSLocalizedString("波兰语", comment: "")),
        .init(code: "PT", displayName: NSLocalizedString("葡萄牙语", comment: "")),
        .init(code: "RO", displayName: NSLocalizedString("罗马尼亚语", comment: "")),
        .init(code: "RU", displayName: NSLocalizedString("俄语", comment: "")),
        .init(code: "SK", displayName: NSLocalizedString("斯洛伐克语", comment: "")),
        .init(code: "SL", displayName: NSLocalizedString("斯洛文尼亚语", comment: "")),
        .init(code: "SV", displayName: NSLocalizedString("瑞典语", comment: "")),
        .init(code: "TR", displayName: NSLocalizedString("土耳其语", comment: "")),
        .init(code: "UK", displayName: NSLocalizedString("乌克兰语", comment: "")),
    ]

    static let defaultFromCode = ""
    static let defaultToCode = "ZH"

    static func fromDisplayName(for code: String) -> String {
        from.first(where: { $0.code == code })?.displayName ?? code
    }

    static func toDisplayName(for code: String) -> String {
        to.first(where: { $0.code == code })?.displayName ?? code
    }
}

/// 服务端已知错误码（见 Windows ErrorCode）。
enum TranslationErrorCode {
    static let requestTooLarge = 60
    static let reachLimit = 61
    static let chatGPTContentFilter = 62
}
