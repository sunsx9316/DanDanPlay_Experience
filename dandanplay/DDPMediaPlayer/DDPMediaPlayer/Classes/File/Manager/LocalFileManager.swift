//
//  LocalFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation

class LocalFileManager: FileManagerProtocol {
    
    static let shared = LocalFileManager()
    
    func contentsOfDirectory(at url: URL, filter: @escaping((URL) -> Bool), completion: @escaping (([File]) -> Void)) {
        let shouldStop = url.startAccessingSecurityScopedResource()
        defer {
            if shouldStop {
                url.stopAccessingSecurityScopedResource()
            }
        }
        
        if let urls = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
            let files = urls.compactMap { (aURL) -> File? in
                let file = LocalFile(with: aURL)
                file.type = aURL.isFileURL ? .file : .folder
                if filter(aURL) {
                    return file
                }
                return nil
            }
            completion(files)
        } else {
            completion([])
        }
    }
}
