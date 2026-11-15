//
//  APIClient.swift
//  AniXPlayer
//
//  macOS only：基于 URLSession async/await 的最小 API 客户端。
//  旧代码继续走 NetworkManager，新代码逐步迁移到这里。
//

import Foundation

enum HTTPMethod: String {
    case get = "GET"
    case post = "POST"
    case delete = "DELETE"
}

final class APIClient {
    private let session: URLSession
    private let decoder = JSONDecoder()

    init(session: URLSession? = nil) {
        if let session = session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.default
            configuration.timeoutIntervalForRequest = 20
            configuration.timeoutIntervalForResource = 30
            configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
            self.session = URLSession(configuration: configuration)
        }
    }

    /// 发送请求并解码 JSON。
    func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data = try await send(request)
        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw APIError.decoding(error)
        }
    }

    /// 发送请求，只返回原始 body。
    func send(_ request: URLRequest) async throws -> Data {
        do {
            let (data, response) = try await session.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw APIError.transport(URLError(.badServerResponse))
            }

            switch http.statusCode {
            case 200..<300:
                return data
            case 401:
                if let oauthError = oauthError(from: data, status: 401) {
                    throw oauthError
                }
                throw APIError.unauthorized
            case 403:
                if let oauthError = oauthError(from: data, status: 403) {
                    throw oauthError
                }
                let header = http.value(forHTTPHeaderField: "X-Error-Message")
                throw APIError.forbidden(message: header ?? plainMessage(from: data))
            case 429:
                let retryAfter = http.value(forHTTPHeaderField: "Retry-After").flatMap(TimeInterval.init)
                throw APIError.rateLimited(retryAfter: retryAfter)
            default:
                if let oauthError = oauthError(from: data, status: http.statusCode) {
                    throw oauthError
                }
                let header = http.value(forHTTPHeaderField: "X-Error-Message")
                throw APIError.http(status: http.statusCode, message: header ?? plainMessage(from: data))
            }
        } catch let error as APIError {
            throw error
        } catch let error as URLError where error.code == .cancelled {
            throw APIError.cancelled
        } catch is CancellationError {
            throw APIError.cancelled
        } catch {
            throw APIError.transport(error)
        }
    }

    private func oauthError(from data: Data, status: Int) -> APIError? {
        guard let oauthError = try? decoder.decode(OAuthErrorResponse.self, from: data) else {
            return nil
        }
        return APIError.oauth(
            code: oauthError.error,
            description: oauthError.errorDescription,
            status: status
        )
    }

    private func plainMessage(from data: Data) -> String? {
        guard let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= 300 else {
            return nil
        }
        return trimmed
    }

    // MARK: - Request builders

    static func jsonRequest(
        url: URL,
        method: HTTPMethod = .get,
        body: Data? = nil,
        bearerToken: String? = nil,
        userAgent: String? = nil,
        timeout: TimeInterval? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = method.rawValue
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body = body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if let bearerToken = bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if let timeout = timeout {
            request.timeoutInterval = timeout
        }
        return request
    }

    static func formRequest(
        url: URL,
        fields: [String: String],
        bearerToken: String? = nil,
        userAgent: String? = nil,
        timeout: TimeInterval? = nil
    ) -> URLRequest {
        var request = URLRequest(url: url)
        request.httpMethod = HTTPMethod.post.rawValue
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.httpBody = formBody(fields)
        if let bearerToken = bearerToken, !bearerToken.isEmpty {
            request.setValue("Bearer \(bearerToken)", forHTTPHeaderField: "Authorization")
        }
        if let userAgent = userAgent {
            request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        }
        if let timeout = timeout {
            request.timeoutInterval = timeout
        }
        return request
    }

    static func formBody(_ fields: [String: String]) -> Data {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-._~"))
        let pairs = fields
            .sorted { $0.key < $1.key }
            .map { key, value in
                let encodedKey = key.addingPercentEncoding(withAllowedCharacters: allowed) ?? key
                let encodedValue = value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
                return "\(encodedKey)=\(encodedValue)"
            }
        return Data(pairs.joined(separator: "&").utf8)
    }
}
