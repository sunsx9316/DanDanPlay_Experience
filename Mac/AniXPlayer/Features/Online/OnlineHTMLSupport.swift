//
//  OnlineHTMLSupport.swift
//  AniXPlayer
//
//  macOS：在线源规则使用的 HTML/XPath 工具。
//
//  Animeko 规则是 CSS 选择器，Kazumi 规则是 XPath。
//  macOS 没有内置 CSS 选择器，因此这里实现一个覆盖现有规则子集的
//  CSS → XPath 转换器；Kazumi 直接使用 Foundation 的 XPath。
//

import Foundation

// MARK: - HTML document

final class OnlineHTMLDocument {

    let document: XMLDocument
    let baseURL: URL?

    init(html: String, baseURL: URL?) throws {
        guard !html.isEmpty else {
            throw OnlinePlaybackError.emptyResponse
        }

        // 页面在进入这里之前已按响应头/meta 解码成 Swift String。
        // 直接传 xmlString 可以让 libtidy 按 UTF-8 处理；若先转 Data，
        // tidy 可能按 Latin-1 解析，导致中文标题乱码。
        //
        // Tidy HTML 会保留 HTML4 的树结构和未闭合的 <li> 等，但会丢掉
        // <section>/<article> 等 HTML5 标签；Tidy XML 能保留这些标签，
        // 但对未闭合标签的推断不如 Tidy HTML。优先 Tidy HTML，只有它确实
        // 丢掉了规则可能用到的 HTML5 标签时才改用 Tidy XML。
        let tidyHTML = try? XMLDocument(
            xmlString: html,
            options: [.documentTidyHTML, .nodePreserveAll]
        )
        let tidyXML = try? XMLDocument(
            xmlString: html,
            options: [.documentTidyXML, .nodePreserveAll]
        )

        if let tidyHTML, !Self.dropsHTML5Tags(html: html, document: tidyHTML) {
            self.document = tidyHTML
        } else if let tidyXML {
            self.document = tidyXML
        } else if let tidyHTML {
            self.document = tidyHTML
        } else {
            // 个别页面 tidy 失败，但仍是合法 XML/HTML 片段，再尝试不 tidy。
            do {
                self.document = try XMLDocument(xmlString: html, options: [.nodePreserveAll])
            } catch {
                throw OnlinePlaybackError.htmlParseFailed
            }
        }
        self.baseURL = baseURL
    }

    private static func dropsHTML5Tags(html: String, document: XMLDocument) -> Bool {
        let lowered = html.lowercased()
        let tags = ["section", "article", "nav", "main", "header", "footer", "aside"]
        for tag in tags where lowered.contains("<\(tag)") {
            let count = (try? document.nodes(forXPath: "//\(tag)"))?.count ?? 0
            if count == 0 {
                return true
            }
        }
        return false
    }

    // MARK: CSS

    func elements(css selector: String) -> [XMLElement] {
        guard let xpath = OnlineCSSSelector.xpath(for: selector) else { return [] }
        return elements(xpath: xpath)
    }

    func elements(css selector: String, in node: XMLNode) -> [XMLElement] {
        guard let xpath = OnlineCSSSelector.xpath(for: selector) else { return [] }
        return nodes(xpath: xpath, in: node).compactMap { $0 as? XMLElement }
    }

    func firstElement(css selector: String) -> XMLElement? {
        return elements(css: selector).first
    }

    // MARK: XPath

    func elements(xpath: String) -> [XMLElement] {
        return nodes(xpath: xpath).compactMap { $0 as? XMLElement }
    }

    func nodes(xpath: String) -> [XMLNode] {
        let normalized = OnlineXPath.relative(xpath)
        guard !normalized.isEmpty else { return [] }
        return (try? document.nodes(forXPath: normalized)) ?? []
    }

    func nodes(xpath: String, in node: XMLNode) -> [XMLNode] {
        let normalized = OnlineXPath.relative(xpath)
        guard !normalized.isEmpty else { return [] }
        return (try? node.nodes(forXPath: normalized)) ?? []
    }

