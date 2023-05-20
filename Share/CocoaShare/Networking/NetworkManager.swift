//
//  NetworkManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation
import Alamofire
import ANXLog

class NetworkManager {
    
    static let shared = NetworkManager()
    
    private var host: String {
        return Preferences.shared.host
    }
    
    private var baseURL: String {
        let url = URL(string: self.host)
        return url?.appendingPathComponent("api/v2").absoluteString ?? ""
    }
    
    private lazy var defaultSession: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let version = AppInfoHelper.appVersion ?? "1.0.0"
        configuration.headers.add(.userAgent("dandanplay/ios \(version)"))
        let manager = Alamofire.Session(configuration: configuration)
        return manager
    }()
    
    /// 根据文件直接搜索弹幕
    func danmakuWithFile(_ file: File,
                       progress: FileProgressAction? = nil,
                       matchCompletion: @escaping((MatchCollection?, Error?) -> Void),
                         danmakuCompletion: @escaping((CommentCollection?, _ episodeId: Int, Error?) -> Void)) {
        
        ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 file: \(file)")
        
        self.matchWithFile(file) { (progressValue) in
            progress?(0.5 * progressValue)
        } completion: { [weak self] (collection, error) in
            
            guard let self = self else {
                progress?(1)
                return
            }
            
            if let error = error {
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 请求失败 error: \(error)")
                progress?(1)
                matchCompletion(collection, error)
                return
            }
            
            //精确匹配
            if collection?.isMatched == true &&
                collection?.collection.count == 1 &&
                Preferences.shared.fastMatch {
                progress?(0.7)
                let matched = collection!.collection[0]
                
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 精确匹配 matched: \(matched)")
                
                self.danmakuWithEpisodeId(matched.episodeId) { (damakus, error) in
                    progress?(1)
                    danmakuCompletion(damakus, matched.episodeId, error)
                }
            } else {
                progress?(1)
                matchCompletion(collection, error)
                ANX.logInfo(.HTTP, "根据文件直接搜索弹幕 请求成功 collection数量: \(String(describing: collection?.collection.count))")
            }
        }
    }
    
    /// 根据文件返回匹配的结果
    func matchWithFile(_ file: File,
                       matchMode: MatchMode = .hashAndFileName,
                       parseDataProgress: FileProgressAction? = nil,
                       completion: @escaping((MatchCollection?, Error?) -> Void)) {
        
        let requestMatchWithFileHashBlock = { [weak self] (_ fileHash: String) in
            
            guard let self = self else { return }
            
            var parameters = [String : String]()
            parameters["fileName"] = file.fileName
            parameters["fileHash"] = fileHash
            parameters["fileSize"] = "\(file.fileSize)"
            parameters["matchMode"] = matchMode.rawValue
            
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求参数: \(parameters)")
            
            self.defaultSession.request(self.baseURL + "/match", method: .post, parameters: parameters, encoder: JSONParameterEncoder.default).responseData { (response) in
                switch response.result {
                case .success(let data):
                    do {
                        let asJSON = try JSONSerialization.jsonObject(with: data)
                        let result = Response<MatchCollection>(with: asJSON)
                        completion(result.result, result.error)
                        ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求成功")
                    } catch {
                        completion(nil, error)
                        ANX.logInfo(.HTTP, "根据文件返回匹配的结果 解析失败: \(error)")
                    }
                case .failure(let error):
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 请求失败: \(error)")
                }
            }
        }
        
        if Preferences.shared.fastMatch,
           let hash = CacheManager.shared.matchHashWithFile(file) {
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 快速匹配 hash：\(hash)")
            requestMatchWithFileHashBlock(hash)
        } else {
            ANX.logInfo(.HTTP, "根据文件返回匹配的结果 获取文件解析字节")
            file.getFileHashWithProgress(parseDataProgress) { result in
                switch result {
                case .failure(let error):
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 失败 error: \(error)")
                case .success(let hash):
                    ANX.logInfo(.HTTP, "根据文件返回匹配的结果 成功 hash: \(hash)")
                    CacheManager.shared.setMatchHashWithFile(file, hash: hash)
                    requestMatchWithFileHashBlock(hash)
                }
            }
        }
        
    }
    
    /// 根据文件下载弹幕
    func danmakuWithEpisodeId(_ episodeId: Int,
                              from: Int? = nil,
                              withRelated: Bool = true,
                              lanConvert: LanConvert? = nil,
                              completion: @escaping((CommentCollection?, Error?) -> Void)) {

        var parameters = [String : String]()
        parameters["withRelated"] = withRelated ? "true" : "false"

        if let from = from {
            parameters["from"] = "\(from)"
        }

        if let lanConvert = lanConvert {
            parameters["chConvert"] = "\(lanConvert.rawValue)"
        }
        
        let md5Str = ("\(parameters)" as NSString).md5() ?? ""
        if let data = CacheManager.shared.danmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str) {
            
            do {
                let jsonObj = try JSONSerialization.jsonObject(with: data, options: [])
                ANX.logInfo(.HTTP, "根据文件下载弹幕 匹配到缓存 episodeId: \(episodeId) md5Str: \(md5Str)")
                let result = Response<CommentCollection>(with: jsonObj)
                completion(result.result, nil)
                return
            } catch {
                ANX.logInfo(.HTTP, "根据文件下载弹幕 匹配缓存失败 error: \(error)")
            }
        }

        ANX.logInfo(.HTTP, "根据文件下载弹幕 请求 parameters: \(parameters)")
        self.defaultSession.request(self.baseURL + "/comment/\(episodeId)", method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default).responseData { (response) in
            switch response.result {
            case .success(let data):
                
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    let result = Response<CommentCollection>(with: asJSON)
                    if result.error == nil {
                        CacheManager.shared.setDanmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str, data: response.data)
                    }
                    completion(result.result, result.error)
                    ANX.logInfo(.HTTP, "根据文件下载弹幕 请求成功")
                } catch {
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "根据文件下载弹幕 解析失败: \(error)")
                }
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "根据文件下载弹幕 请求失败: \(error)")
            }
        }
    }
    
    /// 搜索
    func searchWithKeyword(_ keyword: String, completion: @escaping((SearchResult?, Error?) -> Void)) {
        var parameters = [String : String]()
        parameters["anime"] = keyword
        
        ANX.logInfo(.HTTP, "搜索 parameters: \(parameters)")
        self.defaultSession.request(self.baseURL + "/search/episodes", method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default).responseData { (response) in
            switch response.result {
            case .success(let data):
                
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    let result = Response<SearchResult>(with: asJSON)
                    completion(result.result, result.error)
                    ANX.logInfo(.HTTP, "搜索 请求成功")
                } catch {
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "搜索 解析失败: \(error)")
                }
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "搜索 请求失败: \(error)")
            }
        }
    }
    
    #if os(macOS)
    /// 检查更新
    /// - Parameter completion: 回调
    func checkUpdate(_ completion: @escaping((UpdateInfo?, Error?) -> Void)) {
        ANX.logInfo(.HTTP, "检查更新")

        self.defaultSession.request(self.host + "/api/v1/update/mac", method: .get).responseData { (response) in
            switch response.result {
            case .success(let data):
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data)
                    let result = Response<UpdateInfo>(with: asJSON)
                    completion(result.result, result.error)
                    ANX.logInfo(.HTTP, "更新信息 请求成功 \(result)")
                } catch {
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "更新信息 解析失败: \(error)")
                }
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "更新信息 请求失败: \(error)")
            }
        }
    }
    
    #endif
    
    
    /// 获取备用ip
    /// - Parameter completion: 完成回调
    func getBackupIps(_ completion: @escaping((IPResponse?, Error?) -> Void)) {
        self.defaultSession.request("https://dns.alidns.com/resolve?name=cn.api.dandanplay.net&type=16", method: .get).responseData { (response) in
            switch response.result {
            case .success(let data):
                do {
                    let asJSON = try JSONSerialization.jsonObject(with: data) as? NSDictionary
                    let result = IPResponse.deserialize(from: asJSON)
                    completion(result, nil)
                    ANX.logInfo(.HTTP, "获取备用ip成功: \(String(describing: result))")
                } catch {
                    completion(nil, error)
                    ANX.logInfo(.HTTP, "获取备用ip失败: \(error)")
                }
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "获取备用ip失败: \(error)")
            }
        }
    }
    
}
