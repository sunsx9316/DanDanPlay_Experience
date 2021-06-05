//
//  WebDAVInputStream.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/3/2.
//

import UIKit
import YYCategories

class WebDAVInputStream: InputStream {
    
    private class TaskInfo: CustomStringConvertible {
        
        var description: String {
            return "range: \(self.range.lowerBound)-\(self.range.upperBound), index: \(self.index), isCached: \(self.isCached), isRequesting: \(self.isRequesting)"
        }
        
        let range: ClosedRange<Int>
        
        let index: Int
        
        var isCached = false
        
        var isRequesting = false
        
        init(range: ClosedRange<Int>, index: Int) {
            self.range = range
            self.index = index
        }
        
    }
    
    enum StreamError: Error {
        case streamClose
        case readFailed
    }
    
    private let defaultDownloadSize = 20 * 1024 * 1024
    
    private let fileLength: Int
    
    private var readOffset: Int {
        get {
            return self.inputStream?.property(forKey: .fileCurrentOffsetKey) as? Int ?? 0
        }

        set {
            self.inputStream?.setProperty(newValue, forKey: .fileCurrentOffsetKey)
        }
    }
    
    private let url: URL
    
    private lazy var cacheRangeDic = [Int : TaskInfo]()
    
    private var inputStream: InputStream?
    
    private var fileHandle: FileHandle?
//    private var outputStream: OutputStream?
    
    private let rangeKey = "Range"
    
    private var _streamStatus: Stream.Status = .notOpen
    
    override var streamStatus: Stream.Status {
        return _streamStatus
    }
    
    private var _streamError: Error?
    
    override var streamError: Error? {
        return _streamError
    }
    
//    weak var _delegate: StreamDelegate?
    
    weak var file: WebDavFile?
    
    override var delegate: StreamDelegate? {
        get {
            self.inputStream?.delegate
        }
        
        set {
            self.inputStream?.delegate = newValue
        }
//        get { _delegate }
//        set { _delegate = newValue }
    }
    
    
    init?(file: WebDavFile) {
        self.fileLength = file.fileSize
        self.file = file
        let url = file.url
        
        var cacheURL = URL(string: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])!
        let pathName = (url.absoluteString as NSString).md5() ?? ""
        cacheURL.appendPathComponent(pathName)
        cacheURL.appendPathExtension(url.pathExtension)
        
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
//        self.outputStream = .init(toFileAtPath: cacheURL.path, append: false)
        
        self.url = url
        super.init(url: url)
        self.generateTasks()
    }
    
    deinit {
        self._streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
//        self.outputStream?.close()
    }
    
    override func open() {
        debugPrint("open")
        _streamStatus = .open
        self.inputStream?.open()
//        self.outputStream?.open()
    }
    
    override func close() {
        debugPrint("close")
        self._streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
//        self.outputStream?.close()
        self.delegate?.stream?(self, handle: .endEncountered)
    }
    
    override var hasBytesAvailable: Bool {
        return self.inputStream?.hasBytesAvailable ?? false
//        if self.fileLength > 0 {
//            return self.fileLength - self.readOffset > 0
//        }
//        return true
    }
    
    override func property(forKey key: Stream.PropertyKey) -> Any? {
        return self.inputStream?.property(forKey: key)
//        guard key == .fileCurrentOffsetKey else { return nil }
//        return self.readOffset
    }
    
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        return self.inputStream?.setProperty(property, forKey: key) ?? false
//        guard key == .fileCurrentOffsetKey, let property = property as? Int else { return false }
//        debugPrint("setProperty key:\(key) property:\(property)")
//
//        self.readOffset = property
//        return true
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return self.inputStream?.getBuffer(buffer, length: len) ?? false
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {

        let dataRange = NSRange(location: self.readOffset, length: min(max(self.fileLength - self.readOffset, 0), len))
        
        
        let lower = dataRange.lowerBound / defaultDownloadSize
        let upper = dataRange.upperBound / defaultDownloadSize
        
        var shouldDownloadTasks = [TaskInfo]()
        
        for i in 0...upper {
            if let aTask = self.cacheRangeDic[i] {
                if !aTask.isCached && !aTask.isRequesting {
                    shouldDownloadTasks.append(aTask)
                }
            }
        }
        
        debugPrint("lower: \(lower) upper:\(upper)")
        
        var count = shouldDownloadTasks.count
        
        if !shouldDownloadTasks.isEmpty {
            debugPrint("批量请求数据开始 range：\(dataRange) count：\(count)")
            for aTask in shouldDownloadTasks {
                self.getPartOfFile(with: aTask) { (_) in
                    
                } completion: { (_) in
                    count -= 1
                }
            }
        }
        
        while count > 0 && self._streamStatus != .closed {}
        
        
        if self._streamStatus == .closed {
            debugPrint("streamStatus end")
            return 0
        }
        
        let r = self.inputStream?.read(buffer, maxLength: dataRange.length)
        self.readOffset += dataRange.length
        debugPrint("streamResult \(r)")
        return dataRange.length
    }
    
    private func generateTasks() {
        let taskCount = Int(ceil(Double(self.fileLength) / Double(defaultDownloadSize)))
        var taskDic = [Int : TaskInfo](minimumCapacity: taskCount)
        
        if taskCount == 0 {
            taskDic[0] = .init(range: 0...fileLength, index: 0)
        } else {
            for i in 0..<taskCount {
                
                let tmpRange: ClosedRange<Int>
                
                let start = i * defaultDownloadSize
                //最后一个range.length不一定是kDefaultDownloadSize的整数倍，需要根据文件实际长度处理
                if i == taskCount - 1 {
                    tmpRange = start...self.fileLength - 1
                } else {
                    tmpRange = start...(start + defaultDownloadSize - 1)
                }
                
                taskDic[i] = .init(range: tmpRange, index: i)
                
            }
        }
        
        self.cacheRangeDic = taskDic
    }
    
    private func getPartOfFile(with task: TaskInfo,
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
        self.file?.getDataWithRange(task.range, progress: progressHandler, completion: { [weak self] result in
            guard let self = self else {
                completion(.failure(StreamError.streamClose))
                return
            }
            
            task.isRequesting = false
            
            switch result {
            case .failure(let error):
                debugPrint("请求数据失败 \(error)")
                completion(.failure(error))
            case .success(let data):
                debugPrint("请求数据成功 \(task)")
                task.isCached = true
                self.fileHandle?.write(data)
                self.fileHandle?.synchronizeFile()
                completion(.success(task))
//                self.outputStream?.setProperty(task.range.lowerBound, forKey: .fileCurrentOffsetKey)
//                data.withUnsafeBytes { p in
//                    if let b = p.baseAddress?.assumingMemoryBound(to: UInt8.self) {
//                        self.outputStream?.write(b, maxLength: task.range.count)
//                    }
//
//                    completion(.success(task))
//                }
            }
        })
    }
    
}