    // MARK: Helpers

    func attribute(_ name: String, of element: XMLElement) -> String? {
        return element.attribute(forName: name)?.stringValue
    }

    func href(of element: XMLElement) -> URL? {
        return directHref(of: element)
    }

    /// 搜索/选集规则的 XPath 可能命中容器、文本节点或行内元素。
    /// 依次查找自身 href、向下最近的 `<a href>`、向上最近的 href。
    func href(of node: XMLNode) -> URL? {
        if let element = node as? XMLElement {
            if let url = directHref(of: element) {
                return url
            }
            if let descendant = firstDescendantAnchor(in: element),
               let url = directHref(of: descendant) {
                return url
            }
            return ancestorHref(of: element)
        }

        var parent = node.parent
        while let current = parent {
            if let element = current as? XMLElement {
                if let url = directHref(of: element) {
                    return url
                }
                if let descendant = firstDescendantAnchor(in: element),
                   let url = directHref(of: descendant) {
                    return url
                }
            }
            parent = current.parent
        }
        return nil
    }

    private func directHref(of element: XMLElement) -> URL? {
        guard let raw = attribute("href", of: element)?
            .trimmingCharacters(in: .whitespacesAndNewlines),
              !raw.isEmpty else {
            return nil
        }
        return Self.absoluteURL(raw, baseURL: baseURL)
    }

    private func firstDescendantAnchor(in element: XMLElement) -> XMLElement? {
        guard let nodes = try? element.nodes(forXPath: ".//a[@href]") else {
            return nil
        }
        return nodes.compactMap { $0 as? XMLElement }.first
    }

    private func ancestorHref(of element: XMLElement) -> URL? {
        var parent = element.parent
        while let current = parent {
            if let ancestor = current as? XMLElement,
               let url = directHref(of: ancestor) {
                return url
            }
            parent = current.parent
        }
        return nil
    }

    func text(of node: XMLNode?) -> String {
        guard let node = node else { return "" }
        return Self.cleanText(node.stringValue ?? "")
    }

    static func cleanText(_ raw: String) -> String {
        let normalized = raw
            .replacingOccurrences(of: "\u{00A0}", with: " ")
            .replacingOccurrences(of: "\r", with: " ")
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "\t", with: " ")
        return normalized
            .components(separatedBy: .whitespaces)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    static func absoluteURL(_ raw: String, baseURL: URL?) -> URL? {
        return KazumiURL.resolve(raw, base: baseURL)
    }

    static func origin(of url: URL) -> URL? {
        guard let scheme = url.scheme, let host = url.host else { return nil }
        var components = URLComponents()
        components.scheme = scheme
        components.host = host
        if let port = url.port {
            components.port = port
        }
        components.path = "/"
        return components.url
    }
}

// MARK: - XPath helpers

enum OnlineXPath {

    /// Kazumi 规则里的 XPath 是相对剧集容器的：
    /// `/div/a` → `./div/a`，`//div/a` → `.//div/a`。
    static func relative(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        let parts = splitTopLevel(trimmed, separator: "|")
        guard !parts.isEmpty else { return "" }

        return parts.map { part -> String in
            let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty else { return "" }
            if value == "." {
                return "self::node()"
            }
            if value == ".." {
                return "parent::node()"
            }
            if value == "/" || value == "//" {
                // 规则里偶发只有 `/`；容器内求值等价于当前节点本身。
                return "self::node()"
            }
            if value.hasPrefix("./") || value.hasPrefix(".//") || value.hasPrefix("(") {
                return value
            }
            if value.hasPrefix("/") {
                return "." + value
            }
            return ".//" + value
        }
        .filter { !$0.isEmpty }
        .joined(separator: " | ")
    }

