//
//  KazumiJSONPath.swift
//  AniXPlayer
//
//  macOS：Animeko / Kazumi 规则使用的最小 JSONPath 子集。
//
//  只实现规则实际用到的语法，避免引入第三方依赖：
//  - `$` 根节点
//  - `.field` / `['field']` / `["field"]`
//  - `[0]`、`[-1]` 数组下标
//  - `[*]` 数组/对象通配
//  - `[?(@.field == 'value')]`、`[?(@.field)]`、`[?(@.field != 'value')]`
//  - `..field` 递归下降（也支持 `..*`）
//  - `[start:end]` 正向数组切片（支持负下标）
//  - `[0,1]` / `['a','b']` 逗号 union
//
//  不支持的语法会抛出明确错误，由上层隔离单条规则；不会静默返回空数组。
//

import Foundation

enum KazumiJSONPathError: LocalizedError, Equatable {
    case invalidExpression(String)
    case unsupportedExpression(String)

    var errorDescription: String? {
        switch self {
        case .invalidExpression(let expression):
            return String(
                format: NSLocalizedString("JSONPath 无效：%@", comment: ""),
                expression
            )
        case .unsupportedExpression(let expression):
            return String(
                format: NSLocalizedString("JSONPath 暂不支持：%@", comment: ""),
                expression
            )
        }
    }
}

enum KazumiJSONPath {

    private enum Token: Equatable {
        case key(String)
        case index(Int)
        case wildcard
        case recursiveKey(String)
        case recursiveWildcard
        case filter(FilterExpression)
        case slice(start: Int?, end: Int?)
        case union([UnionSelector])
    }

    private enum UnionSelector: Equatable {
        case key(String)
        case index(Int)
    }

    private enum FilterOperator: Equatable {
        case exists
        case equal
        case notEqual
    }

    private enum FilterLiteral: Equatable {
        case string(String)
        case number(Double)
        case bool(Bool)
        case null
    }

    private struct FilterExpression: Equatable {
        let path: [String]
        let op: FilterOperator
        let literal: FilterLiteral?
    }

    static func read(_ document: Any, path: String) throws -> [Any] {
        let tokens = try parse(path)
        var current: [Any] = [document]

        for token in tokens {
            var next: [Any] = []
            for node in current {
                switch token {
                case .key(let key):
                    if let dictionary = node as? [String: Any], let value = dictionary[key] {
                        next.append(value)
                    }
                case .index(let index):
                    if let array = node as? [Any] {
                        let resolved = index < 0 ? array.count + index : index
                        if array.indices.contains(resolved) {
                            next.append(array[resolved])
                        }
                    }
                case .wildcard:
                    if let array = node as? [Any] {
                        next.append(contentsOf: array)
                    } else if let dictionary = node as? [String: Any] {
                        // Swift Dictionary 无序；排序保证 fixture/测试稳定。
                        for key in dictionary.keys.sorted() {
                            if let value = dictionary[key] {
                                next.append(value)
                            }
                        }
                    }
                case .recursiveKey(let key):
                    next.append(contentsOf: recursiveValues(in: node, key: key))
                case .recursiveWildcard:
                    next.append(contentsOf: recursiveDescendants(in: node))
                case .filter(let filter):
                    for child in children(of: node) where matches(filter, node: child) {
                        next.append(child)
                    }
                case .slice(let start, let end):
                    if let array = node as? [Any] {
                        next.append(contentsOf: sliced(array, start: start, end: end))
                    }
                case .union(let selectors):
                    for selector in selectors {
                        switch selector {
                        case .key(let key):
                            if let dictionary = node as? [String: Any],
                               let value = dictionary[key] {
                                next.append(value)
                            }
                        case .index(let index):
                            if let array = node as? [Any] {
                                let resolved = index < 0 ? array.count + index : index
                                if array.indices.contains(resolved) {
                                    next.append(array[resolved])
                                }
                            }
                        }
                    }
                }
            }
            current = next
        }

        return current
    }

    static func first(in document: Any, path: String) throws -> Any? {
        return try read(document, path: path).first
    }

    static func validate(_ path: String) throws {
        _ = try parse(path)
    }

