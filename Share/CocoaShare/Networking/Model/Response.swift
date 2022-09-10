//
//  Response.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/3.
//

import Foundation
import HandyJSON

private enum NetworkError: LocalizedError {
    case dataFormat
    
    var errorDescription: String? {
        switch self {
        case .dataFormat:
            return "数据格式错误"
        }
    }
}

struct Response<S: HandyJSON> {
    
    struct Error: LocalizedError, HandyJSON {
        var code = 0
        var message: String?
        
        var errorDescription: String? {
            return self.message
        }
    }
    
    var result: S?
    
    var error: Swift.Error?
    
    init(with data: Any) {
        if let data = data as? NSDictionary {
            self.result = S.deserialize(from: data)
            let err = Error.deserialize(from: data)
            if err?.code != 0 {
                self.error = err
            }
        } else {
            self.error = NetworkError.dataFormat
        }
    }
    
}
