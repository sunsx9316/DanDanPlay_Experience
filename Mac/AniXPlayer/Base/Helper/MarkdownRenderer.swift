//
//  MarkdownRenderer.swift
//  AniXPlayer
//
//  macOS only：轻量 Markdown -> NSAttributedString 渲染器。
//  会员权益说明与 AI 视频总结共用；不依赖第三方库，解析失败时回退纯文本。
//
//  支持：H1–H3、粗体、斜体、行内代码、无序/有序列表、引用、链接、段落间距。
//

import AppKit

enum MarkdownRenderer {

    // MARK: - Style

    struct Style {
        var bodyFontSize: CGFloat = 13
        var bodyColor: NSColor = .labelColor
        var secondaryColor: NSColor = .secondaryLabelColor
        var linkColor: NSColor = .linkColor
        var codeColor: NSColor = .labelColor
        var codeBackgroundColor: NSColor = .quaternaryLabelColor
        var linkUnderline: Bool = true
        var lineSpacing: CGFloat = 2
        var paragraphSpacing: CGFloat = 8
        var listParagraphSpacing: CGFloat = 3
        var quoteIndent: CGFloat = 8
        var listIndent: CGFloat = 18

        init() {}
    }

    struct Options {
        var style: Style
        /// 会员中心窗口已经有「弹弹play 会员」标题，跳过服务端文案开头重复的 H1。
        var skipsLeadingH1: Bool

        init(style: Style = Style(), skipsLeadingH1: Bool = false) {
            self.style = style
            self.skipsLeadingH1 = skipsLeadingH1
        }
    }

    // MARK: - Public

    /// 解析失败或结果为空时返回纯文本，保证调用方永远拿到可显示内容。
    static func render(_ markdown: String, options: Options = Options()) -> NSAttributedString {
        let normalized = markdown
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\u{FEFF}", with: "")

        guard !normalized.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return NSAttributedString()
        }

