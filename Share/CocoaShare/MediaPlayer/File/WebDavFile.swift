import YYCategories
//
//  WebDavFile.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
import VLCKit
import MPVFramework
import FilesProvider


class WebDavFile: File {
    
    var type: FileType = .file
    
    var url: URL
    
    var path: String
    
    var fileSize = 0
    
    static var rootFile: File = WebDavFile(url: URL(string: "/")!, fileSize: 0)
    
    var parentFile: File? {
        get {
            if let _parentFile = self._parentFile {
                return _parentFile
            }
            return WebDavFile(url: self.url.deletingLastPathComponent(), fileSize: 0)
        }
        
        set {
            self._parentFile = newValue
        }
    }

    private weak var _parentFile: File?
    
    static var fileManager: FileManagerProtocol {
        return WebDavFileManager.shared
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
    
    func createVLCMedia(delegate: FileDelegate) -> VLCMedia? {
        
        if let auth = WebDavFileManager.shared.loginInfo?.auth,
            var components = URLComponents(string: self.url.absoluteString) {
            // 直接赋值新的凭据，它会自动替换掉旧的
            components.user = auth.userName
            components.password = auth.password
            
            if let newURL = components.url {
                return VLCMedia(url: newURL)
            }
        }
        
        let media = VLCMedia(url: self.url)
        return media
    }
    
    func createMPVMedia() -> MPVMedia? {
        if let auth = WebDavFileManager.shared.loginInfo?.auth,
            var components = URLComponents(string: self.url.absoluteString) {
            // 直接赋值新的凭据，它会自动替换掉旧的
            components.user = auth.userName
            components.password = auth.password

            if let newURL = components.url {
                return MPVMedia(url: newURL)
            }
        }

        let media = MPVMedia(url: self.url)
        return media
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
