//
//  SubtitleManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/4.
//

import Foundation

class SubtitleManager {
    
    static let shared = SubtitleManager()
    
    private init() {}
    
    func downCustomSubtitle(_ file: File, completion: @escaping((Result<SubtitleProtocol, Error>) -> Void)) {
        var cacheURL = UIApplication.shared.cachesURL
        cacheURL.appendPathComponent(file.fileHash)
        
        let subtitle = ExternalSubtitle(name: file.url.lastPathComponent, url: cacheURL)
        
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            file.getDataWithProgress(nil) { result in
                switch result {
                case .success(let data):
                    do {
                        try data.write(to: cacheURL, options: .atomic)
                        completion(.success(subtitle))
                    } catch (let error) {
                        completion(.failure(error))
                    }
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success(subtitle))
        }
    }
    
    func findCustomSubtitleWithMedia(_ media: File, completion: @escaping((Result<[File], Error>) -> Void)) {
        //加载本地弹幕
        if let parentFile = media.parentFile {
            let name = media.url.deletingPathExtension().lastPathComponent
            media.fileManager.subtitlesOfDirectory(at: parentFile) { result in
                switch result {
                case .success(let files):
                    let subtitleFiles = files.filter({ $0.url.lastPathComponent.contains(name) })
                    completion(.success(subtitleFiles))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success([]))
        }
    }
}
