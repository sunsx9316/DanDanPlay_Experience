//
//  FTPFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

import Foundation
import FilesProvider

class FTPFileManager: FileManagerProtocol {
    
    
    private var client: FTPFileProvider?
    
    private(set) var loginInfo: LoginInfo?
    
    var desc: String {
        return NSLocalizedString("FTP", comment: "")
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
    
    func contentsOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        
        self.client?.contentsOfDirectory(path: directory.url.path, completionHandler: { files, error in
            if let error = error {
                completion(.failure(error))
            } else {
                let tmpFiles = files.compactMap({ FTPFile(with: $0) })
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
