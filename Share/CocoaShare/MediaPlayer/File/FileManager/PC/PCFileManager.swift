//
//  PCFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/1.
//

import UIKit
import Alamofire

class PCFileManager: FileManagerProtocol {
    
    private enum PCError: LocalizedError {
        case needInputTokenError
        
        case fileTypeError
        
        var errorDescription: String? {
            switch self {
            case .needInputTokenError:
                return "请输入Token"
            case .fileTypeError:
                return "文件类型错误"
            }
        }
    }
    
    var desc: String {
        return NSLocalizedString("电脑端", comment: "")
    }
    
    var passwordDesc: String {
        return NSLocalizedString("登录Token", comment: "")
    }
    
    var addressExampleDesc: String {
        return "服务器地址：http://example"
    }
    
    var isRequiredUserName: Bool {
        return false
    }
    
    private(set) var loginInfo: LoginInfo?
    
    static let shared = PCFileManager()
    
    private lazy var defaultSession: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let manager = Alamofire.Session(configuration: configuration)
        return manager
    }()
    
    func contentsOfDirectory(at directory: File, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        let parameters: [String: String]? = nil
        
        let header = self.defualtHeader()
        
        self.defaultSession.request(self.appendingURL("/api/v1/library"), method: .get, parameters: parameters, encoder: JSONParameterEncoder.default, headers: header).responseData { response in
            switch response.result {
            case .success(let data):
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    if let asJSON = asJSON as? NSArray {
                        let libraryModel = [PCLibraryModel].deserialize(from: asJSON)
                        let files: [PCFile] = libraryModel?.compactMap({ obj in
                            if let obj = obj {
                                let f = PCFile(libraryModel: obj)
                                /// PC的远程登录只有一级目录，父文件夹设置成自己便于查找关联的字幕文件
                                f.parentFile = f
                                
                                if let filterType = filterType, f.type == .file {
                                    return f.url.isThisType(filterType) ? f : nil
                                }
                                
                                return f
                            }
                            return nil
                        }) ?? []
                        completion(.success(files))
                    } else {
                        completion(.success([PCFile]()))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
 
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        guard let file = file as? PCFile else {
            completion(.failure(PCError.fileTypeError))
            return
        }
        
        let parameters: [String: String]? = nil
        
        var header = self.defualtHeader()
        
        if let range = range {
            header.add(name: "Range", value: "bytes=\(range.lowerBound)-\(range.upperBound)")
        }
        
        self.defaultSession.request(file.downloadURL.absoluteString, method: .get, parameters: parameters, encoder: JSONParameterEncoder.default, headers: header).responseData { (response) in
            switch response.result {
            case .success(let data):
                completion(.success(data))
            case .failure(let error):
                completion(.failure(error))
            }
        }.downloadProgress { p in
            if let totalUnitCount = range?.upperBound, totalUnitCount > 0 {
                progress?(Double(p.completedUnitCount) / Double(totalUnitCount))
            } else {
                progress?(p.fractionCompleted)
            }
        }
        
    }
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping ((Error?) -> Void)) {
        self.loginInfo = loginInfo
        
        let parameters: [String: String]? = nil
        
        let header = self.defualtHeader()

        self.defaultSession.request(self.appendingURL("/api/v1/welcome"), method: .get, parameters: parameters, encoder: JSONParameterEncoder.default, headers: header).responseData { (response) in
            switch response.result {
            case .success(let data):
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    let result = Response<PCWelcomeModel>(with: asJSON)
                    let notInputToken = result.result?.tokenRequired == true && !(loginInfo.auth?.password?.isEmpty == false)
                    if notInputToken {
                        completionHandler(PCError.needInputTokenError)
                    } else {
                        completionHandler(result.error)
                    }
                } catch {
                    completionHandler(error)
                }
            case .failure(let error):
                completionHandler(error)
            }
        }
    }
    
    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        assert(false, "不支持删除")
    }
    
    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        assert(false, "不支持打开文件选择器")
    }
    
    func subtitlesOfMedia(_ file: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        guard let file = file as? PCFile else {
            completion(.failure(PCError.fileTypeError))
            return
        }
        
        let parameters: [String: String]? = nil
        
        let header = self.defualtHeader()
        
        self.defaultSession.request(self.appendingURL("/api/v1/subtitle/info/\(file.libraryModel?.id ?? "")"), method: .get, parameters: parameters, encoder: JSONParameterEncoder.default, headers: header).responseData { (response) in
            switch response.result {
            case .success(let data):
                
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    
                    if let result = PCSubtitleCollectionModel.deserialize(from: asJSON as? NSDictionary) {
                        completion(.success(result.subtitles.compactMap({ PCFile(subtitleModel: $0, media: file) })))
                    } else {
                        completion(.success([]))
                    }
                } catch {
                    completion(.failure(error))
                }
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    
    // MARK: Private Method
    private func appendingURL(_ path: String) -> String {
        if let url = self.loginInfo?.url {
            return url.appendingPathComponent(path).absoluteString
        }
        return path
    }
    
     private func defualtHeader() -> HTTPHeaders {
         var headers = HTTPHeaders()
         if let token = self.loginInfo?.auth?.password {
             headers.add(name: "Authorization", value: "Bearer \(token)")
         }
         return headers
    }

}