        let rendered = renderBlocks(normalized, options: options)
        guard rendered.length > 0 else {
            return plainText(normalized, style: options.style)
        }
        return rendered
    }

    /// 纯文本回退（解析失败、占位提示）。
    static func plainText(
        _ text: String,
        style: Style = Style(),
        color: NSColor? = nil
    ) -> NSAttributedString {
        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.paragraphSpacing)
        return NSAttributedString(
            string: text,
            attributes: [
                .font: NSFont.systemFont(ofSize: style.bodyFontSize),
                .foregroundColor: color ?? style.bodyColor,
                .paragraphStyle: paragraph
            ]
        )
    }

    /// 解析 Markdown 链接目标里的时间戳：`00:12`、`01:02:03`、`t=72`。
    /// 返回 nil 表示不是时间戳（正常 URL 由 NSWorkspace 打开）。
    static func timestampSeconds(from raw: String) -> TimeInterval? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !trimmed.contains("://") else { return nil }

        if let range = trimmed.range(of: "t=") {
            let value = trimmed[range.upperBound...]
            if let seconds = TimeInterval(value), seconds >= 0 {
                return seconds
            }
        }

        let parts = trimmed.split(separator: ":", omittingEmptySubsequences: false)
        guard parts.count == 2 || parts.count == 3 else { return nil }

        let values = parts.compactMap { TimeInterval($0) }
        guard values.count == parts.count, values.allSatisfy({ $0 >= 0 }) else { return nil }

        if values.count == 2 {
            guard values[1] < 60 else { return nil }
            return values[0] * 60 + values[1]
        }
        guard values[1] < 60, values[2] < 60 else { return nil }
        return values[0] * 3600 + values[1] * 60 + values[2]
    }

    static func timestampURL(seconds: TimeInterval) -> URL? {
        let total = max(0, Int(seconds.rounded(.down)))
        return URL(string: "anix-timestamp://seek?t=\(total)")
    }

    // MARK: - Blocks

    private struct HeadingBlock {
        let level: Int
        let text: String
    }

    private struct ListBlock {
        let marker: String
        let content: String
        let level: Int
    }

    private static func renderBlocks(_ markdown: String, options: Options) -> NSAttributedString {
        let style = options.style
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")
        var index = 0
        var hasSeenContent = false

        while index < lines.count {
            let rawLine = lines[index]
            let trimmed = rawLine.trimmingCharacters(in: .whitespaces)

            if trimmed.isEmpty {
                index += 1
                continue
            }

            // 围栏代码块：整体按等宽字体显示，不解析内部 Markdown。
            if let fence = codeFence(from: trimmed) {
                hasSeenContent = true
                index += 1
                var codeLines: [String] = []
                while index < lines.count {
                    let candidate = lines[index].trimmingCharacters(in: .whitespaces)
                    if candidate.hasPrefix(fence) {
                        index += 1
                        break
                    }
                    codeLines.append(lines[index])
                    index += 1
                }
                appendCodeBlock(codeLines.joined(separator: "\n"), style: style, to: result)
                continue
            }

            if let heading = headingBlock(from: trimmed) {
                if heading.level == 1, options.skipsLeadingH1, !hasSeenContent {
                    hasSeenContent = true
                    index += 1
                    continue
                }
                hasSeenContent = true
                appendHeading(heading, style: style, to: result)
                index += 1
                continue
            }

            hasSeenContent = true

            if isHorizontalRule(trimmed) {
                appendHorizontalRule(style: style, to: result)
                index += 1
                continue
            }

            if let quote = blockquote(from: rawLine) {
                appendBlockquote(quote.text, level: quote.level, style: style, to: result)
                index += 1
                continue
            }

            if let item = listItem(from: rawLine) {
                appendListItem(item, style: style, to: result)
                index += 1
                continue
            }

            appendParagraph(trimmed, style: style, to: result)
            index += 1
        }

        trimTrailingNewline(result)
        return result
    }

    private static func codeFence(from trimmed: String) -> String? {
        if trimmed.hasPrefix("```") { return "```" }
        if trimmed.hasPrefix("~~~") { return "~~~" }
        return nil
    }

    private static func headingBlock(from trimmed: String) -> HeadingBlock? {
        var level = 0
        var cursor = trimmed.startIndex
        while cursor < trimmed.endIndex, trimmed[cursor] == "#" {
            level += 1
            cursor = trimmed.index(after: cursor)
        }

        guard level > 0, level <= 6 else { return nil }
        if cursor < trimmed.endIndex, !trimmed[cursor].isWhitespace {
            return nil
        }

        var text = String(trimmed[cursor...]).trimmingCharacters(in: .whitespaces)
        while text.hasSuffix("#") {
            text.removeLast()
        }
        text = text.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return nil }

        return HeadingBlock(level: min(level, 3), text: text)
    }

    private static func blockquote(from rawLine: String) -> (text: String, level: Int)? {
        var current = rawLine.trimmingCharacters(in: .whitespaces)
        guard current.hasPrefix(">") else { return nil }

        var level = 0
        while current.hasPrefix(">") {
            level += 1
            current.removeFirst()
            if current.hasPrefix(" ") {
                current.removeFirst()
            }
            current = current.trimmingCharacters(in: .whitespaces)
        }

        guard !current.isEmpty else { return nil }
        return (current, min(level, 3))
    }

    private static func listItem(from rawLine: String) -> ListBlock? {
        let (indentWidth, trimmed) = leadingIndent(rawLine)
        guard !trimmed.isEmpty else { return nil }
        let level = min(indentWidth / 2, 4)

        for marker in ["- ", "* ", "+ "] where trimmed.hasPrefix(marker) {
            let content = String(trimmed.dropFirst(marker.count))
                .trimmingCharacters(in: .whitespaces)
            guard !content.isEmpty else { return nil }
            return ListBlock(marker: "•", content: content, level: level)
        }

        var cursor = trimmed.startIndex
        var digits = ""
        while cursor < trimmed.endIndex, trimmed[cursor].isNumber {
            digits.append(trimmed[cursor])
            cursor = trimmed.index(after: cursor)
        }
        guard !digits.isEmpty, cursor < trimmed.endIndex else { return nil }
        let delimiter = trimmed[cursor]
        guard delimiter == "." || delimiter == ")" else { return nil }

        let afterDelimiter = trimmed.index(after: cursor)
        guard afterDelimiter < trimmed.endIndex, trimmed[afterDelimiter].isWhitespace else { return nil }
        let content = String(trimmed[afterDelimiter...])
            .trimmingCharacters(in: .whitespaces)
        guard !content.isEmpty else { return nil }

        return ListBlock(marker: digits + String(delimiter), content: content, level: level)
    }

    private static func leadingIndent(_ line: String) -> (width: Int, trimmed: String) {
        var width = 0
        var cursor = line.startIndex
        while cursor < line.endIndex {
            let character = line[cursor]
            if character == " " {
                width += 1
            } else if character == "\t" {
                width += 4
            } else {
                break
            }
            cursor = line.index(after: cursor)
        }
        return (width, String(line[cursor...]).trimmingCharacters(in: .whitespaces))
    }

    private static func isHorizontalRule(_ trimmed: String) -> Bool {
        guard trimmed.count >= 3 else { return false }
        let markers: [Character] = ["-", "*", "_"]
        guard let first = trimmed.first, markers.contains(first) else { return false }
        return trimmed.allSatisfy { $0 == first || $0.isWhitespace }
    }

    // MARK: - Block rendering

    private static func appendParagraph(
        _ text: String,
        style: Style,
        to result: NSMutableAttributedString
    ) {
        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.paragraphSpacing)
        let font = NSFont.systemFont(ofSize: style.bodyFontSize)
        let content = inline(
            text,
            font: font,
            color: style.bodyColor,
            paragraph: paragraph,
            style: style
        )
        appendBlock(content, to: result)
    }

    private static func appendHeading(
        _ heading: HeadingBlock,
        style: Style,
        to result: NSMutableAttributedString
    ) {
        let sizes: [CGFloat] = [21, 17, 14.5]
        let weights: [NSFont.Weight] = [.bold, .semibold, .semibold]
        let index = max(0, min(heading.level - 1, sizes.count - 1))

        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.paragraphSpacing)
        paragraph.paragraphSpacingBefore = heading.level == 1 ? 12 : 9

        let font = NSFont.systemFont(ofSize: sizes[index], weight: weights[index])
        let content = inline(
            heading.text,
            font: font,
            color: style.bodyColor,
            paragraph: paragraph,
            style: style
        )
        appendBlock(content, to: result)
    }

    private static func appendListItem(
        _ item: ListBlock,
        style: Style,
        to result: NSMutableAttributedString
    ) {
        let indent = CGFloat(item.level) * style.listIndent
        let markerWidth = item.marker == "•"
            ? CGFloat(16)
            : max(18, CGFloat(item.marker.count) * 8 + 4)

        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.listParagraphSpacing)
        paragraph.firstLineHeadIndent = indent
        paragraph.headIndent = indent + markerWidth
        paragraph.tabStops = [
            NSTextTab(textAlignment: .left, location: indent + markerWidth, options: [:])
        ]

        let body = inline(
            item.content,
            font: NSFont.systemFont(ofSize: style.bodyFontSize),
            color: style.bodyColor,
            paragraph: paragraph,
            style: style
        )

        let marked = NSMutableAttributedString(
            string: item.marker + "\t",
            attributes: [
                .font: NSFont.systemFont(ofSize: style.bodyFontSize),
                .foregroundColor: style.bodyColor,
                .paragraphStyle: paragraph
            ]
        )
        marked.append(body)
        appendBlock(marked, to: result)
    }

    private static func appendBlockquote(
        _ text: String,
        level: Int,
        style: Style,
        to result: NSMutableAttributedString
    ) {
        let indent = style.quoteIndent + CGFloat(max(0, level - 1)) * 12
        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.paragraphSpacing)
        paragraph.firstLineHeadIndent = indent
        paragraph.headIndent = indent

        let body = inline(
            text,
            font: NSFont.systemFont(ofSize: style.bodyFontSize),
            color: style.secondaryColor,
            paragraph: paragraph,
            style: style
        )

        let quoted = NSMutableAttributedString(
            string: "│ ",
            attributes: [
                .font: NSFont.systemFont(ofSize: style.bodyFontSize),
                .foregroundColor: style.secondaryColor,
                .paragraphStyle: paragraph
            ]
        )
        quoted.append(body)
        appendBlock(quoted, to: result)
    }

    private static func appendCodeBlock(
        _ code: String,
        style: Style,
        to result: NSMutableAttributedString
    ) {
        guard !code.isEmpty else { return }

        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.paragraphSpacing)
        paragraph.lineSpacing = 1
        paragraph.firstLineHeadIndent = 8
        paragraph.headIndent = 8

        let font = NSFont.monospacedSystemFont(
            ofSize: max(10, style.bodyFontSize - 1),
            weight: .regular
        )
        let content = NSMutableAttributedString(
            string: code,
            attributes: [
                .font: font,
                .foregroundColor: style.codeColor,
                .backgroundColor: style.codeBackgroundColor,
                .paragraphStyle: paragraph
            ]
        )
        appendBlock(content, to: result)
    }

    private static func appendHorizontalRule(
        style: Style,
        to result: NSMutableAttributedString
    ) {
        let paragraph = makeParagraphStyle(style: style, spacingAfter: style.paragraphSpacing)
        paragraph.paragraphSpacingBefore = 6
        let content = NSAttributedString(
            string: String(repeating: "─", count: 24),
            attributes: [
                .font: NSFont.systemFont(ofSize: style.bodyFontSize),
                .foregroundColor: style.secondaryColor,
                .paragraphStyle: paragraph
            ]
        )
        appendBlock(content, to: result)
    }

    private static func appendBlock(
        _ content: NSAttributedString,
        to result: NSMutableAttributedString
    ) {
        guard content.length > 0 else { return }

        let block = NSMutableAttributedString(attributedString: content)
        // 换行也带上当前段落的属性，避免末尾产生一个没有段落样式的空段。
        var lastAttributes = block.attributes(at: block.length - 1, effectiveRange: nil)
        // 行尾的链接/下划线/代码底色不应延伸到换行符。
        lastAttributes.removeValue(forKey: .link)
        lastAttributes.removeValue(forKey: .underlineStyle)
        lastAttributes.removeValue(forKey: .backgroundColor)
        block.append(NSAttributedString(string: "\n", attributes: lastAttributes))
        result.append(block)
    }

    private static func trimTrailingNewline(_ result: NSMutableAttributedString) {
        guard result.length > 0, result.string.hasSuffix("\n") else { return }
        result.deleteCharacters(in: NSRange(location: result.length - 1, length: 1))
    }

    private static func makeParagraphStyle(
        style: Style,
        spacingAfter: CGFloat
    ) -> NSMutableParagraphStyle {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = style.lineSpacing
        paragraph.paragraphSpacing = spacingAfter
        paragraph.lineBreakMode = .byWordWrapping
        return paragraph
    }

    // MARK: - Inline rendering

    private struct ParsedLink {
        let label: String
        let destination: String
        let url: URL?
        let end: String.Index
    }

    private static func inline(
        _ text: String,
        font: NSFont,
        color: NSColor,
        paragraph: NSParagraphStyle,
        style: Style,
        bold: Bool = false,
        italic: Bool = false,
        allowsLinks: Bool = true,
        depth: Int = 0
    ) -> NSAttributedString {
        let output = NSMutableAttributedString()
        guard depth < 8 else {
            output.append(NSAttributedString(
                string: text,
                attributes: baseAttributes(
                    font: font,
                    bold: bold,
                    italic: italic,
                    color: color,
                    paragraph: paragraph
                )
            ))
            return output
        }

        var buffer = ""
        var index = text.startIndex

        func flushBuffer() {
            guard !buffer.isEmpty else { return }
            output.append(NSAttributedString(
                string: buffer,
                attributes: baseAttributes(
                    font: font,
                    bold: bold,
                    italic: italic,
                    color: color,
                    paragraph: paragraph
                )
            ))
            buffer = ""
        }

        while index < text.endIndex {
            let character = text[index]

            // 转义字符：直接输出下一个字符。
            if character == "\\" {
                let next = text.index(after: index)
                if next < text.endIndex {
                    buffer.append(text[next])
                    index = text.index(after: next)
                    continue
                }
            }

            // 行内代码优先，内部不再解析粗体/斜体/链接。
            if character == "`" {
                let afterOpen = text.index(after: index)
                if let closing = text[afterOpen...].firstIndex(of: "`") {
                    flushBuffer()
                    let code = String(text[afterOpen..<closing])
                    let codeFont = inlineCodeFont(base: font)
                    output.append(NSAttributedString(
                        string: code,
                        attributes: [
                            .font: codeFont,
                            .foregroundColor: style.codeColor,
                            .backgroundColor: style.codeBackgroundColor,
                            .paragraphStyle: paragraph
                        ]
                    ))
                    index = text.index(after: closing)
                    continue
                }
            }

            // 链接：[label](destination)
            if character == "[", allowsLinks,
               let link = parsedLink(in: text, from: index) {
                flushBuffer()
                let label = link.label.isEmpty ? link.destination : link.label
                let inner = inline(
                    label,
                    font: font,
                    color: color,
                    paragraph: paragraph,
                    style: style,
                    bold: bold,
                    italic: italic,
                    allowsLinks: false,
                    depth: depth + 1
                )
                let linked = NSMutableAttributedString(attributedString: inner)
                if let url = link.url {
                    var attributes: [NSAttributedString.Key: Any] = [
                        .link: url,
                        .foregroundColor: style.linkColor
                    ]
                    if style.linkUnderline {
                        attributes[.underlineStyle] = NSUnderlineStyle.single.rawValue
                    }
                    linked.addAttributes(attributes, range: NSRange(location: 0, length: linked.length))
                }
                output.append(linked)
                index = link.end
                continue
            }

            // 粗体/斜体。
            if character == "*" || character == "_" {
                if let emphasis = parsedEmphasis(in: text, from: index) {
                    flushBuffer()
                    let inner = inline(
                        emphasis.text,
                        font: font,
                        color: color,
                        paragraph: paragraph,
                        style: style,
                        bold: bold || emphasis.bold,
                        italic: italic || emphasis.italic,
                        allowsLinks: allowsLinks,
                        depth: depth + 1
                    )
                    output.append(inner)
                    index = emphasis.end
                    continue
                }
            }

            buffer.append(character)
            index = text.index(after: index)
        }

        flushBuffer()
        return output
    }

    private struct EmphasisMatch {
        let text: String
        let bold: Bool
        let italic: Bool
        let end: String.Index
    }

    private static func parsedEmphasis(in text: String, from start: String.Index) -> EmphasisMatch? {
        let marker = text[start]

        // ***text*** / ___text___：粗斜体。
        let tripleStart = text.index(start, offsetBy: 3, limitedBy: text.endIndex)
        if let tripleStart = tripleStart,
           hasMarker(String(repeating: String(marker), count: 3), at: start, in: text),
           let close = closingMarker(String(repeating: String(marker), count: 3), in: text, from: tripleStart) {
            let innerStart = text.index(start, offsetBy: 3)
            let inner = String(text[innerStart..<close])
            guard !inner.isEmpty else { return nil }
            return EmphasisMatch(
                text: inner,
                bold: true,
                italic: true,
                end: text.index(close, offsetBy: 3)
            )
        }

        // **text** / __text__：粗体。
        let doubleStart = text.index(start, offsetBy: 2, limitedBy: text.endIndex)
        if let doubleStart = doubleStart,
           doubleStart < text.endIndex,
           hasMarker(String(repeating: String(marker), count: 2), at: start, in: text),
           let close = closingMarker(String(repeating: String(marker), count: 2), in: text, from: doubleStart) {
            let innerStart = text.index(start, offsetBy: 2)
            let inner = String(text[innerStart..<close])
            guard !inner.isEmpty else { return nil }
            return EmphasisMatch(
                text: inner,
                bold: true,
                italic: false,
                end: text.index(close, offsetBy: 2)
            )
        }

        // *text* / _text_：斜体。单个标记不能紧跟同类标记，避免吃掉粗体开头。
        let afterSingle = text.index(after: start)
        if afterSingle < text.endIndex, text[afterSingle] != marker,
           let close = closingMarker(String(marker), in: text, from: afterSingle) {
            let inner = String(text[afterSingle..<close])
            guard !inner.isEmpty else { return nil }
            return EmphasisMatch(
                text: inner,
                bold: false,
                italic: true,
                end: text.index(after: close)
            )
        }

        return nil
    }

    private static func hasMarker(_ marker: String, at index: String.Index, in text: String) -> Bool {
        guard let end = text.index(index, offsetBy: marker.count, limitedBy: text.endIndex) else {
            return false
        }
        return text[index..<end] == marker
    }

    private static func closingMarker(
        _ marker: String,
        in text: String,
        from start: String.Index
    ) -> String.Index? {
        guard start <= text.endIndex else { return nil }
        var searchStart = start
        while searchStart < text.endIndex,
              let range = text.range(of: marker, range: searchStart..<text.endIndex) {
            if range.lowerBound > text.startIndex {
                let previous = text.index(before: range.lowerBound)
                if text[previous] == "\\" {
                    searchStart = range.upperBound
                    continue
                }
            }
            return range.lowerBound
        }
        return nil
    }

    private static func parsedLink(in text: String, from openBracket: String.Index) -> ParsedLink? {
        let labelStart = text.index(after: openBracket)
        var cursor = labelStart
        var bracketDepth = 0
        var labelEnd: String.Index?

        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "\\" {
                cursor = text.index(cursor, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
                continue
            }
            if character == "[" {
                bracketDepth += 1
            } else if character == "]" {
                if bracketDepth == 0 {
                    labelEnd = cursor
                    break
                }
                bracketDepth -= 1
            }
            cursor = text.index(after: cursor)
        }

        guard let labelEnd = labelEnd else { return nil }
        let parenthesis = text.index(after: labelEnd)
        guard parenthesis < text.endIndex, text[parenthesis] == "(" else { return nil }

        let destinationStart = text.index(after: parenthesis)
        guard let destinationEnd = closingParenthesis(in: text, from: destinationStart) else {
            return nil
        }

        let label = String(text[labelStart..<labelEnd])
        var destination = String(text[destinationStart..<destinationEnd])
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // [x](url "title") / [x](url 'title')
        if let whitespace = destination.firstIndex(where: { $0.isWhitespace }) {
            let suffix = destination[whitespace...].trimmingCharacters(in: .whitespaces)
            if suffix.hasPrefix("\"") || suffix.hasPrefix("'") || suffix.hasPrefix("(") {
                destination = String(destination[..<whitespace])
            }
        }

        if destination.hasPrefix("<"), destination.hasSuffix(">"), destination.count >= 2 {
            destination = String(destination.dropFirst().dropLast())
        }

        return ParsedLink(
            label: label,
            destination: destination,
            url: makeURL(destination),
            end: text.index(after: destinationEnd)
        )
    }

    private static func closingParenthesis(
        in text: String,
        from start: String.Index
    ) -> String.Index? {
        var cursor = start
        var depth = 0
        while cursor < text.endIndex {
            let character = text[cursor]
            if character == "\\" {
                cursor = text.index(cursor, offsetBy: 2, limitedBy: text.endIndex) ?? text.endIndex
                continue
            }
            if character == "(" {
                depth += 1
            } else if character == ")" {
                if depth == 0 {
                    return cursor
                }
                depth -= 1
            }
            cursor = text.index(after: cursor)
        }
        return nil
    }

    private static func makeURL(_ raw: String) -> URL? {
        guard !raw.isEmpty else { return nil }
        if let url = URL(string: raw) {
            return url
        }
        if let seconds = timestampSeconds(from: raw) {
            return timestampURL(seconds: seconds)
        }
        let escaped = raw.replacingOccurrences(of: " ", with: "%20")
        return URL(string: escaped)
    }

    private static func baseAttributes(
        font: NSFont,
        bold: Bool,
        italic: Bool,
        color: NSColor,
        paragraph: NSParagraphStyle
    ) -> [NSAttributedString.Key: Any] {
        var resolvedFont = font
        if bold || italic {
            var traits = font.fontDescriptor.symbolicTraits
            if bold {
                traits.insert(.bold)
            }
            if italic {
                traits.insert(.italic)
            }
            let descriptor = font.fontDescriptor.withSymbolicTraits(traits)
            resolvedFont = NSFont(descriptor: descriptor, size: font.pointSize) ?? font
        }

        return [
            .font: resolvedFont,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    }

    private static func inlineCodeFont(base: NSFont) -> NSFont {
        NSFont.monospacedSystemFont(
            ofSize: max(10, base.pointSize - 0.5),
            weight: .regular
        )
    }
}
