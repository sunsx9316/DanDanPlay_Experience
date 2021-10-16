//
//  WebDAVInputStream.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/3/2.
//

import UIKit
import YYCategories

protocol WebDAVInputStreamDelegate: AnyObject {
    func streamDidClose(_ stream: WebDAVInputStream)
}

class WebDAVInputStream: InputStream {
    
    private class TaskInfo: CustomStringConvertible {
        
        var description: String {
            return "range: \(self.range.lowerBound)-\(self.range.upperBound), index: \(self.index), isCached: \(self.isCached), isRequesting: \(self.isRequesting)"
        }
        
        let range: NSRange
        
        let index: Int
        
        var isCached = false
        
        var isRequesting = false
        
        init(range: NSRange, index: Int) {
            self.range = range
            self.index = index
        }
        
    }
    
    enum StreamError: Error {
        case streamClose
        case readFailed
    }
    
    private let defaultDownloadSize = 20 * 1024 * 1024
    
    private var fileLength: Int
    
    private var readOffset: Int = 0 {
        didSet {
            self.inputStream?.setProperty(self.readOffset, forKey: .fileCurrentOffsetKey)
        }
    }
    
    private let url: URL
    
    private lazy var cacheRangeDic = [Int : TaskInfo]()
    
    private var inputStream: InputStream?
    
    private var fileHandle: FileHandle?
    
    private let rangeKey = "Range"
    
    private var _streamStatus: Stream.Status = .notOpen
    
    override var streamStatus: Stream.Status {
        return _streamStatus
    }
    
    private var _streamError: Error?
    
    override var streamError: Error? {
        return _streamError
    }
    
    weak var file: WebDavFile?
    
    weak var streamDelegate: WebDAVInputStreamDelegate?
    
    
    init?(file: WebDavFile) {
        self.fileLength = file.fileSize
        self.file = file
        let url = file.url
        
        var cacheURL = UIApplication.shared.cachesURL
        cacheURL.appendPathComponent(url.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            do {
                try FileManager.default.removeItem(atPath: cacheURL.path)
            } catch let error {
                debugPrint("删除文件失败: \(error)")
            }
        }
        
        
        if !FileManager.default.createFile(atPath: cacheURL.path, contents: nil, attributes: nil) {
            debugPrint("创建文件失败: \(cacheURL)")
        }
        
        self.inputStream = .init(fileAtPath: cacheURL.path)
        self.fileHandle = .init(forWritingAtPath: cacheURL.path)
        
        self.url = url
        super.init(url: url)
        if self.fileLength > 0 {
            self.generateTasks()
        }
    }
    
    deinit {
        self._streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
    }
    
    override func open() {
        debugPrint("open")
        _streamStatus = .open
        self.inputStream?.open()
    }
    
    override func close() {
        debugPrint("close")
        self._streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
        self.streamDelegate?.streamDidClose(self)
    }
    
    override var hasBytesAvailable: Bool {
        if self.fileLength > 0 {
            return self.fileLength - self.readOffset > 0
        }
        return true
    }
    
    override func property(forKey key: Stream.PropertyKey) -> Any? {
        guard key == .fileCurrentOffsetKey else { return nil }
        return self.readOffset
    }
    
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        
        guard key == .fileCurrentOffsetKey,
              let property = property as? Int else { return false }
        
        debugPrint("setProperty key:\(key) property:\(property)")
        
        self.readOffset = property
        return true
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        
        if self.fileLength == 0 {
            
            self.fileLength = self.file?.getFileSizeSync() ?? 0
            
            if self.fileLength == 0 {
                debugPrint("文件长度为0")
                return 0
            } else {
                self.generateTasks()
            }
        }
        
        let dataRange = NSRange(location: self.readOffset, length: min(max(self.fileLength - self.readOffset, 0), len))
        
        if (self.fileLength > 0 && self.readOffset >= self.fileLength) {
            _streamStatus = .atEnd
            return 0
        }
        
        
        let lower = dataRange.lowerBound / defaultDownloadSize
        let upper = dataRange.upperBound / defaultDownloadSize
        
        var shouldDownloadTasks = [TaskInfo]()
        
        for i in lower...upper {
            if let aTask = self.cacheRangeDic[i] {
                if !aTask.isCached && !aTask.isRequesting {
                    shouldDownloadTasks.append(aTask)
                }
            }
        }
        
//        debugPrint("lower: \(lower) upper:\(upper)")
        
        if !shouldDownloadTasks.isEmpty {
            
            var count = shouldDownloadTasks.count
            
            debugPrint("批量请求数据开始 range：\(dataRange) count：\(count)")
            for aTask in shouldDownloadTasks {
                self.downloadFile(with: aTask, retryCount: 2) { (_) in
                    
                } completion: { (_) in
                    count -= 1
                }
            }
            
            weak var weakSelf = self
            
            while count > 0 && weakSelf?._streamStatus != .closed {}
            
            if weakSelf?._streamStatus == .closed {
                debugPrint("streamStatus end")
                return 0
            }
        }
        
        let _ = self.inputStream?.read(buffer, maxLength: dataRange.length)
        self.readOffset += dataRange.length
//        debugPrint("streamResult \(r)")
        return dataRange.length
    }
    
    private func generateTasks() {
        
        if self.fileLength == 0 {
            debugPrint("webdav fileLength = 0")
            return
        }
        
        let taskCount = Int(ceil(Double(self.fileLength) / Double(defaultDownloadSize)))
        var taskDic = [Int : TaskInfo](minimumCapacity: taskCount)
        
        if taskCount == 0 {
            taskDic[0] = .init(range: .init(location: 0, length: self.fileLength - 1), index: 0)
        } else {
            for i in 0..<taskCount {
                
                var tmpRange = NSRange(location: i * defaultDownloadSize, length: defaultDownloadSize - 1)
                
                //最后一个range.length不一定是kDefaultDownloadSize的整数倍，需要根据文件实际长度处理
                if i == taskCount - 1 {
                    tmpRange.length = fileLength - tmpRange.location - 1
                }
                
                taskDic[i] = .init(range: tmpRange, index: i)
                
            }
        }
        
        self.cacheRangeDic = taskDic
    }
    
    private func downloadFile(with task: TaskInfo,
                              retryCount: Int,
                       progressHandler: @escaping((Double) -> Void),
                       completion: @escaping((Result<TaskInfo, Error>) -> Void)) {
        
        if task.isCached {
            progressHandler(1)
            completion(.success(task))
            return
        }
        
        if task.isRequesting {
            return
        }
        
        task.isRequesting = true
        debugPrint("请求数据 \(task)")
        let r = task.range
        self.file?.getDataWithRange(r.lowerBound...r.upperBound, progress: progressHandler, completion: { [weak self] result in
            
            guard let self = self else {
                completion(.failure(StreamError.streamClose))
                return
            }
            
            task.isRequesting = false
            
            switch result {
            case .success(let data):
                debugPrint("请求数据成功 \(task)")
                task.isCached = true
                self.fileHandle?.seek(toFileOffset: UInt64(r.lowerBound))
                self.fileHandle?.write(data)
                self.fileHandle?.synchronizeFile()
                completion(.success(task))
            case .failure(let error):
                if retryCount > 0 {
                    self.downloadFile(with: task, retryCount: retryCount - 1, progressHandler: progressHandler, completion: completion)
                } else {
                    debugPrint("请求数据失败 \(error)")
                    completion(.failure(error))
                }
            }
        })
    }
    
}
