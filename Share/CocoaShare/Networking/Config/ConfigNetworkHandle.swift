//
//  ConfigNetworkHandle.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/6.
//

import Foundation
import ANXLog

class ConfigNetworkHandle {
#if os(macOS)
    /// 检查更新
    /// - Parameter completion: 回调
    static func checkUpdate(_ completion: @escaping((UpdateInfo?, Error?) -> Void)) {
        ANX.logInfo(.HTTP, "检查更新")
        
        NetworkManager.shared.get(url: NetworkManager.shared.host) { result in
            switch result {
            case .success(let data):
                let result = Response<UpdateInfo>(with: data)
                completion(result.result, result.error)
                ANX.logInfo(.HTTP, "更新信息 请求成功 \(result)")
            case .failure(let error):
                completion(nil, error)
                ANX.logInfo(.HTTP, "更新信息 请求失败: \(error)")
            }
        }
    }
#endif


    /// 获取备用ip
    /// - Parameter completion: 完成回调
    static func getBackupIps(_ completion: @escaping((IPResponse?, Error?) -> Void)) {
        NetworkManager.shared.get(url: "https://dns.alidns.com/resolve?name=cn.api.dandanplay.net&type=16") { result in
            switch result {
            case .success(let data):
                do {
                    let jsonDecoder = JSONDecoder()
                    let result = try jsonDecoder.decode(IPResponse.self, from: data)
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
