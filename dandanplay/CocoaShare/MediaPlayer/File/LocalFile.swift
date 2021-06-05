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

open class LocalFile: File {
    
    var media: VLCMedia? {
        return VLCMedia(url: self.url)
    }
    
    var fileManager: FileManagerProtocol {
        return LocalFileManager()
    }
    
    var type: FileType = .file
    
    let url: URL
    
    var fileSize = 0
    
    init(with url: URL, fileSize: Int) {
        self.url = url
        self.fileSize = fileSize
    }
    
    convenience init(with url: URL) {
        let attributesOfItem = try? FileManager.default.attributesOfItem(atPath:url.path)
        let size = attributesOfItem?[.size] as? Int ?? 0
        self.init(with: url, fileSize: size)
    }
    
    func getDataWithRange(_ range: ClosedRange<Int>, progress: @escaping (FileProgressAction), completion: @escaping ((Result<Data, Error>) -> Void)) {
        do {
            let length = range.upperBound - range.lowerBound
            let fileHandle = try FileHandle(forReadingFrom: self.url)
            
            fileHandle.seek(toFileOffset: UInt64(range.lowerBound))
            let allData = fileHandle.readData(ofLength: length)
            
            progress(1)
            completion(.success(allData))
        } catch let error {
            progress(1)
            completion(.failure(error))
        }
    }
    
}
    
    

