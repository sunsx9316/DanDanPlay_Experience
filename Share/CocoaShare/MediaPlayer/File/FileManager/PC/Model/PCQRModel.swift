//
//  PCQRModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/2.
//

import Foundation

struct PCQRModel: Decodable {
    
    @Default<[String]> var ip: [String]
    
    @Default<Int> var port: Int
    
    @Default<Bool> var tokenRequired: Bool
    
    @Default<String> var name: String
    
    private enum CodingKeys: String, CodingKey {
        case ip, port, tokenRequired, name = "machineName"
    }
    
}