    static func splitTopLevel(_ raw: String, separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var bracketDepth = 0
        var parenDepth = 0
        var quote: Character?

        for character in raw {
            if let activeQuote = quote {
                current.append(character)
                if character == activeQuote {
                    quote = nil
                }
                continue
            }

            switch character {
            case "'", "\"":
                quote = character
                current.append(character)
            case "[":
                bracketDepth += 1
                current.append(character)
            case "]":
                bracketDepth = max(0, bracketDepth - 1)
                current.append(character)
            case "(":
                parenDepth += 1
                current.append(character)
            case ")":
                parenDepth = max(0, parenDepth - 1)
                current.append(character)
            default:
                if character == separator, bracketDepth == 0, parenDepth == 0 {
                    result.append(current)
                    current = ""
                } else {
                    current.append(character)
                }
            }
        }

        if !current.isEmpty {
            result.append(current)
        }
        return result
    }
}

// MARK: - CSS → XPath

enum OnlineCSSSelector {

    /// 将常见 CSS 选择器转换为 XPath 1.0。
    /// 支持：tag、*、#id、.class、[attr]、[attr=v]、[attr^=v]、[attr$=v]、[attr*=v]、
    /// 后代/子元素组合、逗号并集、:first-child / :last-child / :nth-child(n)。
    static func xpath(for selector: String) -> String? {
        let groups = OnlineXPath.splitTopLevel(selector, separator: ",")
        let converted = groups.compactMap { convertGroup($0) }
        guard !converted.isEmpty else { return nil }
        return converted.joined(separator: " | ")
    }

    private static func convertGroup(_ raw: String) -> String? {
        let tokens = tokenize(raw)
        guard !tokens.isEmpty else { return nil }

        var xpath = ""
        var isFirst = true

        for (index, token) in tokens.enumerated() {
            switch token {
            case .child:
                continue
            case .compound(let value):
                let step = compoundStep(value)
                if isFirst {
                    xpath = ".//" + step
                    isFirst = false
                } else if index > 0, case .child = tokens[index - 1] {
                    xpath += "/" + step
                } else {
                    xpath += "//" + step
                }
            }
        }

        return xpath.isEmpty ? nil : xpath
    }

    private enum Token {
        case child
        case compound(String)
    }

    private static func tokenize(_ raw: String) -> [Token] {
        var tokens: [Token] = []
        var current = ""
        var bracketDepth = 0
        var parenDepth = 0
        var quote: Character?

        func flush() {
            let value = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !value.isEmpty {
                tokens.append(.compound(value))
            }
            current = ""
        }

        for character in raw {
            if let activeQuote = quote {
                current.append(character)
                if character == activeQuote {
                    quote = nil
                }
                continue
            }

            switch character {
            case "'", "\"":
                quote = character
                current.append(character)
            case "[":
                bracketDepth += 1
                current.append(character)
            case "]":
                bracketDepth = max(0, bracketDepth - 1)
                current.append(character)
            case "(":
                parenDepth += 1
                current.append(character)
            case ")":
                parenDepth = max(0, parenDepth - 1)
                current.append(character)
            case ">":
                if bracketDepth == 0, parenDepth == 0 {
                    flush()
                    tokens.append(.child)
                } else {
                    current.append(character)
                }
            case " ", "\t", "\n", "\r":
                if bracketDepth == 0, parenDepth == 0 {
                    flush()
                } else {
                    current.append(character)
                }
            default:
                current.append(character)
            }
        }
        flush()
        return tokens
    }

