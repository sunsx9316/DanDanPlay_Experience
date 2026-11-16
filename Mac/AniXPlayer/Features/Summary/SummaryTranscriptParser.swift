//
//  SummaryTranscriptParser.swift
//  AniXPlayer
//
//  macOS only：把 SRT / ASS / SSA 字幕解析为 AI 视频总结所需的转录文本。
//

import Foundation
import CoreFoundation

enum SubtitleTranscriptError: LocalizedError {
    case unsupportedFormat(String)
    case unreadable

    var errorDescription: String? {
        switch self {
        case .unsupportedFormat(let ext):
            return String(format: NSLocalizedString("不支持的字幕格式：%@", comment: ""), ext)
        case .unreadable:
            return NSLocalizedString("字幕文件无法读取或编码不受支持", comment: "")
        }
    }
}

enum SubtitleTranscriptParser {
    static let supportedExtensions = ["srt", "ass", "ssa"]

    /// 读取字幕文件并解析为转录文本。空结果由调用方给出提示。
    static func transcriptions(from url: URL) throws -> [SummaryTranscription] {
        let ext = url.pathExtension.lowercased()
        guard supportedExtensions.contains(ext) else {
            throw SubtitleTranscriptError.unsupportedFormat(ext.isEmpty ? url.lastPathComponent : ext)
        }

        let text = try loadText(at: url)
        return transcriptions(fromText: text, fileExtension: ext)
    }

    static func transcriptions(fromText text: String, fileExtension ext: String) -> [SummaryTranscription] {
        switch ext.lowercased() {
        case "srt":
            return parseSRT(text)
        case "ass", "ssa":
            return parseASS(text)
        default:
            return []
        }
    }

    // MARK: - SRT

    static func parseSRT(_ text: String) -> [SummaryTranscription] {
        let lines = normalizeLineEndings(text).components(separatedBy: "\n")
        var result: [SummaryTranscription] = []
        var index = 0

        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            guard let start = parseSRTTimeLine(line) else {
                index += 1
                continue
            }

            index += 1
            var contentLines: [String] = []
            while index < lines.count {
                let contentLine = lines[index]
                if contentLine.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    break
                }
                contentLines.append(contentLine)
                index += 1
            }

            let content = cleanText(contentLines.joined(separator: " "))
            if !content.isEmpty {
                result.append(SummaryTranscription(start: SummaryTranscriptTime.format(start), content: content))
            }
        }

        return result
    }

    /// 解析 `00:00:30,141 --> 00:00:33,074` 左侧的开始时间。
    private static func parseSRTTimeLine(_ line: String) -> TimeInterval? {
        guard let arrowRange = line.range(of: "-->") else { return nil }
        let rawStart = line[..<arrowRange.lowerBound].trimmingCharacters(in: .whitespaces)
        return parseTimestamp(rawStart)
    }

    // MARK: - ASS / SSA

    /// 解析 `Dialogue: 0,0:00:12.47,0:00:15.18,Subtitle,,0,0,0,,文本`。
    static func parseASS(_ text: String) -> [SummaryTranscription] {
        let lines = normalizeLineEndings(text).components(separatedBy: "\n")
        var result: [SummaryTranscription] = []

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard trimmed.lowercased().hasPrefix("dialogue:") else { continue }

            let payload = trimmed.dropFirst("Dialogue:".count)
            let fields = payload.split(separator: ",", maxSplits: 9, omittingEmptySubsequences: false)
            guard fields.count >= 10 else { continue }
            guard let start = parseTimestamp(fields[1].trimmingCharacters(in: .whitespaces)) else { continue }

            let rawContent = String(fields[9])
            /// 绘制指令（\p1 等）不是可读文本，直接跳过。
            if rawContent.trimmingCharacters(in: .whitespaces).range(of: "^[mnlbspc]\\s", options: .regularExpression) != nil {
                continue
            }

            let content = cleanText(rawContent)
            if !content.isEmpty {
                result.append(SummaryTranscription(start: SummaryTranscriptTime.format(start), content: content))
            }
        }

        return result
    }

    // MARK: - Helpers

    private static func normalizeLineEndings(_ text: String) -> String {
        var normalized = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        if normalized.hasPrefix("\u{FEFF}") {
            normalized.removeFirst()
        }
        return normalized
    }

    /// 支持 `hh:mm:ss,mmm`、`hh:mm:ss.mmm`、`mm:ss,mmm`、`m:ss.mmm` 等形式。
    private static func parseTimestamp(_ raw: String) -> TimeInterval? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: ",", with: ".")
        guard !value.isEmpty else { return nil }

        let parts = value.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        var hours: Double = 0
        var minutes: Double
        let secondsPart: Substring

        if parts.count == 3 {
            guard let h = Double(parts[0]),
                  let m = Double(parts[1]) else { return nil }
            hours = h
            minutes = m
            secondsPart = parts[2]
        } else {
            guard let m = Double(parts[0]) else { return nil }
            minutes = m
            secondsPart = parts[1]
        }

        guard let seconds = Double(secondsPart), seconds.isFinite,
              hours.isFinite, minutes.isFinite else { return nil }

        return max(0, hours * 3600 + minutes * 60 + seconds)
    }

    private static let overrideTagRegex = try? NSRegularExpression(pattern: "\\{[^}]*\\}")
    private static let htmlTagRegex = try? NSRegularExpression(pattern: "<[^>]*>")

    private static func cleanText(_ raw: String) -> String {
        var text = raw
            .replacingOccurrences(of: "\\N", with: " ")
            .replacingOccurrences(of: "\\n", with: " ")
            .replacingOccurrences(of: "\\h", with: " ")

        text = replaceMatches(in: text, regex: overrideTagRegex)
        text = replaceMatches(in: text, regex: htmlTagRegex)
        text = decodeBasicHTMLEntities(text)

        return text
            .components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func replaceMatches(in text: String, regex: NSRegularExpression?) -> String {
        guard let regex = regex else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.stringByReplacingMatches(in: text, options: [], range: range, withTemplate: "")
    }

    private static func decodeBasicHTMLEntities(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&amp;", with: "&")
    }

    // MARK: - Decoding

    private static func loadText(at url: URL) throws -> String {
        let data = try Data(contentsOf: url)

        if data.starts(with: [0xFF, 0xFE]) || data.starts(with: [0xFE, 0xFF]) {
            if let text = String(data: data, encoding: .utf16) {
                return text
            }
        }

        if let text = String(data: data, encoding: .utf8) {
            return text
        }

        if let text = String(data: data, encoding: .utf16) {
            return text
        }

        let gb18030 = String.Encoding(
            rawValue: CFStringConvertEncodingToNSStringEncoding(
                CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            )
        )
        if let text = String(data: data, encoding: gb18030) {
            return text
        }

        if let text = String(data: data, encoding: .isoLatin1) {
            return text
        }

        throw SubtitleTranscriptError.unreadable
    }
}
