//
//  WebDavFile.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
//import MobileVLCKit
import FilesProvider
#else
import VLCKit
#endif

private class Coordinator: NSObject, WebDAVInputStreamDelegate {
    

    private weak var file: WebDavFile?

    init(file: WebDavFile) {
        super.init()
        self.file = file
    }
    
    func streamDidClose(_ stream: WebDAVInputStream) {
        self.file?.inputStream = nil
    }
}

class WebDavFile: File {
    
    var type: FileType = .file
    
    var url: URL
    
    var fileSize = 0
    
    fileprivate var inputStream: WebDAVInputStream?
    
    private lazy var coordinator = Coordinator(file: self)
    
    //应该是vlc的bug，需要强引用InputStream对象，否则会crash
    private static var inputStream: WebDAVInputStream?
    
    static var rootFile: File = WebDavFile(url: URL(string: "/")!, fileSize: 0)
    
    var parentFile: File? {
        return WebDavFile(url: self.url.deletingLastPathComponent(), fileSize: 0)
    }
    
    var fileManager: FileManagerProtocol {
        return _fileManager
    }
    
    var isCanDelete: Bool {
        if self.url == WebDavFile.rootFile.url {
            return false
        }
        return true
    }
    
    private lazy var _fileManager = WebDavFileManager()
    
    private lazy var fileSizeSemaphore = DispatchSemaphore(value: 0)
    
    init(with file: FileObject) {
        self.url = file.url
        self.fileSize = Int(file.size)
        self.type = (file.isDirectory || file.isSymLink) ? .folder : .file
    }
    
    init(with file: AFWebDAVMultiStatusResponse) {
        self.url = file.url ?? URL(fileURLWithPath: "")
        self.type = file.isCollection ? .folder : .file
        if self.type == .file {
            self.fileSize = Int(file.contentLength)
        }
    }
    
    init(url: URL, fileSize: Int = 0) {
        self.url = url
        self.fileSize = fileSize
        self.type = .folder
    }
    
    func createMedia() -> VLCMedia? {
        let inputStream = WebDAVInputStream(file: self)
        WebDavFile.inputStream = inputStream
        inputStream?.streamDelegate = self.coordinator
        self.inputStream = inputStream
        return VLCMedia(stream: inputStream!)
    }
    
    func getParseDataWithProgress(_ progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        let length = parseFileLength
        self.getDataWithRange(0...length, progress: progress, completion: completion)
    }
    
    func getFileSizeSync() -> Int {
        _fileManager.getFileSize(self) { res in
            
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
