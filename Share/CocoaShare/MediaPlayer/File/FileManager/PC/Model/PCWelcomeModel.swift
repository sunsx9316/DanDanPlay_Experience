//
//  PCWelcomeModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/1.
//

struct PCWelcomeModel: Decodable {
    
    @Default<String> var message: String
    
    @Default<String> var version: String
    
    @Default<String> var time: String
    
    @Default<Bool> var tokenRequired: Bool
    
}
