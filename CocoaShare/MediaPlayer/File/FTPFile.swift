//
//  FTPFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

import Foundation
#if os(iOS)
import MobileVLCKit
import FilesProvider
#else
import VLCKit
#endif

class FTPFile: File {
    
    var type: FileType = .file
    
    var url: URL
    
    var fileSize = 0
    
    let path: String
    
    static var rootFile: File {
        return FTPFile(url: URL(string: "/")!, fileSize: 0)
    }
    
    var parentFile: File? {
        return FTPFile(url: self.url.deletingLastPathComponent(), fileSize: 0)
    }
    
    var fileManager: FileManagerProtocol {
        return FTPFileManager.shared
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
    
    func createMedia() -> VLCMedia? {
        let media = VLCMedia(url: self.url)
        let auth = FTPFileManager.shared.loginInfo?.auth
        
        var options = [AnyHashable : Any]()
        options["ftp-user"] = auth?.userName
        options["ftp-pwd"] = auth?.password
        media.addOptions(options)
        return media
    }
    
}
