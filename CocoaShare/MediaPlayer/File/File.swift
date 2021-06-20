//
//  File.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
//import MobileVLCKit
#else
import VLCKit
#endif

typealias FileProgressAction = ((Double) -> Void)

//弹弹解析文件的长度
let parseFileLength = 16777215

enum FileType {
    case folder
    case file
}

protocol File {
    var url: URL { get }
    
    var fileSize: Int { get }
    
    var fileName: String { get }
    
    var type: FileType { get }
    
    
    var fileManager: FileManagerProtocol { get }
    
    static var rootFile: File { get }
    
    var parentFile: File? { get }
    
    var fileHash: String { get }
    
    func getDataWithRange(_ range: ClosedRange<Int>,
                          progress: FileProgressAction?,
                          completion: @escaping((Result<Data, Error>) -> Void))
    
    func getParseDataWithProgress(_ progress: FileProgressAction?,
                          completion: @escaping((Result<Data, Error>) -> Void))
    
    func createMedia() -> VLCMedia?
}

extension File {
    var fileName: String {
        return self.url.lastPathComponent
    }
    
    var pathExtension: String {
        return self.url.pathExtension.uppercased()
    }
    
    var fileHash: String {
        return (self.url.absoluteString as NSString).md5() ?? ""
    }
    
    //弹弹解析文件需要的文件长度
    func getParseDataWithProgress(_ progress: FileProgressAction? = nil,
                          completion: @escaping((Result<Data, Error>) -> Void)) {
        let length = parseFileLength + 1
        self.getDataWithRange(0...length, progress: progress, completion: completion)
    }
    
    func getDataWithRange(_ range: ClosedRange<Int>,
                          progress: FileProgressAction?,
                          completion: @escaping((Result<Data, Error>) -> Void)) {
        self.fileManager.getDataWithFile(self, range: range, progress: progress, completion: completion)
    }
    
    
    /// 下载文件
    /// - Parameters:
    ///   - progress: 下载进度
    ///   - completion: 完成回调
    func getDataWithProgress(_ progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        self.fileManager.getDataWithFile(self, range: nil, progress: progress, completion: completion)
    }
}
