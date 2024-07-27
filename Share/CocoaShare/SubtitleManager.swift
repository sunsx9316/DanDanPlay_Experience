//
//  SubtitleManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/4.
//

import Foundation
import ANXLog

private enum SubtitleLoadError: LocalizedError {
    case notMatch
    
    var errorDescription: String? {
        switch self {
        case .notMatch:
            return "没有匹配到本地字幕"
        }
    }
}

class SubtitleManager {
    
    static let shared = SubtitleManager()
    
    private init() {}
    
    /// 加载本地字幕
    /// - Parameter media: 视频
    func loadLocalSubtitle(_ media: File, completion: @escaping((Result<SubtitleProtocol, Error>) -> Void)) {
        if Preferences.shared.autoLoadCustomSubtitle {
            self.findCustomSubtitleWithMedia(media) { [weak self] result in
                guard self != nil else { return }
                
                switch result {
                case .success(let files):
                    if files.isEmpty {
                        completion(.failure(SubtitleLoadError.notMatch))
                        return
                    }
                    
                    var subtitleFile = files[0]
                    
                    //按照优先级加载字幕
                    if let subtitleLoadOrder = Preferences.shared.subtitleLoadOrder {
                        for keyName in subtitleLoadOrder {
                            if let matched = files.first(where: { $0.fileName.contains(keyName) }) {
                                subtitleFile = matched
                                break
                            }
                        }
                    }
                    
                    SubtitleManager.shared.downCustomSubtitle(subtitleFile) { result1 in
                        switch result1 {
                        case .success(let subtitle):
                            DispatchQueue.main.async {
                                completion(.success(subtitle))
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(.failure(error))
                            }
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(.failure(error))
                    }
                }
            }
        } else {
            completion(.failure(SubtitleLoadError.notMatch))
        }
    }
    
    func downCustomSubtitle(_ file: File, completion: @escaping((Result<SubtitleProtocol, Error>) -> Void)) {
        var cacheURL = PathUtils.cacheURL
        cacheURL.appendPathComponent(file.fileHash)
        
        let subtitle = ExternalSubtitle(subtitleName: file.url.lastPathComponent, url: cacheURL)
        
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
        type(of: media).fileManager.subtitlesOfMedia(media) { result in
            switch result {
            case .success(let files):
                ANX.logInfo(.subtitle, "字幕搜索成功 \(files)")
                completion(.success(files))
            case .failure(let error):
                ANX.logInfo(.subtitle, "字幕搜索失败 \(error)")
                completion(.failure(error))
            }
        }
    }
}
