//
//  SMBFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

#if os(iOS) || os(tvOS)

import Foundation
import AMSMB2
import GCDWebServer
#if !os(tvOS)
import ANXLog
#endif

class SMBFileManager: FileManagerProtocol {

    private enum SMBError: LocalizedError {
        case fileTypeError
        case listSharesError
        case initError

        var errorDescription: String? {
            switch self {
            case .fileTypeError:
                return "文件类型错误"
            case .listSharesError:
                return "获取服务器共享列表失败"
            case .initError:
                return "初始化 SMB 客户端失败"
            }
        }
    }

    static let shared = SMBFileManager()

    private init() {
        // Debug 模式下 GCDWebServer 默认 log level 为 DEBUG，会产生大量日志，设为 INFO 抑制
        GCDWebServer.setLogLevel(2)
    }

    private var client: SMB2Manager?

    private(set) var loginInfo: LoginInfo?

    private let streamServer = GCDWebServer()
    private var streamPath: String?
    private var streamFileSize: Int64 = 0
    private let streamLock = NSLock()

    var desc: String {
        return NSLocalizedString("SMB", comment: "")
    }

    var addressExampleDesc: String {
        return "服务器地址：smb://example"
    }

    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        self.client?.disconnectShare()

        var credential: URLCredential?

        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }

        guard let client = SMB2Manager(url: loginInfo.url, credential: credential) else {
            completionHandler(SMBError.initError)
            return
        }
        self.client = client
        client.timeout = 5
        client.listShares(enumerateHidden: true, completionHandler: { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let shares):
                debugPrint("smbshares: \(shares)")
                if shares.isEmpty {
                    completionHandler(SMBError.listSharesError)
                } else {
                    self.loginInfo = loginInfo
                    completionHandler(nil)
                }
            case .failure(let error):
                completionHandler(error)
            }
        })
    }

    func contentsOfDirectory(at directory: File, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        guard let directory = directory as? SMBFile else {
            assert(false, "文件类型错误: \(directory)")
            completion(.failure(SMBError.fileTypeError))
            return
        }

        switch directory.pathType {
        case .root:
            self.client?.listShares(completionHandler: { result in
                switch result {
                case .success(let shares):
                    let files = shares.compactMap({ SMBFile(shareName: $0.name) })
                    completion(.success(files))
                case .failure(let error):
                    completion(.failure(error))
                }
            })
        case .share:
            let path = directory.path
            self.client?.connectShare(name: path, completionHandler: { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                } else {
                    self.client?.contentsOfDirectory(atPath: "", completionHandler: { res in
                        switch res {
                        case .success(let result):
                            //过滤隐藏文件
                            let files = result.compactMap({ obj in
                                let f = SMBFile(file: obj, shareName: path)
                                if let filterType = filterType, f.type == .file {
                                    return f.url.isThisType(filterType) ? f : nil
                                }
                                return f
                            }).filter({ !$0.fileName.hasPrefix(".") })

                            completion(.success(files))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    })
                }
            })
        case .normal:
            let path = directory.path
            let shareName = directory.shareName
            self.client?.connectShare(name: shareName, completionHandler: { [weak self] error in
                guard let self = self else { return }

                if let error = error {
                    completion(.failure(error))
                } else {
                    self.client?.contentsOfDirectory(atPath: path, completionHandler: { res in
                        switch res {
                        case .success(let result):
                            //过滤隐藏文件
                            let files = result.compactMap({ obj in
                                let f = SMBFile(file: obj, shareName: shareName)
                                if let filterType = filterType, f.type == .file {
                                    return f.url.isThisType(filterType) ? f : nil
                                }
                                return f
                            }).filter({ !$0.fileName.hasPrefix(".") })

                            completion(.success(files))
                        case .failure(let error):
                            completion(.failure(error))
                        }
                    })
                }
            })
        }
    }

    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {

        guard let file = file as? SMBFile else {
            assert(false, "文件类型错误: \(file)")
            completion(.failure(SMBError.fileTypeError))
            return
        }

        if let range = range {
            let newRange: Range<Int64> = Int64(range.lowerBound)..<Int64(range.upperBound)
            self.client?.contents(atPath: file.path, range: newRange, progress: { (current, total) in
                progress?(Double(current) / Double(total))
                if current >= range.count {
                    return false
                }
                return true
            }, completionHandler: { result in
                completion(result)
            })
        } else {
            self.client?.contents(atPath: file.path, progress: { (_, _) in
                return true
            }, completionHandler: { result in
                completion(result)
            })
        }
    }

    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        guard let file = file as? SMBFile, file.isCanDelete else {
            assert(false, "文件类型错误: \(file)")
            completionHandler(SMBError.fileTypeError)
            return
        }

        self.client?.removeItem(atPath: file.path, completionHandler: { error in
            completionHandler(error)
        })
    }

    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        assert(false)
    }
}

