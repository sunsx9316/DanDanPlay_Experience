//
//  Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/3/23.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

extension URL {
    var isVideoFile: Bool {
        let pathExtension = self.pathExtension as CFString
        if let fileUTI = UTTypeCreatePreferredIdentifierForTag(kUTTagClassFilenameExtension, pathExtension, nil) {
            if UTTypeConformsTo(fileUTI.takeRetainedValue(), kUTTypeMovie) {
                return true
            }
        }
        return false
    }
}
