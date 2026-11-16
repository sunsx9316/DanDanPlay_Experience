//
//  SubtitleDocument.swift
//  AniXPlayer
//
//  macOS only：SRT / ASS / SSA 字幕解析与写回。
//
//  设计目标：
//  - 不引入第三方字幕库；
//  - ASS 只替换 [Events] 中 Dialogue 的 Text 字段，其余行保持原样；
//  - Text 中的 {...} 覆盖标签、\N/\n 换行、\h 等转义在写回时保留；
//  - 无法安全解析的 ASS Dialogue 原样保留，并计入 skippedLineCount。
//

import Foundation

enum SubtitleFormat: String, Equatable {
    case srt
    case ass
    case ssa

    var isASS: Bool {
        switch self {
        case .ass, .ssa:
            return true
        case .srt:
            return false
        }
    }

    static func from(url: URL) -> SubtitleFormat? {
        SubtitleFormat(rawValue: url.pathExtension.lowercased())
    }
}

enum SubtitleTranslationMode: Int, CaseIterable {
    /// 仅译文。
    case translated = 0
    /// 仅原文。
    case original = 1
    /// 原文 + 译文（双语）。
    case bilingual = 2

    var title: String {
        switch self {
        case .translated:
            return NSLocalizedString("仅译文", comment: "")
        case .original:
            return NSLocalizedString("仅原文", comment: "")
        case .bilingual:
            return NSLocalizedString("双语", comment: "")
        }
    }
}

enum SubtitleParseError: LocalizedError {
    case unsupportedFormat(String)
    case unreadable(Error)
    case empty
    case noSubtitles

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return String(format: NSLocalizedString("不支持的字幕格式：%@", comment: ""), ext)
        case .unreadable:
            return NSLocalizedString("无法读取字幕文件，请检查文件编码或权限", comment: "")
        case .empty:
            return NSLocalizedString("字幕文件为空", comment: "")
        case .noSubtitles:
            return NSLocalizedString("没有解析到可翻译的字幕行", comment: "")
        }
    }
}

/// 字幕时间轴，内部统一用毫秒，导出时恢复为 SRT/ASS 文本。
struct SubtitleTime: Comparable, Equatable {
    let milliseconds: Int

    init(milliseconds: Int) {
        self.milliseconds = max(0, milliseconds)
    }

    /// 解析 SRT 时间：`00:00:30,141` / `0:00:30.141` / `00:00:30.14`。
    init?(srt text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]) else {
            return nil
        }
        guard let secondsAndFraction = Self.splitSeconds(parts[2]),
              let seconds = Int(secondsAndFraction.seconds),
              let fraction = Int(secondsAndFraction.fraction),
              fraction >= 0 else {
            return nil
        }
        let fractionDigits = secondsAndFraction.fraction.count
        guard (1...3).contains(fractionDigits) else { return nil }
        let fractionMS = fraction * Self.powerOfTen(3 - fractionDigits)
        self.milliseconds = max(0, ((hours * 60 + minutes) * 60 + seconds) * 1000 + fractionMS)
    }

    /// 解析 ASS 时间：`0:00:12.47` / `0:00:12.470`。
    init?(ass text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 3,
              let hours = Int(parts[0]),
              let minutes = Int(parts[1]),
              minutes >= 0, minutes < 60,
              let secondsAndFraction = Self.splitSeconds(parts[2]),
              let seconds = Int(secondsAndFraction.seconds),
              seconds >= 0, seconds < 60,
              let fraction = Int(secondsAndFraction.fraction) else {
            return nil
        }
        let fractionDigits = secondsAndFraction.fraction.count
        guard (1...3).contains(fractionDigits) else { return nil }
        let fractionMS = fraction * Self.powerOfTen(3 - fractionDigits)
        self.milliseconds = max(0, ((hours * 60 + minutes) * 60 + seconds) * 1000 + fractionMS)
    }

    var srtText: String {
        let totalSeconds = milliseconds / 1000
        let ms = milliseconds % 1000
        let seconds = totalSeconds % 60
        let minutes = (totalSeconds / 60) % 60
        let hours = totalSeconds / 3600
        return String(format: "%02d:%02d:%02d,%03d", hours, minutes, seconds, ms)
    }

    var displayText: String {
        srtText
    }

    static func < (lhs: SubtitleTime, rhs: SubtitleTime) -> Bool {
        lhs.milliseconds < rhs.milliseconds
    }

    private static func splitSeconds(_ text: Substring) -> (seconds: Substring, fraction: Substring)? {
        guard let separator = text.firstIndex(where: { $0 == "," || $0 == "." }) else {
            return nil
        }
        let seconds = text[text.startIndex..<separator]
        let fraction = text[text.index(after: separator)..<text.endIndex]
        guard !seconds.isEmpty, !fraction.isEmpty else { return nil }
        return (seconds, fraction)
    }

    private static func powerOfTen(_ exponent: Int) -> Int {
        var result = 1
        for _ in 0..<exponent {
            result *= 10
        }
        return result
    }
}

