//
//  WebDavFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

#if os(iOS)

import Foundation
import FilesProvider
import YYCategories
import ANXLog

class WebDavFileManager: FileManagerProtocol {
    
    static let shared = WebDavFileManager()
    
    init() {}
    
    private enum WebDavError: LocalizedError {
        case fileTypeError
        
        var errorDescription: String? {
            switch self {
            case .fileTypeError:
                return "文件类型错误"
            }
        }
    }
    
    private var client: AFWebDAVManager?
    
    private var listClient: WebDAVFileProvider?
    
    private var loginInfo: LoginInfo?
    
    var desc: String {
        return NSLocalizedString("WebDav", comment: "")
    }
    
    var addressExampleDesc: String {
        return "服务器地址：http://example"
    }
    
    
    func cancelTasks() {
        ANX.logInfo(.webDav, "cancelTasks")
        self.client?.invalidateSessionCancelingTasks(true, resetSession: true)
        self.listClient = nil
    }
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        ANX.logInfo(.webDav, "登录 loginInfo: %@", "\(loginInfo)")
        
        self.loginInfo = loginInfo
        
        self.client = self.createDefaultClient(with: loginInfo)

        var credential: URLCredential?
        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }
        self.listClient = .init(baseURL: loginInfo.url, credential: credential)
        
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
        
        self.listClient?.contentsOfDirectory(path: directory.url.path, completionHandler: { files, error in
            if let error = error {
                completion(.failure(error))
                ANX.logError(.webDav, "contentsOfDirectory error: %@", error as NSError)
            } else {
                let tmpFiles = files.compactMap { e in
                    let f = WebDavFile(with: e)
                    f.parentFile = directory
                    return f
                }
                ANX.logInfo(.webDav, "directoryURL: %@, tmpFileslCount: %ld", String(describing: directory.url), tmpFiles.count)
                completion(.success(tmpFiles))
            }
        })
    }
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        guard let url = URL(string: file.url.absoluteString, relativeTo: self.client?.baseURL) else {
            ANX.logError(.webDav, "getDataWithFile URL生成失败 fileUrl: %@, relativeTo: %@", String(describing: file.url.absoluteString), String(describing: self.client?.baseURL))
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
                ANX.logError(.webDav, "getDataWithFile请求失败 error: %@", error as NSError)
                completion(.failure(error))
            } else if let data = data as? Data {
                completion(.success(data))
            }
        }).resume()
    }
    
    func getFileSize(_ file: File, completion: @escaping ((Result<Int, Error>) -> Void)) {
        guard let url = URL(string: file.url.absoluteString, relativeTo: self.client?.baseURL) else {
            ANX.logError(.webDav, "getFileSize URL生成失败 fileUrl: %@, relativeTo: %@", String(describing: file.url.absoluteString), String(describing: self.client?.baseURL))
            
            completion(.failure(URLError(.badURL)))
            return
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 60
        request.setValue("bytes=0-1024", forHTTPHeaderField: "Range")
        
        self.client?.dataTask(with: request, uploadProgress: nil, downloadProgress: nil, completionHandler: { res, data, error in
            if let error = error {
                ANX.logError(.webDav, "getFileSize 请求失败 error: %@", error as NSError)
                completion(.failure(error))
            } else if let res = res as? HTTPURLResponse {
                if let contentRange = res.allHeaderFields["Content-Range"] as? String,
                   let fileLengthString = contentRange.components(separatedBy: "/").last {
                    let fileLength = Int(fileLengthString) ?? 0
                    completion(.success(fileLength))
                    ANX.logInfo(.webDav, "getFileSize 请求成功 fileLength: %ld", fileLength)
                } else {
                    completion(.failure(URLError(.zeroByteResource)))
                    ANX.logError(.webDav, "getFileSize 请求失败 allHeaderFields: %@", res.allHeaderFields)
                }
            }
        }).resume()
    }
    
    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        guard file.isCanDelete else {
            assert(false, "文件类型错误: \(file)")
            ANX.logError(.webDav, "deleteFile 文件类型错误: %@", "\(file)")
            completionHandler(WebDavError.fileTypeError)
            return
        }
        
        self.listClient?.removeItem(path: file.url.path, completionHandler: completionHandler)
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
    
    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        assert(false)
    }
}

#endif
