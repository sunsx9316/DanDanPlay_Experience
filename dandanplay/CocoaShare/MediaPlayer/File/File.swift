//
//  File.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
import MobileVLCKit
#else
import VLCKit
#endif

typealias FileProgressAction = ((Double) -> Void)

enum FileType {
    case folder
    case file
}

protocol File {
    var url: URL { get }
    
    var fileSize: Int { get }
    
    var fileName: String { get }
    
    var type: FileType { get }
    
    
    
    func getDataWithRange(_ range: ClosedRange<Int>,
                          progress: @escaping(FileProgressAction),
                          completion: @escaping((Result<Data, Error>) -> Void))
    
    var fileManager: FileManagerProtocol { get }
    
    var media: VLCMedia? { get }
    
}

extension File {
    var fileName: String {
        return self.url.lastPathComponent
    }
    
    var pathExtension: String {
        return self.url.pathExtension.uppercased()
    }
    
    //弹弹解析文件需要的文件长度
    func getParseDataWithProgress(_ progress: @escaping(FileProgressAction),
                          completion: @escaping((Result<Data, Error>) -> Void)) {
        let parseFileLength = 16777216
        self.getDataWithRange(0...parseFileLength, progress: progress, completion: completion)
    }
}
