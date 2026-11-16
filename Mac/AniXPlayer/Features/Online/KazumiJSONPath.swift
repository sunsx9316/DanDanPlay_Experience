//
//  KazumiJSONPath.swift
//  AniXPlayer
//
//  macOS：Kazumi API 规则使用的最小 JSONPath 子集。
//
//  只实现规则实际用到的语法，避免引入第三方依赖：
//  - `$` 根节点
//  - `.field` / `['field']` / `["field"]`
//  - `[0]`、`[-1]` 数组下标
//  - `[*]` 数组/对象通配
//
//  不支持的语法会抛出明确错误，由上层隔离单条规则。
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
                index = expression.index(after: index)
                guard index < expression.endIndex else {
                    throw KazumiJSONPathError.invalidExpression(expression)
                }
                if expression[index] == "." {
                    throw KazumiJSONPathError.unsupportedExpression(expression)
                }
                if expression[index] == "*" {
                    tokens.append(.wildcard)
                    index = expression.index(after: index)
                    continue
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
                if content == "*" {
                    tokens.append(.wildcard)
                } else if let number = Int(content) {
                    tokens.append(.index(number))
                } else if content.count >= 2,
                          (content.hasPrefix("'") && content.hasSuffix("'"))
                            || (content.hasPrefix("\"") && content.hasSuffix("\"")) {
                    let key = String(content.dropFirst().dropLast())
                        .replacingOccurrences(of: "\\'", with: "'")
                        .replacingOccurrences(of: "\\\"", with: "\"")
                        .replacingOccurrences(of: "\\\\", with: "\\")
                    tokens.append(.key(key))
                } else {
                    throw KazumiJSONPathError.unsupportedExpression(expression)
                }
                index = expression.index(after: closing)
                continue
            }

            throw KazumiJSONPathError.unsupportedExpression(expression)
        }

        return tokens
    }

    private static func findClosingBracket(
        in expression: String,
        from start: String.Index
    ) -> String.Index? {
        var index = expression.index(after: start)
        var quote: Character?
        var escaped = false

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
            } else if character == "]" {
                return index
            }
            index = expression.index(after: index)
        }
        return nil
    }
}
