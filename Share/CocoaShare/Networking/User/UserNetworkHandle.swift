//
//  UserNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import Foundation
import YYCategories

class UserNetworkHandle {
    
    
    /// 登录
    /// - Parameters:
    ///   - userName: 用户名
    ///   - password: 密码
    ///   - completion: 完成回调
    static func login(userName: String, password: String, completion: @escaping((LoginResponse?, Error?) -> Void)) {
        
        var parameters = [String : String]()
        parameters["userName"] = userName
        parameters["password"] = password
        parameters["appId"] = AppKey.appId
        
        let time = Int64(Date().timeIntervalSince1970)
        parameters["unixTimestamp"] = "\(time)"
        parameters["hash"] = hash(userName: userName, password: password, unixTimestamp: time)
        
        NetworkManager.shared.postOnBaseURL(additionUrl: "/login") { result in
            switch result {
            case .success(let data):
                let rsp = Response<LoginResponse>(with: data)
                completion(rsp.result, rsp.error)
            case .failure(let error):
                completion(nil, error)
            }
        }
    }
    
    
    private static func hash(userName: String, password: String, unixTimestamp: Int64) -> String {
        let str = AppKey.appId + password + "\(unixTimestamp)" + "userName"
        return (str as NSString).md5() ?? ""
    }
    
}


