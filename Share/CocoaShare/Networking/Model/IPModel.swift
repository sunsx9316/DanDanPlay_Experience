//
//  IPModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/20.
//

import Foundation
import Alamofire

struct IPResponse: Decodable {
    
    @Default<[IPModel]> var answers: [IPModel]
    
    private enum CodingKeys: String, CodingKey {
        case answers = "Answer"
    }
    
}

struct IPModel: Decodable {
    
    var name: String
    
    var data: String
    
    private enum CodingKeys: String, CodingKey {
        case name
        case data
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.name = try container.decodeIfPresent(String.self, forKey: .name) ?? ""
        if let data = try container.decodeIfPresent(String.self, forKey: .data) {
            self.data = data.replacingOccurrences(of: "\"", with: "")
        } else {
            self.data = ""
        }
    }
}
