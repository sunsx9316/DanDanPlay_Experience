//
//  SubtitleManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/4.
//

import Foundation
import ANXLog

class SubtitleManager {
    
    static let shared = SubtitleManager()
    
    private init() {}
    
    func downCustomSubtitle(_ file: File, completion: @escaping((Result<SubtitleProtocol, Error>) -> Void)) {
        var cacheURL = PathUtils.cacheURL
        cacheURL.appendPathComponent(file.fileHash)
        
        let subtitle = ExternalSubtitle(name: file.url.lastPathComponent, url: cacheURL)
        
        if !FileManager.default.fileExists(atPath: cacheURL.path) {
            file.getDataWithProgress(nil) { result in
                switch result {
                case .success(let data):
                    do {
                        ANX.logInfo(.subtitle, "字幕解析成功 \(data.count)")
                        try data.write(to: cacheURL, options: .atomic)
                        completion(.success(subtitle))
                    } catch (let error) {
                        ANX.logInfo(.subtitle, "字幕解析失败 \(error)")
                        completion(.failure(error))
                    }
                case .failure(let error):
                    ANX.logInfo(.subtitle, "字幕下载失败 \(error)")
                    completion(.failure(error))
                }
            }
        } else {
            ANX.logInfo(.subtitle, "字幕有缓存")
            completion(.success(subtitle))
        }
    }
    
    func findCustomSubtitleWithMedia(_ media: File, completion: @escaping((Result<[File], Error>) -> Void)) {
        //加载本地弹幕
        if let parentFile = media.parentFile {
            let name = media.url.deletingPathExtension().lastPathComponent
            type(of: media).fileManager.subtitlesOfDirectory(at: parentFile) { result in
                switch result {
                case .success(let files):
                    let subtitleFiles = files.filter({ $0.url.lastPathComponent.contains(name) })
                    ANX.logInfo(.subtitle, "字幕搜索成功 \(subtitleFiles)")
                    completion(.success(subtitleFiles))
                case .failure(let error):
                    ANX.logInfo(.subtitle, "字幕搜索失败 \(error)")
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success([]))
        }
    }
}
