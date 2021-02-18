//
//  LocalFileMedia.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation

open class LocalFile: File {
    
    public var fileManager: FileManagerProtocol {
        return LocalFileManager.shared
    }
    
    public var type: FileType = .file
    
    public let url: URL
    
    public var fileSize = 0
    
    public init(with url: URL, fileSize: Int) {
        self.url = url
        self.fileSize = fileSize
    }
    
    public convenience init(with url: URL) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        let attributesOfItem = try? FileManager.default.attributesOfItem(atPath:url.path)
        let size = attributesOfItem?[.size] as? Int ?? 0
        self.init(with: url, fileSize: size)
    }
    
    public func getDataWithRange(_ range: ClosedRange<Int>, progress: @escaping (FileProgressAction), completion: @escaping ((Result<Data, Error>) -> Void)) {
        let shouldStop = self.url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                self.url.stopAccessingSecurityScopedResource()
            }
        }
        
        var error: NSError?
        NSFileCoordinator().coordinate(readingItemAt: self.url, error: &error) { (aURL) in
            do {
                let length = range.upperBound - range.lowerBound + 1
                let fileHandle = try FileHandle(forReadingFrom: aURL)
                var allData = Data()
                let everyReadSize = 512
                
                let totalTaskCount = Int(Double(length) / Double(everyReadSize))
                let remainder = length % everyReadSize
                
                for i in 0..<totalTaskCount {
                    let offset = i * everyReadSize + range.lowerBound
                    fileHandle.seek(toFileOffset: UInt64(offset))
                    allData.append(fileHandle.readData(ofLength: everyReadSize))
                    let schedule = Double(allData.count) / Double(length)
                    progress(schedule)
                }
                
                if remainder != 0 {
                    fileHandle.seek(toFileOffset: UInt64(totalTaskCount * everyReadSize))
                    allData.append(fileHandle.readData(ofLength: remainder))
                }
                
                progress(1)
                completion(.success(allData))
            } catch let error {
                progress(1)
                completion(.failure(error))
            }
        }
    }
    
}
    
    

