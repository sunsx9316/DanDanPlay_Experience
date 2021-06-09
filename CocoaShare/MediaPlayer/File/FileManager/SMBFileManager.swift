//
//  SMBFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

import Foundation
import AMSMB2

class SMBFileManager: FileManagerProtocol {
    
    private enum SMBError: LocalizedError {
        case fileTypeError
        case listSharesError
        
        var errorDescription: String? {
            switch self {
            case .fileTypeError:
                return "文件类型错误"
            case .listSharesError:
                return "获取服务器共享列表失败"
            }
        }
    }
    
    static let shared = SMBFileManager()
    
    private init() {}
    
    private var client: AMSMB2?
    
    private(set) var loginInfo: LoginInfo?
    
    var desc: String {
        return "SMB"
    }
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        self.client?.disconnectShare()
        
        var credential: URLCredential?
        
        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }
        
        self.client = .init(url: loginInfo.url, credential: credential)
        self.client?.timeout = 5
        self.client?.listShares(enumerateHidden: true, completionHandler: { [weak self] result in
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
    
    func contentsOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        
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
                            let files = result.compactMap({ SMBFile(file: $0, shareName: path) }).filter({ !$0.fileName.hasPrefix(".") })
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
                            let files = result.compactMap({ SMBFile(file: $0, shareName: shareName) }).filter({ !$0.fileName.hasPrefix(".") })
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
            let newRange: Range<Int> = range.lowerBound..<range.upperBound
            self.client?.contents(atPath: file.path, range: newRange, progress: { (current, total) in
                progress?(Double(current) / Double(total))
                if current >= range.count {
                    return false
                }
                return true
            }, completionHandler: completion)
        } else {
            self.client?.contents(atPath: file.path, progress: { (_, _) in
                return true
            }, completionHandler: completion)
        }
    }
    
}
