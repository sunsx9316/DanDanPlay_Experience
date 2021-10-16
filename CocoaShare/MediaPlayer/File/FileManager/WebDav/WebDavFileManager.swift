//
//  WebDavFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation
import FilesProvider
import YYCategories

class WebDavFileManager: FileManagerProtocol {
    
    private lazy var client: AFWebDAVManager? = {
        
        guard let loginInfo = WebDavFileManager.loginInfo else { return nil }
        
        let client = self.createDefaultClient(with: loginInfo)
        return client
    }()
    
    private(set) var loginInfo: LoginInfo?
    
    var desc: String {
        return NSLocalizedString("WebDav", comment: "")
    }
    
    var addressExampleDesc: String {
        return "服务器地址：http://example"
    }
    
    static var loginInfo: LoginInfo?
    
    func cancelTasks() {
        self.client?.invalidateSessionCancelingTasks(true, resetSession: true)
    }
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        
        WebDavFileManager.loginInfo = loginInfo
        
        self.contentsOfDirectory(at: WebDavFile.rootFile) { [weak self] res in
            guard let self = self else { return }
            
            switch res {
            case .success(_):
                self.loginInfo = loginInfo
                completionHandler(nil)
            case .failure(let error):
                completionHandler(error)
            }
        }
    }
    
    func contentsOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        
        self.client?.contentsOfDirectory(atURLString: directory.url.absoluteString, recursive: false, completionHandler: { res, error in
            if let error = error {
                completion(.failure(error))
            } else {
                
                let directoryURL: URL?
                
                if !directory.url.absoluteString.hasSuffix("/") {
                    directoryURL = URL(string: directory.url.absoluteString + "/", relativeTo: self.client?.baseURL)
                } else {
                    directoryURL = URL(string: directory.url.absoluteString, relativeTo: self.client?.baseURL)
                }
                
                let tmpFiles = res?.filter({ response in
                    
                    guard let subUrl = response.url else { return false }
                    
                    let url: URL?
                    
                    if subUrl.absoluteString.hasSuffix("/") {
                        url = URL(string: subUrl.absoluteString, relativeTo: self.client?.baseURL)
                    } else {
                        url = URL(string: subUrl.absoluteString + "/", relativeTo: self.client?.baseURL)
                    }
                    
                    return directoryURL != url
                }).compactMap({ WebDavFile(with: $0) }) ?? []
                
                completion(.success(tmpFiles))
            }
        })
    }
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        guard let url = URL(string: file.url.absoluteString, relativeTo: self.client?.baseURL) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        if let range = range {
            request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
        }
        
        self.client?.dataTask(with: request, uploadProgress: nil, downloadProgress: { p in
            progress?(p.fractionCompleted)
        }, completionHandler: { _, data, error in
            if let error = error {
                completion(.failure(error))
            } else if let data = data as? Data {
                completion(.success(data))
            }
        }).resume()
    }
    
    func getFileSize(_ file: File, completion: @escaping ((Result<Int, Error>) -> Void)) {
        guard let url = URL(string: file.url.absoluteString, relativeTo: self.client?.baseURL) else {
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("bytes=0-1024", forHTTPHeaderField: "Range")
        
        self.client?.dataTask(with: request, uploadProgress: nil, downloadProgress: nil, completionHandler: { res, data, error in
            if let error = error {
                completion(.failure(error))
            } else if let res = res as? HTTPURLResponse {
                if let contentRange = res.allHeaderFields["Content-Range"] as? String,
                   let fileLengthString = contentRange.components(separatedBy: "/").last {
                    let fileLength = Int(fileLengthString) ?? 0
                    completion(.success(fileLength))
                } else {
                    completion(.failure(URLError(.zeroByteResource)))
                }
            }
        }).resume()
    }
 
    //MARK: - private method
    private func createDefaultClient(with loginInfo: LoginInfo) -> AFWebDAVManager {
        
        var credential: URLCredential?
        
        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }
        
        let client = AFWebDAVManager(baseURL: loginInfo.url)
        client.setAuthenticationChallengeHandler({ [weak self] session, task, challenge, completionHandler in
            
            guard self != nil else {
                return NSNumber(value: URLSession.AuthChallengeDisposition.performDefaultHandling.rawValue)
            }
            
            if challenge.previousFailureCount > 0 {
                return NSNumber(value:URLSession.AuthChallengeDisposition.performDefaultHandling.rawValue)
            }
            
            if let credential = credential {
                return credential
            }
            
            return NSNumber(value:URLSession.AuthChallengeDisposition.performDefaultHandling.rawValue)
        })
        
        return client
    }
}
