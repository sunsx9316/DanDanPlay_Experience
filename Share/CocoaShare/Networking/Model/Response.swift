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

struct ResponseError: LocalizedError, Decodable {
    var errorCode: Int
    var errorMessage: String
    
    var errorDescription: String? {
        return self.errorMessage
    }
    
    private enum CodingKeys: String, CodingKey {
        case errorCode = "errorCode"
        case errorMessage = "errorMessage"
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        errorCode = try container.decodeIfPresent(Int.self, forKey: .errorCode) ?? 0
        errorMessage = try container.decodeIfPresent(String.self, forKey: .errorMessage) ?? ""
    }
}

struct Response<S: Decodable> {
    
    var result: S?
    
    var error: Swift.Error?
    
    init(with data: Data) {
        let decoder = JSONDecoder()
        
        self.result = try? decoder.decode(S.self, from: data)
        let err = try? decoder.decode(ResponseError.self, from: data)
        if err?.errorCode != 0 {
            self.error = err
        }
    }
    
}
