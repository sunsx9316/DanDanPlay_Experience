//
//  PCFileManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/1.
//

#if os(iOS)

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
        
        guard let directory = directory as? PCFile else {
            completion(.failure(PCError.fileTypeError))
            return
        }
        
        let group = DispatchGroup()
        
        var files = [File]()
        var error: Error?
        
        /// 请求视频
        if filterType == nil || filterType?.contains(.video) == true {
            
            group.enter()
            
            let parameters: [String: String]? = nil
            
            let header = self.defualtHeader()
            
            self.defaultSession.request(self.appendingURL("/api/v1/library"), method: .get, parameters: parameters, encoder: JSONParameterEncoder.default, headers: header).responseData { response in
                switch response.result {
                case .success(let data):
                    do {
                        
                        let decoder = JSONDecoder()
                        
                        let libraryModels = try decoder.decode([PCLibraryModel].self, from: data)
                        
                        var fileDic = [Int: PCFile]()
                        /// 根目录展示文件夹
                        if directory.url == PCFile.rootFile.url {
                            
                            for model in libraryModels {
                                var parentFile: PCFile
                                
                                if let tmpParentFile = fileDic[model.animeId]    {
                                    parentFile = tmpParentFile
                                } else {
                                    parentFile = .init(animeId: model.animeId, animeName: model.animeTitle)
                                    fileDic[model.animeId] = parentFile
                                }
                            }
                            
                            files.append(contentsOf: Array<PCFile>(fileDic.values))
                            /// 子目录展示番剧
                        } else {
                            let tmpFiles = libraryModels.compactMap({ obj in
                                let f = PCFile(libraryModel: obj)
                                /// PC的远程登录只有一级目录，父文件夹设置成自己便于查找关联的字幕文件
                                f.parentFile = f
                                
                                if let filterType = filterType,
                                   f.type == .file,
                                   f.url.isThisType(filterType),
                                   f.animeId == directory.animeId {
                                    return f
                                }
                                return nil
                            })
                            
                            files.append(contentsOf: tmpFiles)
                        }
                    } catch (let err) {
                        error = err
                    }
                case .failure(let err):
                    error = err
                }
                
                group.leave()
            }
        }
        
        /// 请求字幕
        if filterType == nil || filterType?.contains(.subtitle) == true {
            group.enter()
            
            self.subtitlesOfMedia(directory) {  result in
                switch result {
                case .success(let success):
                    files.append(contentsOf: success)
                case .failure(let failure):
                    error = failure
                }
                
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            if let error = error {
                completion(.failure(error))
            } else {
                completion(.success(files))
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
                let result = Response<PCWelcomeModel>(with: data)
                let notInputToken = result.result?.tokenRequired == true && !(loginInfo.auth?.password?.isEmpty == false)
                if notInputToken {
                    completionHandler(PCError.needInputTokenError)
                } else {
                    completionHandler(result.error)
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
        
        self.defaultSession.request(self.appendingURL("/api/v1/subtitle/info/\(file.mediaId)"), method: .get, parameters: parameters, encoder: JSONParameterEncoder.default, headers: header).responseData { (response) in
            switch response.result {
            case .success(let data):
                
                do {
                    
                    let jsonDecode = JSONDecoder()
                    let result = try jsonDecode.decode(PCSubtitleCollectionModel.self, from: data)
                    completion(.success(result.subtitles.compactMap({ PCFile(subtitleModel: $0, media: file) })))
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

#endif
