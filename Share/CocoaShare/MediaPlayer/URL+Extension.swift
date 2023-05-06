//
//  URL+Extension.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation
#if os(iOS)
import MobileCoreServices
#else
import CoreServices
#endif

extension URL {
    
    var isSubtitleFile: Bool {
        let subtitleExtensions = ["srt", "sub", "cdg", "idx", "ass", "ssa", "aqt", "jss", "psb", "rt", "smi"]
        
        let decodeStr = self.absoluteString.removingPercentEncoding as NSString? ?? ""
        
        let pathExtension = decodeStr.pathExtension.lowercased()
        return subtitleExtensions.contains(pathExtension)
    }
    
    var isMediaFile: Bool {
        
        let decodeStr = self.absoluteString.removingPercentEncoding as NSString? ?? ""
        
        //fix mkv不展示的问题
        if decodeStr.pathExtension.compare("mkv", options: .caseInsensitive, range: nil, locale: nil) == .orderedSame {
            return true
        }
        
        let pathExtension = decodeStr.pathExtension as CFString
        
        if let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil) {
            if UTTypeConformsTo(fileUTI.takeRetainedValue(), kUTTypeMovie) {
                return true
            }
        }
        return false
    }
    
    var isDanmakuFile: Bool {
        let danmakuTypes = ["xml"]
        
        let decodeStr = self.absoluteString.removingPercentEncoding as NSString? ?? ""
        
        let pathExtension = decodeStr.pathExtension

        return danmakuTypes.contains { (str) -> Bool in
            return str.compare(pathExtension, options: .caseInsensitive, range: nil, locale: nil) == .orderedSame
        }
    }
    
    func isThisType(_ type: URLFilterType) -> Bool {
        
        if type.contains(.video) && self.isMediaFile {
            return true
        }
        
        if type.contains(.subtitle) && self.isSubtitleFile {
            return true
        }
        
        if type.contains(.danmaku) && self.isDanmakuFile {
            return true
        }
        
        return false
    }
    
}
