//
//  PathUtils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation

struct PathUtils {
    static var cacheURL: URL {
#if os(iOS)
        return UIApplication.shared.cachesURL
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