/// 一条可翻译的字幕行。
struct SubtitleLine: Equatable {
    /// 文档内稳定 id（用原始解析顺序，不随翻译刷新变化）。
    let id: Int
    let start: SubtitleTime
    let end: SubtitleTime
    /// 可供翻译 / 展示的可见文本；ASS 已去掉覆盖标签，并保留 \N 对应的换行。
    let originalText: String
    var translatedText: String?
    /// ASS 中对应的原始行号；SRT 为 nil。
    let assSourceLine: Int?

    var displayTimeRange: String {
        "\(start.displayText) → \(end.displayText)"
    }
}

/// ASS Text 字段的结构化模板：标签与转义原样保留，只替换可见文本。
struct ASSTextTemplate: Equatable {
    enum Token: Equatable {
        case text(String)
        case tag(String)
        case escape(String)
    }

    let raw: String
    let tokens: [Token]

    /// 无法安全解析（例如 `{` 没有闭合）时返回 nil。
    static func parse(_ text: String) -> ASSTextTemplate? {
        var tokens: [Token] = []
        var current = ""
        var index = text.startIndex

        func flushText() {
            if !current.isEmpty {
                tokens.append(.text(current))
                current = ""
            }
        }

        while index < text.endIndex {
            let character = text[index]
            if character == "{" {
                guard let closing = text[index...].firstIndex(of: "}") else {
                    return nil
                }
                flushText()
                tokens.append(.tag(String(text[index...closing])))
                index = text.index(after: closing)
                continue
            }

            if character == "\\" {
                let nextIndex = text.index(after: index)
                if nextIndex < text.endIndex {
                    let next = text[nextIndex]
                    if next == "N" || next == "n" || next == "h" {
                        flushText()
                        tokens.append(.escape("\\\(next)"))
                        index = text.index(after: nextIndex)
                        continue
                    }
                }
                current.append(character)
                index = nextIndex
                continue
            }

            current.append(character)
            index = text.index(after: index)
        }

        flushText()
        return ASSTextTemplate(raw: text, tokens: tokens)
    }

    /// 用户实际看到的文本；标签去除，换行/空白转义还原。
    var visibleText: String {
        var result = ""
        for token in tokens {
            switch token {
            case .text(let text):
                result += text
            case .tag:
                break
            case .escape(let escape):
                switch escape {
                case "\\N", "\\n":
                    result += "\n"
                case "\\h":
                    result += " "
                default:
                    result += escape
                }
            }
        }
        return result
    }

    /// 把译文放回模板：
    /// - 按 \N/\n 分组，组数与译文行数一致时逐行替换；
    /// - 不一致时整个译文放进第一组，内部换行写成 \N；
    /// - 标签、转义与原始换行符（\N 或 \n）保持不变。
    func render(translatedText: String) -> String {
        let translationLines = translatedText
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .components(separatedBy: "\n")

        let groups = Self.makeGroups(tokens)
        let usesLineMapping = groups.count == translationLines.count && !groups.isEmpty

        var output = ""
        for (groupIndex, group) in groups.enumerated() {
            var inserted = false
            for token in group.tokens {
                switch token {
                case .tag(let tag):
                    output += tag
                case .escape(let escape):
                    output += escape
                case .text:
                    if !inserted {
                        if usesLineMapping {
                            output += translationLines[groupIndex]
                        } else if groupIndex == 0 {
                            output += translationLines.joined(separator: "\\N")
                        }
                        inserted = true
                    }
                }
            }

            // 整组只有标签（例如 `{\pos(...)}\N`）时，把译文补在换行前。
            if !inserted {
                if usesLineMapping {
                    output += translationLines[groupIndex]
                } else if groupIndex == 0 {
                    output += translationLines.joined(separator: "\\N")
                }
            }

            if let separator = group.separator {
                output += separator
            }
        }

        return output
    }

    // MARK: - Private

    private struct Group {
        var tokens: [Token] = []
        var separator: String?
    }

