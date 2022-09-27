//
//  FTPFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

#if os(iOS)

import Foundation
import MobileVLCKit
import FilesProvider


class FTPFile: File {
    
    var type: FileType = .file
    
    var url: URL
    
    var fileSize = 0
    
    let path: String
    
    static var rootFile: File = FTPFile(url: URL(string: "/")!, fileSize: 0)
    
    var parentFile: File? {
        return FTPFile(url: self.url.deletingLastPathComponent(), fileSize: 0)
    }
    
    static var fileManager: FileManagerProtocol {
        return FTPFileManager.shared
    }
    
    var isCanDelete: Bool {
        if self.url == FTPFile.rootFile.url {
            return false
        }
        return true
    }
    
    init(with file: FileObject) {
        self.url = file.url
        self.path = file.path
        self.fileSize = Int(file.size)
        self.type = (file.isDirectory || file.isSymLink) ? .folder : .file
    }
    
    private init(url: URL, fileSize: Int = 0) {
        self.url = url
        self.path = ""
        self.fileSize = fileSize
        self.type = .folder
    }
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        let media = VLCMedia(url: self.url)
        let auth = FTPFileManager.shared.loginInfo?.auth
        
        var options = [AnyHashable : Any]()
        options["ftp-user"] = auth?.userName
        options["ftp-pwd"] = auth?.password
        media.addOptions(options)
        return media
    }
    
    func getParseDataWithProgress(_ progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        let length = parseFileLength
        self.getDataWithRange(0...length, progress: progress, completion: completion)
    }
}

#endif