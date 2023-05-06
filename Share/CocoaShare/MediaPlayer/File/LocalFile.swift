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
    
    init(with url: URL, fileSize: Int) {
        self.url = url
        self.fileSize = fileSize
        self.type = url.hasDirectoryPath ? .folder : .file
    }
    
    func getFileHashWithProgress(_ progress: FileProgressAction?,
                                 completion: @escaping((Result<String, Error>) -> Void)) {
        let length = parseFileLength + 1
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
    
    convenience init(with url: URL) {
        let attributesOfItem = try? FileManager.default.attributesOfItem(atPath:url.path)
        let size = attributesOfItem?[.size] as? Int ?? 0
        self.init(with: url, fileSize: size)
    }
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        return VLCMedia(url: self.url)
    }
    
}
    
    

