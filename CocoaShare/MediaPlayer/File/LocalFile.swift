//
//  LocalFileMedia.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
//import MobileVLCKit
#else
import VLCKit
#endif

class LocalFile: File {

    lazy var fileManager: FileManagerProtocol = LocalFileManager()
    
    let type: FileType
    
    let url: URL
    
    var fileSize = 0
    
    var parentFile: File? {
        return LocalFile(with: self.url.deletingLastPathComponent())
    }
    
    static var rootFile: File = LocalFile(with: UIApplication.shared.documentsURL)
    
    init(with url: URL, fileSize: Int) {
        self.url = url
        self.fileSize = fileSize
        self.type = url.hasDirectoryPath ? .folder : .file
    }
    
    convenience init(with url: URL) {
        let attributesOfItem = try? FileManager.default.attributesOfItem(atPath:url.path)
        let size = attributesOfItem?[.size] as? Int ?? 0
        self.init(with: url, fileSize: size)
    }
    
    func createMedia() -> VLCMedia? {
        return VLCMedia(url: self.url)
    }
    
}
    
    

