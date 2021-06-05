//
//  LocalFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation

class LocalFileManager: FileManagerProtocol {
    
    var desc: String {
        return "本地文件"
    }
    
    func contentsOfDirectory(at url: URL, completion: @escaping (([File]) -> Void)) {
        
        do {
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            let files = urls.compactMap { (aURL) -> File? in
                let file = LocalFile(with: aURL)
                file.type = aURL.hasDirectoryPath ? .folder : .file
                return file
            }
            completion(files)
        } catch let error {
            debugPrint("读取文件出错: \(error)")
            completion([])
        }
    }
}
