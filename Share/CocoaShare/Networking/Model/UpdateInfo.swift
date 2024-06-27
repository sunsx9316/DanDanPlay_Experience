//
//  UpdateInfo.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/26.
//

struct UpdateInfo: Decodable {
    @Default<String> var url: String
    
    /// "2022092601"
    @Default<String> var version: String
    
    /// "1.0"
    @Default<String> var shortVersion: String
    
    @Default<String> var desc: String
    
    @Default<String> var hash: String
    
    @Default<Bool> var forceUpdate: Bool
}
