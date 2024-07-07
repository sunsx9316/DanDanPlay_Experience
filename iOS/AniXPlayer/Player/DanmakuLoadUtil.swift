//
//  DanmakuLoadUtil.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/8/13.
//

import Foundation

private enum DanmakuLoadError: LocalizedError {
    case notMatch
    case converError
    
    var errorDescription: String? {
        switch self {
        case .notMatch:
            return "没有匹配到本地弹幕"
        case .converError:
            return "弹幕转换失败"
        }
    }
}

class DanmakuLoadUtil {
    
    
}
