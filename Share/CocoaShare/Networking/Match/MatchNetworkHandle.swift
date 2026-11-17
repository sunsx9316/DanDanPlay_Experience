//
//  MatchNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation
import ANXLog


/// 文件匹配模式
enum MatchMode: String {
    case hashAndFileName = "hashAndFileName"
    case fileNameOnly = "fileNameOnly"
    case hashOnly = "hashOnly"
}

class MatchNetworkHandle {
    
    /// 可取消的弹幕匹配请求。
    /// `MatchsViewController` 等旧调用方可以忽略返回值；在线播放前的弹幕选择窗口用它取消请求。
    final class MatchRequest {
        private let lock = NSLock()
        private var cancelHandler: (() -> Void)?
        private var cancelled = false

        fileprivate init() {}

        var isCancelled: Bool {
            lock.lock()
            defer { lock.unlock() }
            return cancelled
        }

        fileprivate func attachCancelHandler(_ handler: @escaping () -> Void) {
            var shouldCancelImmediately = false
            lock.lock()
            if cancelled {
                shouldCancelImmediately = true
            } else {
                cancelHandler = handler
            }
            lock.unlock()

            if shouldCancelImmediately {
                handler()
            }
        }

        func cancel() {
            let handler: (() -> Void)?
            lock.lock()
            guard !cancelled else {
                lock.unlock()
                return
            }
            cancelled = true
            handler = cancelHandler
            cancelHandler = nil
            lock.unlock()

            handler?()
        }

        fileprivate func finish() {
            lock.lock()
            cancelHandler = nil
            lock.unlock()
        }
    }

