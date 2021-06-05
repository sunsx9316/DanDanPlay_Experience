//
//  WebDAVInputStream.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/3/2.
//

import UIKit

extension WebDAVInputStream: URLSessionDataDelegate {

    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if challenge.previousFailureCount > 0 {
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            if let user = self.auth?.user, let password = self.auth?.password {
                let credential = URLCredential(user: user, password: password, persistence: .permanent)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
}

class WebDAVInputStream: InputStream {
    
    private class Task {
        let range: NSRange
        
        let index: Int
        
        let rangeString: String
        
        var isCached = false
        
        var isRequesting = false
        
        var obs: NSKeyValueObservation?
        
        
        
        init(range: NSRange, index: Int) {
            self.range = range
            self.index = index
            self.rangeString = "bytes=\(range.location)-\(NSMaxRange(range))"
        }
        
    }
    
    enum StreamError: Error {
        case streamClose
        case readFailed
    }
    
    private let defaultDownloadSize = 16 * 1024 * 1024
    
    private let fileLength: Int
    
    private var readOffset = 0 {
        didSet {
            self.inputStream?.setProperty(self.readOffset, forKey: .fileCurrentOffsetKey)
        }
    }
    
    private let url: URL
    
    private lazy var cacheRangeDic = [Int : Task]()
    
    private var inputStream: InputStream?
    
    private var fileHandle: FileHandle?
    
    private let rangeKey = "Range"
    
    private var auth: Auth?
    
    private lazy var session: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: OperationQueue())
        return session
    }()
    
    private var _streamStatus: Stream.Status = .notOpen
    
    override var streamStatus: Stream.Status {
        return _streamStatus
    }
    
    private var _streamError: Error?
    
    override var streamError: Error? {
        return _streamError
    }
    
    weak var _delegate: StreamDelegate?
    
    override var delegate: StreamDelegate? {
        get { _delegate }
        set { _delegate = newValue }
    }
    
    
    
    init?(url: URL, fileLength: Int = 0, auth: Auth? = nil) {
        self.fileLength = fileLength
        self.auth = auth
        var cacheURL = URL(string: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0])!
        cacheURL.appendPathComponent(url.lastPathComponent)
        
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            do {
                try FileManager.default.removeItem(atPath: cacheURL.path)
            } catch let error {
                debugPrint("删除文件失败: \(error)")
            }
        }
        
        FileManager.default.createFile(atPath: cacheURL.path, contents: nil, attributes: nil)
        self.fileHandle = FileHandle(forUpdatingAtPath: cacheURL.path)
        self.inputStream = InputStream(fileAtPath: cacheURL.path)
        self.url = url
        super.init(url: url)
        self.generateTasks()
    }
    
    deinit {
        self._streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
    }
    
    override func open() {
        _streamStatus = .open
        self.inputStream?.open()
    }
    
    override func close() {
        self._streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
        self.delegate?.stream?(self, handle: .endEncountered)
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
        
        guard key == .fileCurrentOffsetKey, let property = property as? Int else { return false }
        
        self.readOffset = property
        return true
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    func getDataWithRange(_ range: NSRange, progressHandle: @escaping (FileProgressAction), completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        let lower = range.location / defaultDownloadSize
        let upper = NSMaxRange(range) / defaultDownloadSize
        
        var shouldDownloadTasks = [Task]()
        
        for i in lower...upper {
            if let aTask = self.cacheRangeDic[i] {
                if !aTask.isCached && !aTask.isRequesting {
                    shouldDownloadTasks.append(aTask)
                }
            }
        }
        
        if shouldDownloadTasks.isEmpty {
            if let fileHandle = self.fileHandle {
                fileHandle.seek(toFileOffset: UInt64(range.location))
                let data = fileHandle.readData(ofLength: range.length)
                completion(.success(data))
            } else {
                completion(.failure(StreamError.readFailed))
            }
        } else {
            var count = shouldDownloadTasks.count
            for aTask in shouldDownloadTasks {
                self.getPartOfFile(with: aTask) { (progress) in
                    progressHandle(progress)
                } completion: { (_) in
                    count -= 1
                }
            }
            
            while self._streamStatus != .closed && count > 0 {}
            
            if self._streamStatus == .closed {
                return
            }
            
            if let fileHandle = self.fileHandle {
                fileHandle.seek(toFileOffset: UInt64(range.location))
                let data = fileHandle.readData(ofLength: range.length)
                completion(.success(data))
            } else {
                completion(.failure(StreamError.readFailed))
            }
        }
        
    }
    
    override func read(_ buffer: UnsafeMutablePointer<UInt8>, maxLength len: Int) -> Int {
        
        let dataRange = NSRange(location: self.readOffset, length: min(len, max(self.fileLength - self.readOffset, 0)))
        
        if self.fileLength > 0 && self.readOffset >= self.fileLength {
            self._streamStatus = .atEnd
            return 0
        }
        
        self.getDataWithRange(dataRange) { (_) in
            
        } completion: { (result) in
            
        }
        
        if self._streamStatus == .closed {
            return 0
        }
        
        self.inputStream?.read(buffer, maxLength: dataRange.length)
        self.readOffset += dataRange.length
        return dataRange.length
    }
    
    private func generateTasks() {
        let taskCount = Int(ceil(Double(self.fileLength) / Double(defaultDownloadSize)))
        
        var taskDic = [Int : Task](minimumCapacity: taskCount)
        
        if taskCount == 0 {
            let tmpRange = NSRange(location: 0, length: fileLength - 1);
            taskDic[0] = .init(range: tmpRange, index: 0)
        } else {
            for i in 0..<taskCount {
                
                var tmpRange = NSRange(location: i * defaultDownloadSize, length: defaultDownloadSize - 1)
                
                //最后一个range.length不一定是kDefaultDownloadSize的整数倍，需要根据文件实际长度处理
                if i == taskCount - 1 {
                    tmpRange.length = fileLength - tmpRange.location - 1;
                }
                
                taskDic[i] = .init(range: tmpRange, index: i)
                
            }
        }
        
        self.cacheRangeDic = taskDic
    }
    
    private func getPartOfFile(with task: Task,
                       progressHandler: @escaping((Double) -> Void),
                       completion: @escaping((Result<Task, Error>) -> Void)) {
        
        var req = URLRequest(url: self.url)
        
        if task.isCached {
            progressHandler(1)
            completion(.success(task))
            return
        }
        
        if task.isRequesting {
            return
        }
        
        task.isRequesting = true
        req.setValue(task.rangeString, forHTTPHeaderField: rangeKey)
        let dataTask = self.session.dataTask(with: req) { [weak self] (data, res, err) in
            guard let self = self else {
                completion(.failure(StreamError.streamClose))
                return
            }
            
            task.isRequesting = false
            if let data = data {
                task.isCached = true
                self.fileHandle?.seek(toFileOffset: UInt64(task.range.location))
                self.fileHandle?.write(data)
                self.fileHandle?.synchronizeFile()
            }
            
            task.obs = nil
            completion(.success(task))
        }
        
        if #available(iOS 11.0, *) {
            task.obs = dataTask.observe(\.progress) { (aTask, change) in
                let fractionCompleted = aTask.progress.fractionCompleted
                progressHandler(fractionCompleted)
            }
        }
        
        dataTask.resume()
        
    }
    
}
