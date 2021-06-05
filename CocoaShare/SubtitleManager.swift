//
//  SubtitleManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/4.
//

import Foundation

enum SubtitleError: LocalizedError {
    case customSubtitleNotExit
    
    var errorDescription: String? {
        switch self {
        case .customSubtitleNotExit:
            return "本地字幕不存在"
        }
    }
}

class SubtitleManager {
    
    
    
    static let shared = SubtitleManager()
    
    private init() {}
    
    func loadCustomSubtitleWithMedia(_ media: File, completion: @escaping((Result<URL, Error>) -> Void)) {
        //加载本地弹幕
        if let parentFile = media.parentFile {
            let name = media.url.deletingPathExtension().lastPathComponent
            media.fileManager.subtitlesOfDirectory(at: parentFile) { result in
                switch result {
                case .success(let files):
                    if let file = files.first(where: { $0.url.lastPathComponent.contains(name) }) {
                        
                        var cacheURL = UIApplication.shared.cachesURL
                        cacheURL.appendPathComponent(file.fileHash)
                        
                        if !FileManager.default.fileExists(atPath: cacheURL.path) {
                            file.getDataWithProgress(nil) { result in
                                switch result {
                                case .success(let data):
                                    do {
                                        try data.write(to: cacheURL)
                                        completion(.success(cacheURL))
                                    } catch (let error) {
                                        completion(.failure(error))
                                    }
                                case .failure(let error):
                                    completion(.failure(error))
                                }
                            }
                        } else {
                            completion(.success(cacheURL))
                        }
                    } else {
                        completion(.failure(SubtitleError.customSubtitleNotExit))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.failure(SubtitleError.customSubtitleNotExit))
        }
    }
}