    private static func compoundStep(_ raw: String) -> String {
        var index = raw.startIndex
        var tag = ""
        var conditions: [String] = []
        var pseudo: [String] = []

        func consumeIdentifier() -> String {
            var value = ""
            while index < raw.endIndex {
                let character = raw[index]
                if character.isLetter || character.isNumber || character == "-" || character == "_" {
                    value.append(character)
                    index = raw.index(after: index)
                } else {
                    break
                }
            }
            return value
        }

        if index < raw.endIndex, raw[index] == "*" {
            tag = "*"
            index = raw.index(after: index)
        } else {
            let name = consumeIdentifier()
            if !name.isEmpty {
                tag = name.lowercased()
            }
        }

        while index < raw.endIndex {
            let character = raw[index]
            switch character {
            case "#":
                index = raw.index(after: index)
                let identifier = consumeIdentifier()
                if !identifier.isEmpty {
                    conditions.append("[@id=\(literal(identifier))]")
                }
            case ".":
                index = raw.index(after: index)
                let identifier = consumeIdentifier()
                if !identifier.isEmpty {
                    conditions.append(
                        "[contains(concat(' ', normalize-space(@class), ' '), \(literal(" " + identifier + " ")))]"
                    )
                }
            case "[":
                if let closing = findClosingBracket(in: raw, from: index) {
                    let body = String(raw[raw.index(after: index)..<closing])
                    if let condition = attributeCondition(body) {
                        conditions.append(condition)
                    }
                    index = raw.index(after: closing)
                } else {
                    index = raw.endIndex
                }
            case ":":
                index = raw.index(after: index)
                let name = consumeIdentifier()
                if name == "first-child" {
                    pseudo.append("[1]")
                } else if name == "last-child" {
                    pseudo.append("[last()]")
                } else if name == "nth-child",
                          index < raw.endIndex,
                          raw[index] == "(",
                          let closing = raw[index...].firstIndex(of: ")") {
                    let number = raw[raw.index(after: index)..<closing]
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    if Int(number) != nil {
                        pseudo.append("[\(number)]")
                    }
                    index = raw.index(after: closing)
                }
            default:
                index = raw.index(after: index)
            }
        }

        let base = tag.isEmpty ? "*" : tag
        return base + conditions.joined() + pseudo.joined()
    }

    private static func attributeCondition(_ raw: String) -> String? {
        let pattern = #"^\s*([A-Za-z0-9_:\-]+)\s*(?:([\^\$\*]?=)\s*(?:"([^"]*)"|'([^']*)'|([^\s]+))\s*)?$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: raw, range: NSRange(raw.startIndex..., in: raw)) else {
            return nil
        }

        func group(_ index: Int) -> String? {
            guard let range = Range(match.range(at: index), in: raw) else { return nil }
            return String(raw[range])
        }

        guard let name = group(1) else { return nil }
        guard let op = group(2) else {
            return "[@\(name)]"
        }
        let value = group(3) ?? group(4) ?? group(5) ?? ""
        switch op {
        case "=":
            return "[@\(name)=\(literal(value))]"
        case "^=":
            return "[starts-with(@\(name), \(literal(value)))]"
        case "$=":
            return "[substring(@\(name), string-length(@\(name)) - string-length(\(literal(value))) + 1) = \(literal(value))]"
        case "*=":
            return "[contains(@\(name), \(literal(value)))]"
        default:
            return nil
        }
    }

    private static func findClosingBracket(in raw: String, from start: String.Index) -> String.Index? {
        var index = raw.index(after: start)
        var quote: Character?
        while index < raw.endIndex {
            let character = raw[index]
            if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "]" {
                return index
            }
            index = raw.index(after: index)
        }
        return nil
    }

    private static func literal(_ value: String) -> String {
        if !value.contains("\"") {
            return "\"\(value)\""
        }
        if !value.contains("'") {
            return "'\(value)'"
        }
        // 同时包含单双引号：按双引号切分，用 concat 拼接。
        let parts = value.components(separatedBy: "\"")
        var pieces: [String] = []
        for (index, part) in parts.enumerated() {
            if !part.isEmpty {
                if part.contains("'") {
                    pieces.append("\"\(part)\"")
                } else {
                    pieces.append("'\(part)'")
                }
            }
            if index < parts.count - 1 {
                pieces.append("'\"'")
            }
        }
        return "concat(\(pieces.joined(separator: ", ")))"
    }
}
