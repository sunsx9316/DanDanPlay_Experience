//
//  CacheManager.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/5/3.
//

import Foundation

class CacheManager {
    
    static let shared = CacheManager()
    
    func danmakuCacheWithEpisodeId(_ episodeId: Int, parametersHash: String) -> Data? {
        let episodeFolderURL = PathUtils.cacheURL.appendingPathComponent("\(episodeId)")
        let cacheURL = episodeFolderURL.appendingPathComponent(parametersHash)
        
        if FileManager.default.fileExists(atPath: cacheURL.path) {
            
            do {
                
                if let modificationDate = try FileManager.default.attributesOfItem(atPath: cacheURL.path)[.modificationDate] as? NSDate,
                   let limitDate = modificationDate.addingDays(Preferences.shared.danmakuCacheDay) {
                    
                    let now = Date()
                    //当前时间在有效期范围内，缓存均有效
                    if now <= limitDate {
                        let data = try Data(contentsOf: cacheURL)
                        debugPrint("\(episodeId) 命中缓存")
                        return data
                    }
                }
                
                return nil
            } catch let error {
                debugPrint("读取缓存出错 episodeId:\(episodeId), error:\(error)")
                return nil
            }
        }
        return nil
    }
    
    func setDanmakuCacheWithEpisodeId(_ episodeId: Int, parametersHash: String, data: Data?) {
        do {
            let episodeFolderURL = PathUtils.cacheURL.appendingPathComponent("\(episodeId)")
            let cacheURL = episodeFolderURL.appendingPathComponent(parametersHash)
            
            try FileManager.default.createDirectory(at: episodeFolderURL, withIntermediateDirectories: true, attributes: nil)
            try data?.write(to: cacheURL, options: .atomic)
        } catch let err {
            debugPrint("弹幕写缓存出错 \(err)")
        }
    }
    
    func matchHashWithFile(_ file: File) -> String? {
        let episodeFolderURL = PathUtils.cacheURL.appendingPathComponent("fileHash.plist")
        if let dic = NSDictionary(contentsOf: episodeFolderURL) as? [AnyHashable : [AnyHashable : Any]] {
            let values = dic[file.fileHash]
            return values?["hash"] as? String
        }
        return nil
    }
    
    func setMatchHashWithFile(_ file: File, hash: String) {
        let episodeFolderURL = PathUtils.cacheURL.appendingPathComponent("fileHash.plist")
        let dic = NSMutableDictionary(contentsOf: episodeFolderURL) ?? .init()
        dic[file.fileHash] = ["hash" : hash]
        do {
            try dic.write(to: episodeFolderURL)
        } catch let error {
            debugPrint("写入缓存失败  file:\(file), hash:\(hash) error:\(error)")
        }
    }
    
    func matchResultWithHash(_ hash: String) -> Data? {
        let episodeFolderURL = PathUtils.cacheURL.appendingPathComponent("matchResult").appendingPathComponent(hash)
        
        do {
            let data = try Data(contentsOf: episodeFolderURL)
            return data
        } catch {
            return nil
        }
    }
    
    func setMatchResultWithHash(_ hash: String, data: Data) {
        let episodeFolderURL = PathUtils.cacheURL.appendingPathComponent("matchResult")
        
        if !FileManager.default.fileExists(atPath: episodeFolderURL.path) {
            do {
                try FileManager.default.createDirectory(at: episodeFolderURL, withIntermediateDirectories: true)
            } catch {
                debugPrint("创建缓存文件失败 hash:\(hash) error:\(error)")
            }
        }
        
        do {
            try data.write(to: episodeFolderURL.appendingPathComponent(hash))
        } catch let error {
            debugPrint("写入缓存失败 hash:\(hash) error:\(error)")
        }
    }
    
    func cleanupCache() {
        do {
            try FileManager.default.removeItem(at: PathUtils.cacheURL)
        } catch {
            debugPrint("缓存删除失败 error:\(error)")
        }
    }
}
