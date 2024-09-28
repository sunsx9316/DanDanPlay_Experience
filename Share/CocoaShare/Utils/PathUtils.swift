//
//  PathUtils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation
import YYCategories

struct PathUtils {
    static var cacheURL: URL {
#if os(iOS)
        return UIApplication.shared.cachesURL.appendingPathComponent("anx_data")
#else
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .allDomainsMask, true)[0])
#endif
    }
    
    static var documentsURL: URL {
#if os(iOS)
        return UIApplication.shared.documentsURL
#else
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)[0])
#endif
    }
}
