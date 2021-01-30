//
//  WebDavInputStream.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/1/18.
//

import Foundation

private class WebDavPartTask {
    
    private(set)var rangeString = ""
    private(set)var range = NSRange(location: 0, length: 0)
    private(set)var index = 0
    var downloadProgress: CGFloat = 0
    var requesting = false
    
    init(with range: NSRange, index: Int) {
        self.range = range
        self.index = index
        self.rangeString = "bytes=\(range.location)-\(range.upperBound)"
    }
}

class WebDavInputStream: InputStream {
    
    struct Access {
        let name: String
        let password: String
    }
    
    private let defaultDownloadSize = 16 * 1024 * 1024
    private var url: URL
    private var readOffset = 0 {
        didSet {
            self.inputStream?.setProperty(self.readOffset, forKey: .fileCurrentOffsetKey)
        }
    }
    private var fileLength = 0
    private var inputStream: InputStream?
    private var fileHandle: FileHandle?
    private var _streamStatus = Stream.Status.notOpen
    private weak var weakDelegate: StreamDelegate?
    
    private var cacheRangeDic: [Int : WebDavPartTask]?
    
    private lazy var session: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return session
    }()
    
    private var access: Access?
    
    override var delegate: StreamDelegate? {
        get {
            return self.weakDelegate
        }
        
        set {
            self.weakDelegate = newValue
        }
    }
    
    init?(url: URL, fileLength: Int? = nil, access: Access?) {
        self.url = url
        
        super.init(url: url)
        self.access = access
        
        if let cachePath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first as NSString? {
            let cacheFilePath = cachePath.appendingPathComponent(url.lastPathComponent)
            
            if FileManager.default.fileExists(atPath: cacheFilePath) {
                try? FileManager.default.removeItem(atPath: cacheFilePath)
            }
            
            FileManager.default.createFile(atPath: cacheFilePath, contents: nil, attributes: nil)
            self.fileHandle = FileHandle(forWritingAtPath: cacheFilePath)
            self.inputStream = InputStream(fileAtPath: cacheFilePath)
        }
        
        if let fileLength = fileLength {
            self.fileLength = fileLength
        }
        
    }
    
    override func open() {
        _streamStatus = .open
        self.inputStream?.open()
    }
    
    override func close() {
        _streamStatus = .closed
        self.inputStream?.close()
        self.fileHandle?.closeFile()
        self.delegate?.stream?(self, handle: .endEncountered)
    }
    
    override var hasBytesAvailable: Bool {
        if self.fileLength > 0 {
            return self.fileLength - self.readOffset > 0
        }
        return false
    }
    
    override func property(forKey key: Stream.PropertyKey) -> Any? {
        guard key == .fileCurrentOffsetKey else {
            return nil
        }
        
        return self.readOffset
    }
    
    override func setProperty(_ property: Any?, forKey key: Stream.PropertyKey) -> Bool {
        guard key == .fileCurrentOffsetKey, let offset = property as? Int else {
            return false
        }
        
        self.readOffset = offset
        return true
    }
    
    override func getBuffer(_ buffer: UnsafeMutablePointer<UnsafeMutablePointer<UInt8>?>, length len: UnsafeMutablePointer<Int>) -> Bool {
        return false
    }
    
    //MARK:Private Method
    private func generateTasksWithFileLength(_ fileLength: Int) -> [Int : WebDavPartTask] {
        if fileLength == 0 {
            return [:]
        }
        
        self.fileLength = fileLength
        
        let taskCount = Int(ceil(Double(fileLength) / Double(defaultDownloadSize)))
        var taskDic = [Int : WebDavPartTask](minimumCapacity: taskCount)
        
        if taskCount == 0 {
            let range = NSRange(location: 0, length: fileLength - 1)
            taskDic[0] = .init(with: range, index: 0)
        } else {
            
            for idx in 0..<taskCount {
                var tmpRange = NSRange(location: idx * defaultDownloadSize, length: defaultDownloadSize - 1)
                //最后一个range.length不一定是defaultDownloadSize的整数倍，需要根据文件实际长度处理
                if idx == taskCount - 1 {
                    tmpRange.length = fileLength - tmpRange.location - 1
                }
                
                taskDic[idx] = .init(with: tmpRange, index: idx)
            }
        }
        
        return taskDic
    }
    
    private func generateTasksUnknowFileLength(_ completion: @escaping(([Int : WebDavPartTask]) -> Void)) {
        var req = URLRequest(url: self.url)
        req.setValue("bytes=0-1024", forHTTPHeaderField: "Range")
        self.session.dataTask(with: req) { (data, res, error) in
            
            guard data != nil,
                  let res = res as? HTTPURLResponse,
                  let contentRange = res.allHeaderFields["Content-Range"] as? String,
                  let fileLength = contentRange.components(separatedBy: "/").last else {
                completion([:])
                return
            }
            
            completion(self.generateTasksWithFileLength(Int(fileLength) ?? 0))
        }.resume()
    }
}

extension WebDavInputStream: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        
        if challenge.previousFailureCount > 0 {
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            if let access = self.access {
                let credential = URLCredential(user: access.name, password: access.password, persistence: .forSession)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
    
    
}