    static func stringValue(_ value: Any?) -> String {
        guard let value else { return "" }
        if value is NSNull { return "" }
        if let string = value as? String {
            return string.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                return number.boolValue ? "true" : "false"
            }
            return number.stringValue
        }
        return String(describing: value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    // MARK: - Evaluation helpers

    private static func children(of node: Any) -> [Any] {
        if let array = node as? [Any] {
            return array
        }
        if let dictionary = node as? [String: Any] {
            return dictionary.keys.sorted().compactMap { dictionary[$0] }
        }
        return []
    }

    private static func recursiveValues(in node: Any, key: String) -> [Any] {
        var result: [Any] = []

        if let dictionary = node as? [String: Any] {
            if let value = dictionary[key] {
                result.append(value)
            }
            for childKey in dictionary.keys.sorted() {
                if let child = dictionary[childKey] {
                    result.append(contentsOf: recursiveValues(in: child, key: key))
                }
            }
        } else if let array = node as? [Any] {
            for child in array {
                result.append(contentsOf: recursiveValues(in: child, key: key))
            }
        }

        return result
    }

    private static func recursiveDescendants(in node: Any) -> [Any] {
        var result: [Any] = []

        if let dictionary = node as? [String: Any] {
            for childKey in dictionary.keys.sorted() {
                guard let child = dictionary[childKey] else { continue }
                result.append(child)
                result.append(contentsOf: recursiveDescendants(in: child))
            }
        } else if let array = node as? [Any] {
            for child in array {
                result.append(child)
                result.append(contentsOf: recursiveDescendants(in: child))
            }
        }

        return result
    }

    private static func sliced(_ array: [Any], start: Int?, end: Int?) -> [Any] {
        let count = array.count
        let rawStart = start ?? 0
        let rawEnd = end ?? count
        let resolvedStart = rawStart < 0 ? count + rawStart : rawStart
        let resolvedEnd = rawEnd < 0 ? count + rawEnd : rawEnd
        let lower = min(max(resolvedStart, 0), count)
        let upper = min(max(resolvedEnd, 0), count)
        guard lower < upper else { return [] }
        return Array(array[lower..<upper])
    }

    private static func matches(_ filter: FilterExpression, node: Any) -> Bool {
        guard let value = resolve(filter.path, in: node) else {
            // 字段不存在：!= 视为不相等；其他比较/存在判断不命中。
            return filter.op == .notEqual
        }

        switch filter.op {
        case .exists:
            return !(value is NSNull)
        case .equal:
            guard let literal = filter.literal else { return false }
            return equals(value, literal)
        case .notEqual:
            guard let literal = filter.literal else { return false }
            return !equals(value, literal)
        }
    }

    private static func resolve(_ path: [String], in node: Any) -> Any? {
        var current: Any? = node
        for segment in path {
            guard let value = current else { return nil }
            if let dictionary = value as? [String: Any] {
                current = dictionary[segment]
            } else if let array = value as? [Any], let index = Int(segment) {
                let resolved = index < 0 ? array.count + index : index
                current = array.indices.contains(resolved) ? array[resolved] : nil
            } else {
                return nil
            }
        }
        return current
    }

    private static func equals(_ value: Any, _ literal: FilterLiteral) -> Bool {
        switch literal {
        case .string(let expected):
            if let string = value as? String {
                return string == expected
            }
            if let number = value as? NSNumber, !isBoolean(number) {
                return number.stringValue == expected
            }
            return false
        case .number(let expected):
            if let number = value as? NSNumber, !isBoolean(number) {
                return number.doubleValue == expected
            }
            if let string = value as? String, let number = Double(string) {
                return number == expected
            }
            return false
        case .bool(let expected):
            if let number = value as? NSNumber, isBoolean(number) {
                return number.boolValue == expected
            }
            if let string = value as? String {
                let lowered = string.lowercased()
                if lowered == "true" { return expected }
                if lowered == "false" { return !expected }
            }
            return false
        case .null:
            return value is NSNull
        }
    }

    private static func isBoolean(_ number: NSNumber) -> Bool {
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    // MARK: - Parsing

    private static func parse(_ path: String) throws -> [Token] {
        let expression = path.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !expression.isEmpty else {
            throw KazumiJSONPathError.invalidExpression(path)
        }
        guard expression.hasPrefix("$") else {
            throw KazumiJSONPathError.invalidExpression(expression)
        }

        var tokens: [Token] = []
        var index = expression.index(after: expression.startIndex)

        while index < expression.endIndex {
            let character = expression[index]

            if character == "." {
                let next = expression.index(after: index)
                guard next < expression.endIndex else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }

                if expression[next] == "." {
                    // 递归下降：..field / ..*
                    var cursor = expression.index(after: next)
                    guard cursor < expression.endIndex else {
                        throw KazumiJSONPathError.invalidExpression(expression)
                    }
                    if expression[cursor] == "*" {
                        tokens.append(.recursiveWildcard)
                        index = expression.index(after: cursor)
                        continue
                    }
                    if expression[cursor] == "[" {
                        throw KazumiJSONPathError.unsupportedExpression(expression)
                    }
                    let start = cursor
                    while cursor < expression.endIndex,
                          expression[cursor] != ".",
                          expression[cursor] != "[" {
                        cursor = expression.index(after: cursor)
                    }
                    let key = String(expression[start..<cursor])
                    guard !key.isEmpty else {
                        throw KazumiJSONPathError.invalidExpression(expression)
                    }
                    tokens.append(.recursiveKey(key))
                    index = cursor
                    continue
                }

                index = next
                if expression[index] == "*" {
                    tokens.append(.wildcard)
                    index = expression.index(after: index)
                    continue
                }
                if expression[index] == "[" {
                    throw KazumiJSONPathError.unsupportedExpression(expression)
                }
                let start = index
                while index < expression.endIndex,
                      expression[index] != ".",
                      expression[index] != "[" {
                    index = expression.index(after: index)
                }
                let key = String(expression[start..<index])
                guard !key.isEmpty else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                tokens.append(.key(key))
                continue
            }

            if character == "[" {
                guard let closing = findClosingBracket(in: expression, from: index) else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                let content = expression[expression.index(after: index)..<closing]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !content.isEmpty else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                tokens.append(try bracketToken(content, expression: expression))
                index = expression.index(after: closing)
                continue
            }

            throw KazumiJSONPathError.unsupportedExpression(expression)
        }

        return tokens
    }

    private static func bracketToken(_ content: String, expression: String) throws -> Token {
        if content == "*" {
            return .wildcard
        }

        if content.hasPrefix("?(") {
            guard content.hasSuffix(")") else {
                throw KazumiJSONPathError.invalidExpression(expression)
            }
            let body = content
                .dropFirst(2)
                .dropLast()
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return .filter(try parseFilter(body, expression: expression))
        }

        let parts = splitTopLevel(content, separator: ",")
        if parts.count > 1 {
            var selectors: [UnionSelector] = []
            for part in parts {
                let value = part.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !value.isEmpty else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                if let number = Int(value) {
                    selectors.append(.index(number))
                } else if let key = quotedKey(value) {
                    selectors.append(.key(key))
                } else {
                    throw KazumiJSONPathError.unsupportedExpression(expression)
                }
            }
            return .union(selectors)
        }

        if let key = quotedKey(content) {
            return .key(key)
        }
        if let number = Int(content) {
            return .index(number)
        }
        if content.contains(":") {
            let sliceParts = splitTopLevel(content, separator: ":")
            guard sliceParts.count == 2 else {
                throw KazumiJSONPathError.unsupportedExpression(expression)
            }
            let start = try sliceBound(sliceParts[0], expression: expression)
            let end = try sliceBound(sliceParts[1], expression: expression)
            return .slice(start: start, end: end)
        }

        throw KazumiJSONPathError.unsupportedExpression(expression)
    }

    private static func sliceBound(_ raw: String, expression: String) throws -> Int? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return nil }
        guard let number = Int(value) else {
            throw KazumiJSONPathError.unsupportedExpression(expression)
        }
        return number
    }

    private static func parseFilter(_ raw: String, expression: String) throws -> FilterExpression {
        let body = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !body.isEmpty else {
            throw KazumiJSONPathError.invalidExpression(expression)
        }

        if let match = try findFilterOperator(in: body, expression: expression) {
            let op = match.0
            let literalStart = match.1
            let pathPart = String(body[..<literalStart.operatorStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let literalPart = String(body[literalStart.valueStart...])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !literalPart.isEmpty else {
                throw KazumiJSONPathError.invalidExpression(expression)
            }
            let path = try parseFilterPath(pathPart, expression: expression)
            let literal = try parseFilterLiteral(literalPart, expression: expression)
            return FilterExpression(path: path, op: op, literal: literal)
        }

        let path = try parseFilterPath(body, expression: expression)
        return FilterExpression(path: path, op: .exists, literal: nil)
    }

    private static func findFilterOperator(
        in raw: String,
        expression: String
    ) throws -> (FilterOperator, (operatorStart: String.Index, valueStart: String.Index))? {
        var index = raw.startIndex
        var quote: Character?
        var escaped = false
        var bracketDepth = 0
        var parenDepth = 0

        while index < raw.endIndex {
            let character = raw[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "[" {
                bracketDepth += 1
            } else if character == "]" {
                bracketDepth = max(0, bracketDepth - 1)
            } else if character == "(" {
                parenDepth += 1
            } else if character == ")" {
                parenDepth = max(0, parenDepth - 1)
            } else if bracketDepth == 0, parenDepth == 0 {
                if character == "=" {
                    let next = raw.index(after: index)
                    guard next < raw.endIndex, raw[next] == "=" else {
                        throw KazumiJSONPathError.unsupportedExpression(expression)
                    }
                    return (
                        .equal,
                        (operatorStart: index, valueStart: raw.index(after: next))
                    )
                }
                if character == "!" {
                    let next = raw.index(after: index)
                    guard next < raw.endIndex, raw[next] == "=" else {
                        throw KazumiJSONPathError.unsupportedExpression(expression)
                    }
                    return (
                        .notEqual,
                        (operatorStart: index, valueStart: raw.index(after: next))
                    )
                }
                if character == ">" || character == "<" || character == "~" {
                    throw KazumiJSONPathError.unsupportedExpression(expression)
                }
            }

            index = raw.index(after: index)
        }

        return nil
    }

    private static func parseFilterPath(_ raw: String, expression: String) throws -> [String] {
        let path = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard path.hasPrefix("@") else {
            throw KazumiJSONPathError.unsupportedExpression(expression)
        }

        var segments: [String] = []
        var index = path.index(after: path.startIndex)

        while index < path.endIndex {
            let character = path[index]

            if character.isWhitespace {
                index = path.index(after: index)
                continue
            }

            if character == "." {
                index = path.index(after: index)
                let start = index
                while index < path.endIndex,
                      !path[index].isWhitespace,
                      path[index] != ".",
                      path[index] != "[" {
                    index = path.index(after: index)
                }
                let key = String(path[start..<index])
                guard !key.isEmpty else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                segments.append(key)
                continue
            }

            if character == "[" {
                guard let closing = findClosingBracket(in: path, from: index) else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                let content = path[path.index(after: index)..<closing]
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if let key = quotedKey(content) {
                    segments.append(key)
                } else if let number = Int(content) {
                    segments.append(String(number))
                } else {
                    throw KazumiJSONPathError.unsupportedExpression(expression)
                }
                index = path.index(after: closing)
                continue
            }

            throw KazumiJSONPathError.unsupportedExpression(expression)
        }

        return segments
    }

    private static func parseFilterLiteral(_ raw: String, expression: String) throws -> FilterLiteral {
        if let value = quotedKey(raw) {
            return .string(value)
        }
        switch raw.lowercased() {
        case "true":
            return .bool(true)
        case "false":
            return .bool(false)
        case "null":
            return .null
        default:
            break
        }
        if let number = Double(raw) {
            return .number(number)
        }
        throw KazumiJSONPathError.unsupportedExpression(expression)
    }

    /// 只接受完整包裹在单引号/双引号里的字符串；`'a','b'` 不会被误认为一个 key。
    private static func quotedKey(_ raw: String) -> String? {
        guard let quote = raw.first, quote == "'" || quote == "\"" else { return nil }
        guard raw.count >= 2 else { return nil }

        var result = ""
        var index = raw.index(after: raw.startIndex)
        var escaped = false

        while index < raw.endIndex {
            let character = raw[index]
            if escaped {
                result.append(character)
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if character == quote {
                return index == raw.index(before: raw.endIndex) ? result : nil
            } else {
                result.append(character)
            }
            index = raw.index(after: index)
        }
        return nil
    }

    private static func splitTopLevel(_ raw: String, separator: Character) -> [String] {
        var result: [String] = []
        var current = ""
        var bracketDepth = 0
        var parenDepth = 0
        var quote: Character?
        var escaped = false

        for character in raw {
            if escaped {
                current.append(character)
                escaped = false
                continue
            }
            if character == "\\" {
                current.append(character)
                escaped = true
                continue
            }
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

        result.append(current)
        return result
    }

    private static func findClosingBracket(
        in expression: String,
        from start: String.Index
    ) -> String.Index? {
        var index = expression.index(after: start)
        var quote: Character?
        var escaped = false
        var bracketDepth = 0

        while index < expression.endIndex {
            let character = expression[index]
            if escaped {
                escaped = false
            } else if character == "\\" {
                escaped = true
            } else if let activeQuote = quote {
                if character == activeQuote {
                    quote = nil
                }
            } else if character == "'" || character == "\"" {
                quote = character
            } else if character == "[" {
                bracketDepth += 1
            } else if character == "]" {
                if bracketDepth == 0 {
                    return index
                }
                bracketDepth -= 1
            }
            index = expression.index(after: index)
        }
        return nil
    }
}
