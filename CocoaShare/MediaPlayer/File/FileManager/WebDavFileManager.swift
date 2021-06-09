//
//  WebDavFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation
import FilesProvider

class WebDavFileManager: FileManagerProtocol {
    
    private var client: WebDAVFileProvider?
    
    private(set) var loginInfo: LoginInfo?
    
    var desc: String {
        return NSLocalizedString("WebDav", comment: "")
    }
    
    var addressExampleDesc: String {
        return "服务器地址：http://example"
    }
    
    static let shared = WebDavFileManager()
    
    private init() {}
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        
        var credential: URLCredential?
        
        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }
        
        self.client = .init(baseURL: loginInfo.url, credential: credential)
        self.client?.isReachable(completionHandler: { [weak self] (isReachable, error) in
            
            guard let self = self else { return }
            
            if let error = error {
                completionHandler(error)
            } else {
                self.loginInfo = loginInfo
                completionHandler(nil)
            }
        })
    }
    
    func contentsOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        self.client?.contentsOfDirectory(path: directory.url.path, completionHandler: { files, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let tmpFiles = files.compactMap({ WebDavFile(with: $0) })
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
    
    
    
}
