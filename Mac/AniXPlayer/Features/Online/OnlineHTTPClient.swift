//
//  OnlineHTTPClient.swift
//  AniXPlayer
//
//  macOS：在线源解析使用的轻量 HTTP 客户端。
//  统一处理超时、大小限制、常见中文编码与请求头。
//

import Foundation

struct OnlineHTTPResponse {
    let text: String
    let finalURL: URL
    let mimeType: String?
}

final class OnlineHTTPClient {

    static let shared = OnlineHTTPClient(configuration: OnlineHTTPClient.defaultConfiguration())

    /// 在线源页面通常不大；超过此大小视为异常，避免正则/HTML 解析卡死。
    static let maximumResponseBytes = 8 * 1024 * 1024

    private let session: URLSession

    /// 测试可注入带 StubURLProtocol 的 URLSessionConfiguration。
    init(configuration: URLSessionConfiguration) {
        self.session = URLSession(configuration: configuration)
    }

    static func defaultConfiguration() -> URLSessionConfiguration {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 20
        configuration.timeoutIntervalForResource = 30
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        configuration.httpCookieAcceptPolicy = .never
        configuration.httpShouldSetCookies = false
        configuration.httpAdditionalHeaders = [
            "Accept": "text/html,application/xhtml+xml,application/json;q=0.9,*/*;q=0.8",
            "Accept-Language": "zh-CN,zh;q=0.9,en;q=0.8"
        ]
        return configuration
    }

    func get(
        _ url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> OnlineHTTPResponse {
        return try await request(
            method: "GET",
            url: url,
            headers: headers,
            body: nil,
            contentType: nil,
            timeout: timeout
        )
    }

    /// GET/POST 通用入口；超时、状态码、大小限制和文本解码与 get 完全一致。
    func request(
        method: String,
        url: URL,
        headers: [String: String] = [:],
        body: Data? = nil,
        contentType: String? = nil,
        timeout: TimeInterval = 20
    ) async throws -> OnlineHTTPResponse {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw OnlinePlaybackError.invalidURL(url.absoluteString)
        }

        let normalizedMethod = method.uppercased()
        guard normalizedMethod == "GET" || normalizedMethod == "POST" else {
            throw OnlinePlaybackError.unsupportedRule(String(
                format: NSLocalizedString("不支持的 HTTP 方法：%@", comment: ""),
                normalizedMethod
            ))
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.httpMethod = normalizedMethod
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(Self.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }
        if let contentType,
           request.value(forHTTPHeaderField: "Content-Type") == nil {
            request.setValue(contentType, forHTTPHeaderField: "Content-Type")
        }
        if normalizedMethod == "POST" {
            request.httpBody = body
        }

        return try await perform(request: request, fallbackURL: url)
    }

    /// POST JSON：payload 可以是对象/数组；编码失败直接抛出，不发送不完整请求。
    func postJSON(
        _ url: URL,
        payload: Any,
        headers: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> OnlineHTTPResponse {
        let data: Data
        do {
            data = try JSONSerialization.data(withJSONObject: payload, options: [.fragmentsAllowed])
        } catch {
            throw OnlinePlaybackError.unsupportedRule(
                NSLocalizedString("请求体不是有效的 JSON。", comment: "")
            )
        }
        return try await request(
            method: "POST",
            url: url,
            headers: headers,
            body: data,
            contentType: "application/json; charset=utf-8",
            timeout: timeout
        )
    }

    /// 下载源配置文件（JSON），不经过 HTML 编码猜测。
    func getData(
        _ url: URL,
        headers: [String: String] = [:],
        timeout: TimeInterval = 20
    ) async throws -> Data {
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            throw OnlinePlaybackError.invalidURL(url.absoluteString)
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        if request.value(forHTTPHeaderField: "User-Agent") == nil {
            request.setValue(Self.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        }
        for (key, value) in headers {
            request.setValue(value, forHTTPHeaderField: key)
        }

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OnlinePlaybackError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OnlinePlaybackError.httpStatus(http.statusCode, url)
        }
        guard data.count <= Self.maximumResponseBytes else {
            throw OnlinePlaybackError.responseTooLarge
        }
        return data
    }

    static let defaultUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

    // MARK: - Private

    private func perform(request: URLRequest, fallbackURL: URL) async throws -> OnlineHTTPResponse {
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw OnlinePlaybackError.emptyResponse
        }
        guard (200..<300).contains(http.statusCode) else {
            throw OnlinePlaybackError.httpStatus(http.statusCode, fallbackURL)
        }
        guard data.count <= Self.maximumResponseBytes else {
            throw OnlinePlaybackError.responseTooLarge
        }

        let finalURL = http.url ?? fallbackURL
        let text = Self.decode(data: data, response: http)
        guard !text.isEmpty else {
            throw OnlinePlaybackError.emptyResponse
        }

        return OnlineHTTPResponse(
            text: text,
            finalURL: finalURL,
            mimeType: http.mimeType
        )
    }

    // MARK: - Decoding

    private static func decode(data: Data, response: HTTPURLResponse) -> String {
        let headerCharset = response.value(forHTTPHeaderField: "Content-Type")?
            .lowercased()
            .components(separatedBy: "charset=")
            .dropFirst()
            .first?
            .components(separatedBy: ";")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)

        var encodings: [String.Encoding] = []
        if let headerCharset, let encoding = encoding(forCharset: headerCharset) {
            encodings.append(encoding)
        }

        // HTML meta charset（部分源站响应头不带 charset）。
        if let prefix = String(data: data.prefix(4096), encoding: .isoLatin1)?.lowercased(),
           let range = prefix.range(of: "charset=") {
            let tail = prefix[range.upperBound...]
                .prefix(40)
                .trimmingCharacters(in: CharacterSet(charactersIn: "\"' />\n\r\t"))
            let value = tail.components(separatedBy: CharacterSet(charactersIn: "\"' />\n\r\t;")).first ?? ""
            if let encoding = encoding(forCharset: value) {
                encodings.append(encoding)
            }
        }

        encodings.append(.utf8)
        encodings.append(encoding(forCharset: "gb18030") ?? .utf8)
        encodings.append(encoding(forCharset: "big5") ?? .utf8)
        encodings.append(.isoLatin1)

        for encoding in encodings {
            if let text = String(data: data, encoding: encoding), !text.isEmpty {
                return text
            }
        }

        return String(decoding: data, as: UTF8.self)
    }

    private static func encoding(forCharset charset: String) -> String.Encoding? {
        let value = charset.trimmingCharacters(in: .whitespacesAndNewlines)
        if value.isEmpty { return nil }

        switch value {
        case "utf-8", "utf8":
            return .utf8
        case "gbk", "gb2312", "gb18030", "x-gbk":
            let cfEncoding = CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        case "big5", "big-5", "x-big5":
            let cfEncoding = CFStringEncoding(CFStringEncodings.big5.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        case "shift_jis", "shift-jis", "sjis", "cp932":
            let cfEncoding = CFStringEncoding(CFStringEncodings.shiftJIS.rawValue)
            return String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
        case "iso-8859-1", "latin1":
            return .isoLatin1
        default:
            return nil
        }
    }
}
