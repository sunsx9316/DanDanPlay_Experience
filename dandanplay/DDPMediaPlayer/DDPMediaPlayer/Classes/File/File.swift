//
//  File.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation

public typealias FileProgressAction = ((Double) -> Void)

public enum FileType {
    case folder
    case file
}

public protocol File {
    var url: URL { get }
    
    var fileSize: Int { get }
    
    var fileName: String { get }
    
    var type: FileType { get }
    
    func getDataWithRange(_ range: ClosedRange<Int>,
                          progress: @escaping(FileProgressAction),
                          completion: @escaping((Result<Data, Error>) -> Void))
    
    var fileManager: FileManagerProtocol { get }
}

public extension File {
    var fileName: String {
        return self.url.deletingPathExtension().lastPathComponent
    }
}
