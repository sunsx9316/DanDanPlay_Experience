//
//  NetworkManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation
import Alamofire

class NetworkManager {
    
    static let shared = NetworkManager()
    
    private let baseURL = "https://api.acplay.net/api/v2"
    
    private lazy var defaultSession: Alamofire.Session = {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 10
        let manager = Alamofire.Session(configuration: configuration)
        return manager
    }()
    
    /// 根据文件直接搜索弹幕
    func danmakuWithFile(_ file: File,
                       progress: FileProgressAction? = nil,
                       matchCompletion: @escaping((MatchCollection?, Error?) -> Void),
                       danmakuCompletion: @escaping((CommentCollection?, Error?) -> Void)) {
        
        self.matchWithFile(file) { (progressValue) in
            progress?(0.5 * progressValue)
        } completion: { [weak self] (collection, error) in
            
            guard let self = self else {
                progress?(1)
                return
            }
            
            if let error = error {
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
                self.danmakuWithEpisodeId(matched.episodeId) { (damakus, error) in
                    progress?(1)
                    danmakuCompletion(damakus, error)
                }
            } else {
                progress?(1)
                matchCompletion(collection, error)
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
            
            self.defaultSession.request(self.baseURL + "/match", method: .post, parameters: parameters, encoder: JSONParameterEncoder.default).responseJSON { (response) in
                switch response.result {
                case .success(let data):
                    let result = Response<MatchCollection>(with: data)
                    completion(result.result, result.error)
                case .failure(let error):
                    completion(nil, error)
                }
            }
        }
        
        if Preferences.shared.fastMatch,
           let hash = CacheManager.shared.matchHashWithFile(file) {
            requestMatchWithFileHashBlock(hash)
        } else {
            file.getParseDataWithProgress(parseDataProgress) { (result) in
                switch result {
                case .failure(let error):
                    completion(nil, error)
                case .success(let parseData):
                    let hash = (parseData as NSData).md5String()
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
        if let data = CacheManager.shared.danmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str),
           let jsonObj = try? JSONSerialization.jsonObject(with: data, options: []) {
            let result = Response<CommentCollection>(with: jsonObj)
            completion(result.result, nil)
            return
        }

        
        self.defaultSession.request(self.baseURL + "/comment/\(episodeId)", method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                let result = Response<CommentCollection>(with: data)
                if result.error == nil {
                    CacheManager.shared.setDanmakuCacheWithEpisodeId(episodeId, parametersHash: md5Str, data: response.data)
                }
                completion(result.result, result.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    /// 搜索
    func searchWithKeyword(_ keyword: String, completion: @escaping((SearchResult?, Error?) -> Void)) {
        var parameters = [String : String]()
        parameters["anime"] = keyword
        
        self.defaultSession.request(self.baseURL + "/search/episodes", method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default).responseJSON { (response) in
            switch response.result {
            case .success(let data):
                let result = Response<SearchResult>(with: data)
                completion(result.result, result.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
}