    private static func makeGroups(_ tokens: [Token]) -> [Group] {
        var groups: [Group] = [Group()]
        for token in tokens {
            if case .escape(let escape) = token, escape == "\\N" || escape == "\\n" {
                groups[groups.count - 1].separator = escape
                groups.append(Group())
            } else {
                groups[groups.count - 1].tokens.append(token)
            }
        }
        return groups
    }
}

/// 解析后的字幕文档。
struct SubtitleDocument {
    let sourceURL: URL
    let format: SubtitleFormat
    let lineEnding: String
    let endsWithNewline: Bool
    private(set) var lines: [SubtitleLine]
    /// ASS 中无法安全解析的 Dialogue 数量；这些行会被原样保留。
    let skippedLineCount: Int

    private let rawASSLines: [String]
    private let assDialogueInfo: [Int: ASSDialogueInfo]

    fileprivate struct ASSDialogueInfo {
        let prefix: String
        let template: ASSTextTemplate
    }

    fileprivate init(
        sourceURL: URL,
        format: SubtitleFormat,
        lineEnding: String,
        endsWithNewline: Bool,
        lines: [SubtitleLine],
        skippedLineCount: Int,
        rawASSLines: [String],
        assDialogueInfo: [Int: ASSDialogueInfo]
    ) {
        self.sourceURL = sourceURL
        self.format = format
        self.lineEnding = lineEnding
        self.endsWithNewline = endsWithNewline
        self.lines = lines
        self.skippedLineCount = skippedLineCount
        self.rawASSLines = rawASSLines
        self.assDialogueInfo = assDialogueInfo
    }

    var isASS: Bool { format.isASS }

