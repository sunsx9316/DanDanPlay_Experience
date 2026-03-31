//
//  File.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
import MobileVLCKit
import MPVFramework
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

protocol MediaBufferInfo {
    
    var startPositin: CGFloat { get }
    
    var endPositin: CGFloat { get }
    
}

protocol FileDelegate: AnyObject {
    func mediaBufferDidChange(file: File, bufferInfo: MediaBufferInfo)
}

protocol File: HistoryManager.lastWatchDateStoreable {
    
    var url: URL { get }
    
    var fileSize: Int { get }
    
    var fileName: String { get }
    
    var subtitle: String { get }
    
    var type: FileType { get }
    
    static var fileManager: FileManagerProtocol { get }
    
    static var rootFile: File { get }
    
    var parentFile: File? { get }
    
    var fileId: String { get }
    
    /// 文件是否允许删除
    var isCanDelete: Bool { get }
    
    /// 缓存信息，某些需要自己从网络加载留的格式可以实现
    var bufferInfos: [MediaBufferInfo] { get }
    
    /// 获取文件字节流
    /// - Parameters:
    ///   - range: 范围
    ///   - progress: 进度
    ///   - completion: 完成回调
    func getDataWithRange(_ range: ClosedRange<Int>,
                          progress: FileProgressAction?,
                          completion: @escaping((Result<Data, Error>) -> Void))
    
    /// 获取弹弹解析的文件哈希
    /// - Parameters:
    ///   - progress: 进度
    ///   - completion: 完成回调
    func getFileHashWithProgress(_ progress: FileProgressAction?,
                                 completion: @escaping((Result<String, Error>) -> Void))
    
    /// 创建播放的媒体文件
    /// - Parameter delegate: 媒体代理
    /// - Returns: 媒体文件
    func createVLCMedia(delegate: FileDelegate) -> VLCMedia?
    
    func createMPVMedia() -> MPVMedia?
}

extension File {
    var fileName: String {
        return (self.url.absoluteString.removingPercentEncoding as NSString?)?.lastPathComponent ?? ""
    }
    
    var subtitle: String {
        return ""
    }
    
    var pathExtension: String {
        return (self.url.absoluteString.removingPercentEncoding as NSString?)?.pathExtension.uppercased() ?? ""
    }
    
    var fileId: String {
        return (self.url.absoluteString as NSString).md5() ?? ""
    }
    
    var bufferInfos: [MediaBufferInfo] {
        return []
    }
    
    var isCanDelete: Bool {
        if self == Swift.type(of: self).rootFile {
            return false
        }
        return true
    }
    
    var lastWatchDateKey: String {
        return self.fileId
    }
    
    func getDataWithRange(_ range: ClosedRange<Int>,
                          progress: FileProgressAction?,
                          completion: @escaping((Result<Data, Error>) -> Void)) {
        Swift.type(of: self).fileManager.getDataWithFile(self, range: range, progress: progress, completion: completion)
    }
    
    
    /// 下载文件
    /// - Parameters:
    ///   - progress: 下载进度
    ///   - completion: 完成回调
    func getDataWithProgress(_ progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        Swift.type(of: self).fileManager.getDataWithFile(self, range: nil, progress: progress, completion: completion)
    }
}

extension File {
    // 定义一个通用的比较方法
    func isEqual(to other: any File) -> Bool {
        guard let comp1 = URLComponents(url: self.url, resolvingAgainstBaseURL: false),
              let comp2 = URLComponents(url: other.url, resolvingAgainstBaseURL: false) else {
            return self.url == other.url
        }
        
        // 忽略 user 和 password 的逻辑
        return comp1.scheme == comp2.scheme &&
               comp1.host == comp2.host &&
               comp1.path == comp2.path &&
               comp1.query == comp2.query
    }
}

// 重载运算符，支持不同类型的 File 比较
func == (lhs: any File, rhs: any File) -> Bool {
    return lhs.isEqual(to: rhs)
}

func == (lhs: any File, rhs: (any File)?) -> Bool {
    guard let rhs = rhs else { return false }
    return lhs.isEqual(to: rhs)
}

func == (lhs: (any File)?, rhs: any File) -> Bool {
    guard let lhs = lhs else { return false }
    return lhs.isEqual(to: rhs)
}
