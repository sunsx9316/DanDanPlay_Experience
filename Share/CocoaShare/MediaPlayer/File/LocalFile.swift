//
//  LocalFileMedia.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
import MobileVLCKit
#else
import VLCKit
#endif

class LocalFile: File {

    static var fileManager: FileManagerProtocol {
        return LocalFileManager.shared
    }
    
    let type: FileType
    
    let url: URL
    
    var fileSize = 0
    
    var parentFile: File? {
        return LocalFile(with: self.url.deletingLastPathComponent())
    }
    
    static var rootFile: File = LocalFile(with: PathUtils.documentsURL)
    
    var isCanDelete: Bool {
        if self.url == LocalFile.rootFile.url {
            return false
        }
        return true
    }
    
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
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        return VLCMedia(url: self.url)
    }
    
}
    
    