    /// 按文件名直接请求匹配结果（在线虚拟文件 / 用户修改关键词后重新搜索）。
    /// - Parameters:
    ///   - fileName: 用于匹配的虚拟文件名，不需要带扩展名
    ///   - matchMode: 匹配模式，默认 `.fileNameOnly`
    ///   - completion: 完成回调
    /// - Returns: 可取消的请求
    @discardableResult
    static func match(fileName: String,
                      matchMode: MatchMode = .fileNameOnly,
                      completion: @escaping((MatchCollection?, Error?) -> Void)) -> MatchRequest {
        var parameters = [String : String]()
        parameters["fileName"] = fileName
        parameters["fileHash"] = Self.emptyFileHash
        parameters["fileSize"] = "0"
        parameters["matchMode"] = matchMode.rawValue

        ANX.logInfo(.HTTP, "根据文件名匹配弹幕 请求参数: \(parameters)")

        let request = MatchRequest()
        let dataRequest = NetworkManager.shared.postOnBaseURL(additionUrl: "/match", parameters: parameters) { result in
            guard !request.isCancelled else { return }
            request.finish()

            switch result {
            case .success(let data):
                let result = Response<MatchCollection>(with: data)
                completion(result.result, result.error)
                ANX.logInfo(.HTTP, "根据文件名匹配弹幕 请求成功")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "根据文件名匹配弹幕 请求失败: \(error)")
            }
        }
        request.attachCancelHandler {
            dataRequest?.cancel()
        }
        return request
    }

    /// 匹配文件，当匹配结果为1时，则自动获取弹幕
    /// - Parameters:
    ///   - file: 文件
    ///   - progress: 当前进度
    ///   - matchCompletion: 当匹配结果 > 1时回调，不再继续往下走
    ///   - getDanmakuCompletion: 获取弹幕回调
    static func matchAndGetDanmakuWithFile(_ file: File,
                                           progress: LoadingProgressAction?,
                                           matchCompletion: @escaping((MatchCollection?, Error?) -> Void),
                                           getDanmakuCompletion: @escaping((CommentCollection?, _ matchInfo: Match, Error?) -> Void)) {
        
        ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 file: \(file)")
        
        self.match(with: file) { (progressValue) in
            progress?(.matchMedia(progress: 0.5 * progressValue))
        } completion: { (collection, error) in
            
            progress?(.matchMedia(progress: 1))
            
            if let error = error {
                matchCompletion(collection, error)
                return
            }
            
            //精确匹配
            if collection?.isMatched == true &&
                collection?.collection.count == 1 &&
                Preferences.shared.fastMatch {
                progress?(.downloadDanmaku)
                let matched = collection!.collection[0]
                
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 精确匹配 matched: \(matched)")
                
                CommentNetworkHandle.getDanmaku(with: matched.episodeId) { damakus, error in
                    getDanmakuCompletion(damakus, matched, error)
                }
            } else {
                
                matchCompletion(collection, error)
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 请求成功 collection数量: \(String(describing: collection?.collection.count))")
            }
        }
    }
    
    
    
    /// 空字符串的 MD5；在线/虚拟文件没有本地哈希时使用。
    static let emptyFileHash = "d41d8cd98f00b204e9800998ecf8427e"

    /// 根据文件请求匹配的结果
    /// - Parameters:
    ///   - file: 文件
    ///   - matchMode: 匹配模式
    ///   - parseDataProgress: 匹配进度
    ///   - completion: 完成回调
    static func match(with file: File,
                      matchMode: MatchMode = .hashAndFileName,
                      parseDataProgress: FileProgressAction? = nil,
                      completion: @escaping((MatchCollection?, Error?) -> Void)) {

        let requestMatchBlock: (String, String, Int, MatchMode, Bool) -> Void = { fileName, fileHash, fileSize, mode, cacheResult in

            var parameters = [String : String]()
            parameters["fileName"] = fileName
            parameters["fileHash"] = fileHash
            parameters["fileSize"] = "\(fileSize)"
            parameters["matchMode"] = mode.rawValue

            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求参数: \(parameters)")

            NetworkManager.shared.postOnBaseURL(additionUrl: "/match", parameters: parameters) { result in
                switch result {
                case .success(let data):
                    let result = Response<MatchCollection>(with: data)

                    let collection = result.result

                    /// 精确匹配，缓存结果；虚拟文件没有稳定哈希，不写入全局 hash 缓存。
                    if cacheResult,
                       collection?.isMatched == true,
                       collection?.collection.count == 1 {
                        CacheManager.shared.setMatchResultWithHash(fileHash, data: data)
                    }

                    completion(collection, result.error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求成功")
                case .failure(let error):
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求失败: \(error)")
                }
            }
        }

        // 在线/虚拟文件：用「作品名 + 剧集名」按文件名匹配，不读取本地哈希。
        // 对齐 Windows 版 LoadManager_Matching / MatchManager 的虚拟文件逻辑。
        if file.isVirtualFile {
            let fileName = file.danmakuMatchFileName ?? file.fileName
            ANX.logInfo(.HTTP, "根据虚拟文件匹配弹幕 fileName: \(fileName)")
            _ = self.match(fileName: fileName, matchMode: .fileNameOnly, completion: completion)
            return
        }

        if Preferences.shared.fastMatch,
           let hash = CacheManager.shared.matchHashWithFile(file) {
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 快速匹配 hash：\(hash)")

            if let data = CacheManager.shared.matchResultWithHash(hash) {
                let result = Response<MatchCollection>(with: data)

                completion(result.result, nil)
                ANX.logInfo(.HTTP, "根据缓存返回匹配的结果 请求成功")
            } else {
                requestMatchBlock(file.fileName, hash, file.fileSize, matchMode, true)
            }

        } else {
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 获取文件解析字节")
            file.getFileHashWithProgress(parseDataProgress) { result in
                switch result {
                case .failure(let error):
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 失败 error: \(error)")
                case .success(let hash):
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 成功 hash: \(hash)")
                    CacheManager.shared.setMatchHashWithFile(file, hash: hash)
                    requestMatchBlock(file.fileName, hash, file.fileSize, matchMode, true)
                }
            }
        }
    }
    
}
