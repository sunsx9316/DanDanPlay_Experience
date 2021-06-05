//
//  URL+Extension.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation
import CoreServices

public extension URL {
    
    var isSubtitleFile: Bool {
        let pathExtension = self.pathExtension as CFString
        if let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil) {
            if UTTypeConformsTo(fileUTI.takeRetainedValue(), kUTTypePlainText) {
                return true
            }
        }
        return false
    }
    
    var isMediaFile: Bool {
        let pathExtension = self.pathExtension as CFString
        if let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil) {
            if UTTypeConformsTo(fileUTI.takeRetainedValue(), kUTTypeMovie) {
                return true
            }
        }
        return false
    }
    
    var isDanmakuFile: Bool {
        let danmakuTypes = ["xml"]
        let pathExtension = self.pathExtension

        return danmakuTypes.contains { (str) -> Bool in
            return str.compare(pathExtension, options: .caseInsensitive, range: nil, locale: nil) == .orderedSame
        }
    }
}
