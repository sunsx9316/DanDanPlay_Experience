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
        case reqError
        
        var errorDescription: String? {
            switch self {
            case .fileTypeError:
                return "文件类型错误"
            case .reqError:
                return "请求失败"
            }
        }
    }
    
    private var progressObj: Progress?
    
    private var progressObs: NSKeyValueObservation?
    
    private var client: WebDAVFileProvider?
    
    private var loginInfo: LoginInfo?
    
    var desc: String {
        return NSLocalizedString("WebDav", comment: "")
    }
    
    var addressExampleDesc: String {
        return "服务器地址：http://example:1234"
    }
    
    
    func cancelTasks() {
        ANX.logInfo(.webDav, "cancelTasks")
        self.client = nil
    }
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void)) {
        ANX.logInfo(.webDav, "登录 loginInfo: %@", "\(loginInfo)")
        
        self.loginInfo = loginInfo

        var credential: URLCredential?
        if let auth = loginInfo.auth {
            credential = .init(user: auth.userName ?? "", password: auth.password ?? "", persistence: .forSession)
        }
        self.client = .init(baseURL: loginInfo.url, credential: credential)
        
        let rootFile: File
        if let webDavRootPath = loginInfo.parameter?[LoginInfo.Key.webDavRootPath.rawValue], !webDavRootPath.isEmpty {
            rootFile = WebDavFile(url: URL(string: webDavRootPath)!, fileSize: 0)
        } else {
            rootFile = WebDavFile.rootFile
        }
        
        self.contentsOfDirectory(at: rootFile, filterType: nil) { [weak self] res in
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
    
    
    func contentsOfDirectory(at directory: File, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        
        guard let directory = directory as? WebDavFile else {
            completion(.failure(WebDavError.fileTypeError))
            return
        }
        
        self.client?.contentsOfDirectory(path: directory.path, completionHandler: { files, error in
            if let error = error {
                completion(.failure(error))
                ANX.logError(.webDav, "contentsOfDirectory error: %@", error as NSError)
            } else {
                let tmpFiles = files.compactMap { e in
                    let f = WebDavFile(with: e)
                    f.parentFile = directory
                    
                    if let filterType = filterType, f.type == .file {
                        return f.url.isThisType(filterType) ? f : nil
                    }
                    
                    return f
                }
                ANX.logInfo(.webDav, "directoryURL: %@, tmpFileslCount: %ld", String(describing: directory.url), tmpFiles.count)
                completion(.success(tmpFiles))
            }
        })
    }
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        guard let file = file as? WebDavFile else {
            assert(false, "文件类型错误: \(file)")
            completion(.failure(WebDavError.fileTypeError))
            return
        }
        
        var offset: Int64 = 0
        var length: Int = -1
        
        if let range = range {
            offset = Int64(range.lowerBound)
            length = range.count
        }
        
        
        self.progressObj = self.client?.contents(path: file.path, offset: offset, length: length, completionHandler: { [weak self] contents, error in
            self?.progressObs = nil
            self?.progressObj = nil
            
            if let error = error {
                completion(.failure(error))
            } else if let contents = contents {
                try? contents.write(to: UIApplication.shared.documentsURL.appendingPathComponent("new.data"))
                completion(.success(contents))
            } else {
                completion(.failure(WebDavError.reqError))
            }
        })
        
        self.progressObs = self.progressObj?.observe(\.fractionCompleted, options: [.new], changeHandler: { _, value in
            progress?(value.newValue ?? 0)
        })
    }
    
    func getFileSize(_ file: File, completion: @escaping ((Result<Int, Error>) -> Void)) {
        guard let file = file as? WebDavFile else {
            assert(false, "文件类型错误: \(file)")
            completion(.failure(WebDavError.fileTypeError))
            return
        }
        
        self.client?.attributesOfItem(path: file.path, completionHandler: { attributes, error in
            if let error = error {
                ANX.logError(.webDav, "getFileSize 请求失败 error: %@", error as NSError)
                completion(.failure(error))
                ANX.logError(.webDav, "getFileSize 请求失败 error: \(error)")
            } else if let attributes = attributes {
                completion(.success(Int(attributes.size)))
                ANX.logInfo(.webDav, "getFileSize 请求成功 fileLength: %ld", attributes.size)
            }
        })
    }
    
    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        guard file.isCanDelete else {
            assert(false, "文件类型错误: \(file)")
            ANX.logError(.webDav, "deleteFile 文件类型错误: %@", "\(file)")
            completionHandler(WebDavError.fileTypeError)
            return
        }
        
        self.client?.removeItem(path: file.url.path, completionHandler: completionHandler)
    }
 
    //MARK: - private method
    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        assert(false)
    }
}

#endif
