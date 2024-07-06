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
    
    var host: String {
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
    
    
    /// 发起Get请求
    /// - Parameters:
    ///   - url: url
    ///   - parameters: 参数
    ///   - complection: 完成回调
    func get(url: String, parameters: Encodable = [String: String](), complection: @escaping((Result<Data, Error>) -> Void)) {
        ANX.logInfo(.HTTP, "发起 get 请求 url: \(url), 参数: \(parameters)")
        self.defaultSession.request(url, method: .get, parameters: parameters, encoder: URLEncodedFormParameterEncoder.default).responseData { (response) in
            switch response.result {
            case .success(let data):
                ANX.logInfo(.HTTP, "get 请求成功 url: \(url), 参数: \(parameters)")
                
                complection(.success(data))
            case .failure(let error):
                ANX.logInfo(.HTTP, "get 请求失败 url: \(url), 参数: \(parameters), error:\(error)")
                
                complection(.failure(error))
            }
        }
    }
    
    /// 发起Post请求
    /// - Parameters:
    ///   - url: url
    ///   - parameters: 参数
    ///   - complection: 完成回调
    func post(url: String, parameters: Encodable = [String: String](), complection: @escaping((Result<Data, Error>) -> Void)) {
        ANX.logInfo(.HTTP, "发起 post 请求 url: \(url), 参数: \(parameters)")
        self.defaultSession.request(url, method: .post, parameters: parameters, encoder: JSONParameterEncoder.default).responseData { (response) in
            switch response.result {
            case .success(let data):
                ANX.logInfo(.HTTP, "post 请求成功 url: \(url), 参数: \(parameters)")
                
                complection(.success(data))
            case .failure(let error):
                ANX.logInfo(.HTTP, "post 请求失败 url: \(url), 参数: \(parameters), error:\(error)")
                
                complection(.failure(error))
            }
        }
    }
    
    
    /// 基于baseurl 拼接 additionUrl发起Get请求
    /// - Parameters:
    ///   - additionUrl: 附加路径，需要自己加/分隔符
    ///   - parameters: 参数
    ///   - complection: 完成回调
    func getOnBaseURL(additionUrl: String, parameters: Encodable = [String: String](), complection: @escaping((Result<Data, Error>) -> Void)) {
        self.get(url: self.baseURL + additionUrl, parameters: parameters, complection: complection)
    }
    
    
    /// 基于baseurl 拼接 additionUrl发起Post请求
    /// - Parameters:
    ///   - additionUrl: 附加路径，需要自己加/分隔符
    ///   - parameters: 参数
    ///   - complection: 完成回调
    func postOnBaseURL(additionUrl: String, parameters: Encodable = [String: String](), complection: @escaping((Result<Data, Error>) -> Void)) {
        self.post(url: self.baseURL + additionUrl, parameters: parameters, complection: complection)
    }

    
}