// MARK: - SMB 流式代理（mpv-lgpl 不支持 smb:// 协议）

extension SMBFileManager {

    private final class StreamState {
        var currentOffset: UInt64
        var bytesRemaining: UInt64

        init(currentOffset: UInt64, bytesRemaining: UInt64) {
            self.currentOffset = currentOffset
            self.bytesRemaining = bytesRemaining
        }
    }

    func streamURL(for path: String, fileSize: Int64) -> URL? {
        streamLock.lock()
        defer { streamLock.unlock() }

        guard client != nil else {
            ANX.logError(.SMB, "[SMB] 流式代理：SMB 客户端未连接")
            return nil
        }

        if !streamServer.isRunning {
            streamServer.addHandler(
                forMethod: "GET",
                path: "/stream",
                request: GCDWebServerRequest.self
            ) { [weak self] request, completion in
                self?.handleStreamRequest(request, completion: completion)
            }

            if streamServer.start(withPort: 0, bonjourName: nil) {
                ANX.logInfo(.SMB, "[SMB] 流式代理启动: \(streamServer.serverURL?.absoluteString ?? "unknown")")
            } else {
                ANX.logError(.SMB, "[SMB] 流式代理启动失败")
                return nil
            }
        }

        streamPath = path
        streamFileSize = fileSize
        ANX.logInfo(.SMB, "[SMB] 注册流: \(path), 大小: \(fileSize)")
        return streamServer.serverURL?.appendingPathComponent("stream")
    }

    func stopStreaming() {
        streamLock.lock()
        streamPath = nil
        streamFileSize = 0
        streamLock.unlock()
    }

    private func handleStreamRequest(
        _ request: GCDWebServerRequest,
        completion: @escaping (GCDWebServerResponse?) -> Void
    ) {
        streamLock.lock()
        guard let path = streamPath, let client = client else {
            streamLock.unlock()
            completion(GCDWebServerResponse(statusCode: 404))
            return
        }
        let fileSize = streamFileSize
        streamLock.unlock()

        let hasKnownSize = fileSize > 0
        let fileSizeUInt = hasKnownSize ? UInt64(fileSize) : UInt64(0)

        let byteRange = request.byteRange
        let hasRange = hasKnownSize && request.hasByteRange()

        let startOffset: UInt64
        var totalLength: UInt64

        if hasRange {
            startOffset = UInt64(byteRange.location)
            if byteRange.length > 0 {
                totalLength = UInt64(byteRange.length)
            } else {
                totalLength = fileSizeUInt - startOffset
            }
            if totalLength > fileSizeUInt {
                totalLength = fileSizeUInt
            }
        } else {
            startOffset = 0
            totalLength = hasKnownSize ? fileSizeUInt : UInt64.max
        }

        let state = StreamState(currentOffset: startOffset, bytesRemaining: totalLength)

        let response = GCDWebServerStreamedResponse(contentType: "application/octet-stream") { completionBlock in
            guard state.bytesRemaining > 0 else {
                completionBlock(Data(), nil)
                return
            }

            let readSize: UInt64 = min(1_048_576, state.bytesRemaining)
            let rangeEnd = state.currentOffset + readSize

            client.contents(
                atPath: path,
                range: state.currentOffset..<rangeEnd,
                progress: nil
            ) { result in
                switch result {
                case .success(let data):
                    if data.isEmpty {
                        completionBlock(Data(), nil)
                    } else {
                        state.currentOffset += UInt64(data.count)
                        if hasKnownSize {
                            state.bytesRemaining -= UInt64(data.count)
                        }
                        completionBlock(data, nil)
                    }
                case .failure(let error):
                    ANX.logError(.SMB, "[SMB] 流式读取失败: \(error)")
                    completionBlock(nil, error as NSError)
                }
            }
        }

        response.setValue("bytes", forAdditionalHeader: "Accept-Ranges")
        if hasRange {
            response.statusCode = 206
            let rangeEnd = startOffset + totalLength - 1
            response.setValue("bytes \(startOffset)-\(rangeEnd)/\(fileSizeUInt)", forAdditionalHeader: "Content-Range")
            response.contentLength = UInt(totalLength)
        } else if hasKnownSize {
            response.contentLength = UInt(fileSizeUInt)
        } else {
            response.contentLength = UInt.max
        }

        completion(response)
    }
}

#endif
