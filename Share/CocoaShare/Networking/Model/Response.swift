//
//  Response.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation

private enum NetworkError: LocalizedError {
    case dataFormat
    
    var errorDescription: String? {
        switch self {
        case .dataFormat:
            return "数据格式错误"
        }
    }
}

struct Response<S: Decodable> {
    
    struct Error: LocalizedError, Decodable {
        var code: Int
        var message: String
        
        var errorDescription: String {
            return self.message
        }
        
        private enum CodingKeys: String, CodingKey {
            case code, message
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            code = try container.decodeIfPresent(Int.self, forKey: .code) ?? 0
            message = try container.decodeIfPresent(String.self, forKey: .message) ?? ""
        }
    }
    
    var result: S?
    
    var error: Swift.Error?
    
    init(with data: Data) {
        let decoder = JSONDecoder()
        
        self.result = try? decoder.decode(S.self, from: data)
        let err = try? decoder.decode(Error.self, from: data)
        if err?.code != 0 {
            self.error = err
        }
    }
    
}
