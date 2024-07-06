//
//  UpdateInfo.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/26.
//

#if os(macOS)
struct UpdateInfo: Decodable {
    /// 更新url
    @Default<String> var url: String
    
    /// "2022092601"
    @Default<String> var version: String
    
    /// "1.0"
    @Default<String> var shortVersion: String
    
    /// 更新描述
    @Default<String> var desc: String
    
    /// 安装包hash值
    @Default<String> var hash: String
    
    /// 强制更新
    @Default<Bool> var forceUpdate: Bool
}
#endif
