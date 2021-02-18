//
//  Helper.swift
//  Runner
//
//  Created by JimHuang on 2020/3/23.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation
import DDPMediaPlayer

class Helper {
    
    static let shared = Helper()
    
    weak var player: MediaPlayer?
    
    let subTitlePathExtension = ["SSA", "ASS", "SMI", "SRT", "SUB", "LRC", "SST", "TXT", "XSS", "PSB", "SSB"]
    
    func isSubTitleFile(_ url: URL) -> Bool {
        let subtitleNames = subTitlePathExtension
        let pathExtension = url.pathExtension
        return subtitleNames.contains { (str) -> Bool in
            return pathExtension.range(of: str, options: .caseInsensitive) != nil
        }
    }
    
}
