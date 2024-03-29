//
//  FTPFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

#if os(iOS)

import Foundation
import FilesProvider

class FTPFileManager: FileManagerProtocol {
    
    private enum FTPError: LocalizedError {
        case fileTypeError
        
        var errorDescription: String? {
            switch self {
            case .fileTypeError:
                return "文件类型错误"
            }
        }
    }
    
    private var client: FTPFileProvider?
    
    private(set) var loginInfo: LoginInfo?
    
    var desc: String {
        return NSLocalizedString("FTP", comment: "")
    }
    
    var addressExampleDesc: String {
        return "服务器地址：ftp://example"
    }
    
    static let shared = FTPFileManager()
    
    private init() {}
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        
        var credential: URLCredential?
        
        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }
        
        self.client = .init(baseURL: loginInfo.url, mode: .passive, credential: credential)
        self.client?.contentsOfDirectory(path: "/", completionHandler: { [weak self] files, error in
            
            guard let self = self else { return }
            
            if let error = error {
                completionHandler(error)
            } else {
                self.loginInfo = loginInfo
                completionHandler(nil)
            }
        })
    }
    
    func contentsOfDirectory(at directory: File, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        self.client?.contentsOfDirectory(path: directory.url.path, completionHandler: { files, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let tmpFiles = files.compactMap { obj in
                    let f = FTPFile(with: obj)
                    if let filterType = filterType, f.type == .file {
                        return f.url.isThisType(filterType) ? f : nil
                    }
                    return f
                }
                completion(.success(tmpFiles))
            }
        })
    }
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        if let range = range {
            let offset = Int64(range.lowerBound)
            let length = range.upperBound - range.lowerBound + 1
            
            self.client?.contents(path: file.url.path, offset: offset, length: length, completionHandler: { data, error in
                if let error = error {
                    completion(.failure(error))
                } else if let data = data {
                    completion(.success(data))
                }
            })
        } else {
            self.client?.contents(path: file.url.path, completionHandler: { data, error in
                if let error = error {
                    completion(.failure(error))
                } else if let data = data {
                    completion(.success(data))
                }
            })
        }
    }
    
    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        guard file.isCanDelete else {
            assert(false, "文件类型错误: \(file)")
            completionHandler(FTPError.fileTypeError)
            return
        }
        
        self.client?.removeItem(path: file.url.path, completionHandler: completionHandler)
    }
    
    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        assert(false)
    }
}

#endif
