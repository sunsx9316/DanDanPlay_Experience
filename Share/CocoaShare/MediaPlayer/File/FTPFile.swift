//
//  FTPFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/30.
//

#if os(iOS) || os(tvOS)

import Foundation
#if os(iOS)
import MobileVLCKit
import MPVFramework
import FilesProvider
#elseif os(tvOS)
import TVVLCKit
import MPVFramework
import FilesProvider
#endif


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
    
    func createVLCMedia(delegate: FileDelegate) -> VLCMedia? {
        let media = VLCMedia(url: self.url)
        let auth = FTPFileManager.shared.loginInfo?.auth
        
        var options = [AnyHashable : Any]()
        options["ftp-user"] = auth?.userName
        options["ftp-pwd"] = auth?.password
        media.addOptions(options)
        return media
    }
    
#if os(iOS) || os(tvOS)
    func createMPVMedia() -> MPVMedia? {
        if let auth = FTPFileManager.shared.loginInfo?.auth,
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
#endif
    
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
}

#endif
