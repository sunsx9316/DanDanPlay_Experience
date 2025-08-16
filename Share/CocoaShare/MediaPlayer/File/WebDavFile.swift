//
//  WebDavFile.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

#if os(iOS)

import Foundation
import MobileVLCKit
import FilesProvider


class WebDavFile: File {
    
    var type: FileType = .file
    
    var url: URL
    
    var path: String
    
    var fileSize = 0
    
    fileprivate var inputStream: WebDAVInputStream?
    
    //应该是vlc的bug，需要强引用InputStream对象，否则会crash
    private static var inputStream: WebDAVInputStream?
    
    static var rootFile: File = WebDavFile(url: URL(string: "/")!, fileSize: 0)
    
    var parentFile: File? {
        get {
            if let _parentFile = self._parentFile {
                return _parentFile
            }
            return WebDavFile(url: self.url.deletingLastPathComponent(), fileSize: 0)
        }
        
        set {
            self._parentFile = newValue as? (File & AnyObject)
        }
    }
    
    private weak var _parentFile: (File & AnyObject)?
    
    static var fileManager: FileManagerProtocol {
        return WebDavFileManager.shared
    }
    
    var bufferInfos: [MediaBufferInfo] {
        return inputStream?.taskInfos ?? []
    }
    
    private weak var fileDelegate: FileDelegate?
    
    private lazy var fileSizeSemaphore = DispatchSemaphore(value: 0)
    
    init(with file: FileObject) {
        self.url = file.url
        self.path = file.path
        self.fileSize = Int(file.size)
        self.type = (file.isDirectory || file.isSymLink) ? .folder : .file
    }
    
    init(url: URL, fileSize: Int = 0) {
        self.url = url
        self.fileSize = fileSize
        self.type = .folder
        self.path = self.url.path
    }
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        let inputStream = WebDAVInputStream(file: self)
        WebDavFile.inputStream = inputStream
        inputStream?.streamDelegate = self
        self.inputStream = inputStream
        self.fileDelegate = delegate
        return VLCMedia(stream: inputStream!)
    }
    
    func getFileHashWithProgress(_ progress: FileProgressAction?,
                                 completion: @escaping((Result<String, Error>) -> Void)) {
        let length = parseFileLength
        self.getDataWithRange(0...length, progress: progress) { result in
            switch result {
            case .success(let data):
                let hash = (data as NSData).md5String()
                completion(.success(hash))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func getFileSizeSync() -> Int {
        WebDavFileManager.shared.getFileSize(self) { res in
            
            switch res {
            case .success(let size):
                self.fileSize = size
            case .failure(_):
                break
            }
            
            self.fileSizeSemaphore.signal()
        }
        
        _ = self.fileSizeSemaphore.wait(timeout: .distantFuture)
        
        return self.fileSize
    }
   
}

extension WebDavFile: WebDAVInputStreamDelegate {
    func streamDidClose(_ stream: WebDAVInputStream) {
        self.inputStream = nil
    }
    
    func streamTaskInfoDidChange(_ stream: WebDAVInputStream, taskInfo: WebDAVInputStream.TaskInfo) {
        self.fileDelegate?.mediaBufferDidChange(file: self, bufferInfo: taskInfo)
    }
}

#endif
