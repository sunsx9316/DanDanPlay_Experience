//
//  AISummaryService.swift
//  AniXPlayer
//
//  macOS only：`POST /api/v2/ai/summary`。
//
//  AI 生成可能持续 1-2 分钟，因此使用独立的长超时 URLSession，
//  不修改 APIClient 的全局 20 秒默认值。
//

import Foundation
import ANXLog

enum AISummaryError: LocalizedError {
    case invalidURL
    case contentFilter
    case membershipRequired
    case quotaExhausted
    case unauthorized
    case invalidResponse
    case emptySummary
    case server(code: Int, message: String?)

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return NSLocalizedString("请求地址无效", comment: "")
        case .contentFilter:
            return NSLocalizedString(
                "字幕中包含了敏感词汇，AI 无法为您生成视频总结。请检查字幕内容，或者尝试使用其他字幕。",
                comment: ""
            )
        case .membershipRequired:
            return NSLocalizedString("AI 视频总结是弹弹play会员功能，请开通会员后使用。", comment: "")
        case .quotaExhausted:
            return NSLocalizedString("本月 AI 视频总结额度已用完，请下月再试。", comment: "")
        case .unauthorized:
            return NSLocalizedString("登录已过期，请重新登录", comment: "")
        case .invalidResponse:
            return NSLocalizedString("服务返回的数据无法解析", comment: "")
        case .emptySummary:
            return NSLocalizedString("AI 没有返回可用的总结内容，请尝试使用其他字幕。", comment: "")
        case .server(let code, let message):
            if let message = message?.trimmingCharacters(in: .whitespacesAndNewlines), !message.isEmpty {
                return message
            }
            return String(
                format: NSLocalizedString("生成视频总结失败，错误代码：%d", comment: ""),
                code
            )
        }
    }
}

final class AISummaryService {
    /// 至少 120 秒；服务端通常需要 1-2 分钟。
    static let requestTimeout: TimeInterval = 180
    static let resourceTimeout: TimeInterval = 240

    private let environment: APIEnvironment
    private let api: AuthenticatedAPIClient
    private let decoder = JSONDecoder()

    init(
        environment: APIEnvironment = .current(),
        client: APIClient? = nil,
        session: SessionStore = .shared
    ) {
        self.environment = environment
        self.api = AuthenticatedAPIClient(
            client: client ?? Self.makeLongRunningClient(),
            tokenProvider: { try await session.validAccessToken() },
            refreshHandler: { try await session.forceRefresh().accessToken }
        )
    }

    /// 独立 session：请求超时 180s、资源超时 240s。
    static func makeLongRunningClient() -> APIClient {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = requestTimeout
        configuration.timeoutIntervalForResource = resourceTimeout
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return APIClient(session: URLSession(configuration: configuration))
    }

    func generateSummary(for summaryRequest: SummaryVideoRequest) async throws -> SummaryVideoResponse {
        guard let url = environment.makeURL("/ai/summary") else {
            throw AISummaryError.invalidURL
        }

        let body: Data
        do {
            body = try JSONEncoder().encode(summaryRequest)
        } catch {
            throw AISummaryError.invalidResponse
        }

        let request = APIClient.jsonRequest(
            url: url,
            method: .post,
            body: body,
            userAgent: environment.userAgent,
            timeout: Self.requestTimeout
        )

        ANX.logInfo(
            .HTTP,
            "[Summary] 请求 AI 视频总结，字幕条数：\(summaryRequest.transcriptions.count)，文件：\(summaryRequest.fileName)"
        )

        let data: Data
        do {
            data = try await api.send(request)
        } catch let error as APIError {
            ANX.logError(.HTTP, "[Summary] AI 视频总结请求失败：\(error)")
            if error.isUnauthorized {
                throw AISummaryError.unauthorized
            }
            throw error
        }

        let response: SummaryVideoResponse
        do {
            response = try decoder.decode(SummaryVideoResponse.self, from: data)
        } catch {
            ANX.logError(.HTTP, "[Summary] AI 视频总结响应解析失败：\(error)")
            throw AISummaryError.invalidResponse
        }

        guard response.isSuccess else {
            let mapped = Self.error(from: response)
            ANX.logError(
                .HTTP,
                "[Summary] AI 视频总结失败，errorCode：\(response.errorCode ?? -1)，message：\(response.errorMessage ?? "")"
            )
            throw mapped
        }

        guard response.hasContent else {
            throw AISummaryError.emptySummary
        }

        ANX.logInfo(
            .HTTP,
            "[Summary] AI 视频总结成功，summaryId：\(response.summaryId ?? 0)，usage：\(response.usage ?? 0)，remain：\(response.countRemain ?? 0)"
        )
        return response
    }

    static func error(from response: SummaryVideoResponse) -> AISummaryError {
        switch response.errorCode {
        case 8:
            return .membershipRequired
        case 11:
            return .unauthorized
        case 61:
            return .quotaExhausted
        case 62:
            return .contentFilter
        default:
            return .server(code: response.errorCode ?? -1, message: response.errorMessage)
        }
    }
}