    var translatedLineCount: Int {
        lines.filter { !($0.translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    /// 只取未翻译、非空、去重后的文本（保持首次出现顺序）。
    func pendingTexts() -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        for line in lines {
            let hasTranslation = !(line.translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard !hasTranslation else { continue }
            let text = line.originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            if seen.insert(text).inserted {
                result.append(text)
            }
        }
        return result
    }

    mutating func applyTranslations(_ translations: [String: String]) {
        guard !translations.isEmpty else { return }
        for index in lines.indices {
            guard (lines[index].translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                continue
            }
            let key = lines[index].originalText.trimmingCharacters(in: .whitespacesAndNewlines)
            if let translated = translations[key],
               !translated.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                lines[index].translatedText = translated.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
    }

    /// 生成导出文本。ASS 源可导出为 ASS（保留样式）或 SRT。
    func exportText(mode: SubtitleTranslationMode, format targetFormat: SubtitleFormat? = nil) -> String {
        let target = targetFormat ?? format
        if target.isASS {
            return exportASS(mode: mode)
        }
        return exportSRT(mode: mode)
    }

    // MARK: - SRT export

    private func exportSRT(mode: SubtitleTranslationMode) -> String {
        var blocks: [String] = []
        var number = 1
        for line in lines {
            let text = exportLineText(line, mode: mode)
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { continue }
            blocks.append("\(number)")
            blocks.append("\(line.start.srtText) --> \(line.end.srtText)")
            blocks.append(text)
            blocks.append("")
            number += 1
        }
        return blocks.joined(separator: lineEnding)
    }

    private func exportLineText(_ line: SubtitleLine, mode: SubtitleTranslationMode) -> String {
        let original = line.originalText
        let translated = (line.translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        switch mode {
        case .original:
            return original
        case .translated:
            return translated.isEmpty ? original : translated
        case .bilingual:
            return translated.isEmpty ? original : original + "\n" + translated
        }
    }

    // MARK: - ASS export

    private func exportASS(mode: SubtitleTranslationMode) -> String {
        guard !rawASSLines.isEmpty else { return "" }

        var outputLines = rawASSLines
        if mode != .original {
            for line in lines {
                guard let rawLineIndex = line.assSourceLine,
                      let info = assDialogueInfo[rawLineIndex],
                      rawLineIndex < outputLines.count else {
                    continue
                }

                let translated = (line.translatedText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
                let renderedText: String
                switch mode {
                case .translated:
                    renderedText = translated.isEmpty
                        ? info.template.raw
                        : info.template.render(translatedText: translated)
                case .bilingual:
                    if translated.isEmpty {
                        renderedText = info.template.raw
                    } else {
                        let translatedRendered = info.template.render(translatedText: translated)
                        renderedText = info.template.raw + "\\N" + translatedRendered
                    }
                case .original:
                    renderedText = info.template.raw
                }

                outputLines[rawLineIndex] = info.prefix + renderedText
            }
        }

        var result = outputLines.joined(separator: lineEnding)
        if endsWithNewline && !result.hasSuffix(lineEnding) {
            result += lineEnding
        }
        return result
    }
}

// MARK: - Loading

enum SubtitleDocumentLoader {
    static func load(url: URL) throws -> SubtitleDocument {
        guard let format = SubtitleFormat.from(url: url) else {
            throw SubtitleParseError.unsupportedFormat(url.pathExtension)
        }

        let data: Data
        do {
            data = try Data(contentsOf: url)
        } catch {
            throw SubtitleParseError.unreadable(error)
        }

        guard let content = decode(data), !content.isEmpty else {
            throw SubtitleParseError.empty
        }

        switch format {
        case .srt:
            return try parseSRT(content, url: url)
        case .ass, .ssa:
            return try parseASS(content, url: url, format: format)
        }
    }

    static func parseSRT(_ content: String, url: URL = URL(fileURLWithPath: "subtitle.srt")) throws -> SubtitleDocument {
        let lineEnding = detectLineEnding(content)
        let endsWithNewline = content.hasSuffix("\n")
        let normalized = normalizeNewlines(stripBOM(content))
        let rawLines = normalized.components(separatedBy: "\n")

        var blocks: [[String]] = []
        var current: [String] = []
        for line in rawLines {
            if line.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if !current.isEmpty {
                    blocks.append(current)
                    current = []
                }
            } else {
                current.append(line)
            }
        }
        if !current.isEmpty {
            blocks.append(current)
        }

        var lines: [SubtitleLine] = []
        var skipped = 0
        for block in blocks {
            var index = 0
            // 可选的序号行。
            if index < block.count,
               Int(block[index].trimmingCharacters(in: .whitespacesAndNewlines)) != nil {
                index += 1
            }
            guard index < block.count else {
                skipped += 1
                continue
            }

            let timing = block[index]
            guard let arrowRange = timing.range(of: "-->") else {
                skipped += 1
                continue
            }
            let startText = String(timing[timing.startIndex..<arrowRange.lowerBound])
            let endPart = String(timing[arrowRange.upperBound...])
            let endText = endPart.split(whereSeparator: { $0 == " " || $0 == "\t" }).first.map(String.init) ?? ""
            guard let start = SubtitleTime(srt: startText),
                  let end = SubtitleTime(srt: endText) else {
                skipped += 1
                continue
            }

            index += 1
            let text = block[index...].joined(separator: "\n")
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                skipped += 1
                continue
            }

            lines.append(SubtitleLine(
                id: lines.count,
                start: start,
                end: end,
                originalText: text,
                translatedText: nil,
                assSourceLine: nil
            ))
        }

        guard !lines.isEmpty else {
            throw SubtitleParseError.noSubtitles
        }

        return SubtitleDocument(
            sourceURL: url,
            format: .srt,
            lineEnding: lineEnding,
            endsWithNewline: endsWithNewline,
            lines: lines,
            skippedLineCount: skipped,
            rawASSLines: [],
            assDialogueInfo: [:]
        )
    }

    static func parseASS(
        _ content: String,
        url: URL = URL(fileURLWithPath: "subtitle.ass"),
        format: SubtitleFormat = .ass
    ) throws -> SubtitleDocument {
        let lineEnding = detectLineEnding(content)
        let endsWithNewline = content.hasSuffix("\n")
        let normalized = normalizeNewlines(stripBOM(content))
        let rawLines = normalized.components(separatedBy: "\n")

        var lines: [SubtitleLine] = []
        var dialogueInfo: [Int: SubtitleDocument.ASSDialogueInfo] = [:]
        var skipped = 0
        var inEvents = false
        var eventFormat: [String]?

        for (lineIndex, rawLine) in rawLines.enumerated() {
            let trimmed = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)

            if trimmed.hasPrefix("[") && trimmed.hasSuffix("]") {
                inEvents = trimmed.lowercased() == "[events]"
                if inEvents {
                    eventFormat = nil
                }
                continue
            }

            guard inEvents else { continue }

            if trimmed.lowercased().hasPrefix("format:") {
                let body = String(trimmed.dropFirst("format:".count))
                eventFormat = body.split(separator: ",", omittingEmptySubsequences: false)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                continue
            }

            guard trimmed.lowercased().hasPrefix("dialogue:") else { continue }

            guard let format = eventFormat,
                  let textIndex = format.firstIndex(of: "text"),
                  textIndex == format.count - 1,
                  let startIndex = format.firstIndex(of: "start"),
                  let endIndex = format.firstIndex(of: "end") else {
                skipped += 1
                continue
            }

            guard let parsed = parseASSDialogue(
                rawLine: rawLine,
                format: format,
                textIndex: textIndex,
                startIndex: startIndex,
                endIndex: endIndex
            ) else {
                skipped += 1
                continue
            }

            // 安全解析但没有可见文本（空行、纯绘图命令）：原样保留，不计入 skipped。
            guard !parsed.visibleText.isEmpty else { continue }

            lines.append(SubtitleLine(
                id: lines.count,
                start: parsed.start,
                end: parsed.end,
                originalText: parsed.visibleText,
                translatedText: nil,
                assSourceLine: lineIndex
            ))
            dialogueInfo[lineIndex] = parsed.info
        }

        guard !lines.isEmpty else {
            throw SubtitleParseError.noSubtitles
        }

        return SubtitleDocument(
            sourceURL: url,
            format: format,
            lineEnding: lineEnding,
            endsWithNewline: endsWithNewline,
            lines: lines,
            skippedLineCount: skipped,
            rawASSLines: rawLines,
            assDialogueInfo: dialogueInfo
        )
    }

    // MARK: - ASS helpers

    private struct ParsedASSDialogue {
        let start: SubtitleTime
        let end: SubtitleTime
        let visibleText: String
        let info: SubtitleDocument.ASSDialogueInfo
    }

    private static func parseASSDialogue(
        rawLine: String,
        format: [String],
        textIndex: Int,
        startIndex: Int,
        endIndex: Int
    ) -> ParsedASSDialogue? {
        guard let dialogueRange = rawLine.range(of: "Dialogue:", options: .caseInsensitive) else {
            return nil
        }

        let body = rawLine[dialogueRange.upperBound...]
        let fields = body.split(separator: ",", maxSplits: format.count - 1, omittingEmptySubsequences: false)
        guard fields.count == format.count else { return nil }

        let startText = fields[startIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        let endText = fields[endIndex].trimmingCharacters(in: .whitespacesAndNewlines)
        guard let start = SubtitleTime(ass: startText),
              let end = SubtitleTime(ass: endText) else {
            return nil
        }

        guard let textStart = textFieldStartIndex(in: body, textIndex: textIndex) else {
            return nil
        }

        let rawText = String(body[textStart...])
        guard let template = ASSTextTemplate.parse(rawText) else {
            return nil
        }

        let visible = template.visibleText.trimmingCharacters(in: .whitespacesAndNewlines)
        let prefix = String(rawLine[rawLine.startIndex..<rawLine.index(dialogueRange.upperBound, offsetBy: body.distance(from: body.startIndex, to: textStart))])
        return ParsedASSDialogue(
            start: start,
            end: end,
            visibleText: visible,
            info: SubtitleDocument.ASSDialogueInfo(prefix: prefix, template: template)
        )
    }

    /// 返回 Text 字段在 body（`Dialogue:` 之后）中的起点：第 textIndex 个逗号之后。
    private static func textFieldStartIndex(
        in body: Substring,
        textIndex: Int
    ) -> Substring.Index? {
        guard textIndex > 0 else { return body.startIndex }
        var commaCount = 0
        var index = body.startIndex
        while index < body.endIndex {
            if body[index] == "," {
                commaCount += 1
                if commaCount == textIndex {
                    let next = body.index(after: index)
                    return next <= body.endIndex ? next : nil
                }
            }
            index = body.index(after: index)
        }
        return nil
    }

    // MARK: - Text helpers

    private static func stripBOM(_ text: String) -> String {
        text.hasPrefix("\u{FEFF}") ? String(text.dropFirst()) : text
    }

    private static func normalizeNewlines(_ text: String) -> String {
        text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    private static func detectLineEnding(_ text: String) -> String {
        if text.contains("\r\n") {
            return "\r\n"
        }
        if text.contains("\r") {
            return "\r"
        }
        return "\n"
    }

    private static func decode(_ data: Data) -> String? {
        if let text = String(data: data, encoding: .utf8) {
            return text
        }
        if let text = String(data: data, encoding: .utf16LittleEndian) {
            return text
        }
        if let text = String(data: data, encoding: .utf16BigEndian) {
            return text
        }
        // 中文老字幕常见 GB18030；不引入第三方库，用 CoreFoundation 编码。
        let cfEncoding = CFStringConvertEncodingToNSStringEncoding(
            CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
        )
        return String(data: data, encoding: String.Encoding(rawValue: cfEncoding))
    }
}
