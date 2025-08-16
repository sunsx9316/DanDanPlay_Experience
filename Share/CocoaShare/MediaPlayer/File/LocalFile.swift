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
    
    var fileId: String = ""
    
    var parentFile: File? {
        return LocalFile(with: self.url.deletingLastPathComponent())
    }
    
    static var rootFile: File = LocalFile(with: PathUtils.documentsURL)
    
    private init(with url: URL, fileSize: Int, fileId: String) {
        self.url = url
        self.fileSize = fileSize
        self.fileId = fileId
        self.type = url.hasDirectoryPath ? .folder : .file
    }
    
    convenience init(with url: URL) {
        let attributesOfItem = try? FileManager.default.attributesOfItem(atPath:url.path)
        let size = attributesOfItem?[.size] as? Int ?? 0
        
        /// 本地文件每次启动的路径都会变，这里结合文件信息和名称确定id
        var fileId = url.lastPathComponent
        if let createDate = attributesOfItem?[.creationDate] as? Date {
            let dateFormatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ss_SSSFormatter
            fileId += dateFormatter.string(from: createDate)
        }
        
        let fileHash = fileId.md5() ?? ""
        self.init(with: url, fileSize: size, fileId: fileHash)
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
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        return VLCMedia(url: self.url)
    }
    
}
    
    

