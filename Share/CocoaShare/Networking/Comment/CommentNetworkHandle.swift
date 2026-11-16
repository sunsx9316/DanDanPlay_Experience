//
//  CommentNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation
import ANXLog
import YYCategories


/// 语言转换枚举
enum LanConvert: Int {
    /// 不转化
    case noCover = 0
    /// 转为简体
    case toSimplified = 1
    
    /// 转为繁体
    case toTraditional
}

class CommentNetworkHandle {

    /// 根据文件获取弹幕
    /// - Parameters:
    ///   - episodeId: 剧集id
    ///   - from: 起始弹幕编号，忽略此编号以前的弹幕。默认值为0
    ///   - withRelated: 是否同时获取关联的第三方弹幕。默认值为true
    ///   - lanConvert: 中文简繁转换
    ///   - forceRefresh: 跳过本地缓存，强制重新请求（用于会员补充弹幕）
    ///   - completion: 完成回调
    static func getDanmaku(with episodeId: Int,
                           from: Int? = nil,
                           withRelated: Bool = true,
                           lanConvert: LanConvert? = nil,
                           forceRefresh: Bool = false,
                           completion: @escaping((CommentCollection?, Error?) -> Void)) {

        var parameters = [String : String]()
        parameters["withRelated"] = withRelated ? "true" : "false"

        if let from = from {
            parameters["from"] = "\(from)"
        }

        if let lanConvert = lanConvert {
            parameters["chConvert"] = "\(lanConvert.rawValue)"
        }

        let md5Str = ("\(parameters)" as NSString).md5() ?? ""
        if !forceRefresh,
           let data = CacheManager.shared.danmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str) {
            ANX.logInfo(.HTTP, "根据文件下载弹幕 匹配到缓存 episodeId: \(episodeId) md5Str: \(md5Str)")
            let result = Response<CommentCollection>(with: data)
            completion(result.result, nil)
            return
        }

        ANX.logInfo(.HTTP, "根据文件下载弹幕 请求 parameters: \(parameters)")

        NetworkManager.shared.getOnBaseURL(additionUrl: "/comment/\(episodeId)", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let result = Response<CommentCollection>(with: data)
                if result.error == nil {
                    CacheManager.shared.setDanmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str, data: data)
                }
                completion(result.result, result.error)
                ANX.logInfo(.HTTP, "根据文件下载弹幕 请求成功")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "根据文件下载弹幕 请求失败: \(error)")
            }
        }
    }

    /// 发送弹幕
    /// - Parameters:
    ///   - episodeId: 弹幕库ID
    ///   - request: 弹幕内容
    ///   - completion: 完成回调
    static func sendComment(episodeId: Int,
                            comment: Comment,
                            completion: @escaping((SendCommentResponse?, Error?) -> Void)) {
        ANX.logInfo(.HTTP, "发送弹幕 episodeId: \(episodeId), request: \(comment)")
        
#if os(macOS)
        Task {
            do {
                let response = try await sendComment(episodeId: episodeId, comment: comment)
                completion(response, nil)
                ANX.logInfo(.HTTP, "发送弹幕 请求成功, result: \(String(describing: response))")
            } catch {
                completion(nil, error)
                ANX.logInfo(.HTTP, "发送弹幕 请求失败: \(error)")
            }
        }
#else
        var parameters = [String: String]()
        parameters["time"] = "\(comment.time)"
        parameters["mode"] = "\(comment.mode.rawValue)"
        parameters["color"] = "\(comment.color.anxRgbValue)"
        parameters["comment"] = "\(comment.message)"

        NetworkManager.shared.postOnBaseURL(additionUrl: "/comment/\(episodeId)", parameters: parameters) { result in
            switch result {
            case .success(let data):
                let response = Response<SendCommentResponse>(with: data)
                completion(response.result, response.error)
                ANX.logInfo(.HTTP, "发送弹幕 请求成功, result: \(String(describing: response.result))")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "发送弹幕 请求失败: \(error)")
            }
        }
#endif
    }

#if os(macOS)
    /// macOS：走 Bearer + 401 单次刷新；服务端明确失败时返回可展示的错误。
    private static func sendComment(episodeId: Int, comment: Comment) async throws -> SendCommentResponse {
        let environment = APIEnvironment.current()
        guard let url = environment.makeURL("/comment/\(episodeId)") else {
            throw APIError.invalidURL
        }

        let parameters = [
            "time": "\(comment.time)",
            "mode": "\(comment.mode.rawValue)",
            "color": "\(comment.color.anxRgbValue)",
            "comment": comment.message,
        ]
        let body = try JSONEncoder().encode(parameters)
        let request = APIClient.jsonRequest(
            url: url,
            method: .post,
            body: body,
            userAgent: environment.userAgent,
            timeout: environment.timeout
        )

        let data = try await AuthenticatedAPIClient().send(request)
        let response = try JSONDecoder().decode(SendCommentResponse.self, from: data)
        if let cid = response.cid, cid > 0 {
            return response
        }

        let errorResponse = try? JSONDecoder().decode(SendCommentErrorResponse.self, from: data)
        if let errorResponse = errorResponse, !errorResponse.success {
            throw CommentSendError.server(errorResponse.errorMessage)
        }
        throw CommentSendError.server(NSLocalizedString("发送失败", comment: ""))
    }
#endif
}

#if os(macOS)
private struct SendCommentErrorResponse: Decodable {
    let success: Bool
    let errorMessage: String

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        success = (try? container.decodeIfPresent(Bool.self, forKey: .success)) ?? true
        errorMessage = (try? container.decodeIfPresent(String.self, forKey: .errorMessage)) ?? ""
    }

    private enum CodingKeys: String, CodingKey {
        case success, errorMessage
    }
}

private enum CommentSendError: LocalizedError {
    case server(String)

    var errorDescription: String? {
        switch self {
        case .server(let message):
            return message.isEmpty ? NSLocalizedString("发送失败", comment: "") : message
        }
    }
}
#endif
