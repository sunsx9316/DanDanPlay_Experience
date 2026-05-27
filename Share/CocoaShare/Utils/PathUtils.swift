//
//  PathUtils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Foundation
#if os(iOS)
import YYCategories
#endif

struct PathUtils {
    static var cacheURL: URL {
#if os(iOS)
        return UIApplication.shared.cachesURL.appendingPathComponent("anx_data")
#elseif os(tvOS)
        let caches = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: caches).appendingPathComponent("anx_data")
#else
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .allDomainsMask, true)[0])
#endif
    }

    static var documentsURL: URL {
#if os(iOS)
        return UIApplication.shared.documentsURL
#elseif os(tvOS)
        let documents = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
        return URL(fileURLWithPath: documents)
#else
        return URL(fileURLWithPath: NSSearchPathForDirectoriesInDomains(.documentDirectory, .allDomainsMask, true)[0])
#endif
    }
}
