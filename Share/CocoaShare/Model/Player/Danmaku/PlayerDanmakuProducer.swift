//
//  PlayerDanmakuProducer.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/16.
//

import Foundation
import RxSwift

typealias DanmakuFilterProgress = (filtered: Int, total: Int)

/// 弹幕生产者
class PlayerDanmakuProducer {
    
    private var rawDanmakus = DanmakuMapResult()
    
    private var filterDanmakus = DanmakuMapResult()
    
    private let lock = NSLock()
    
    private let danmakuContext: PlayerDanmakuContext!
    
    init(danmakuContext: PlayerDanmakuContext) {
        self.danmakuContext = danmakuContext
    }
    
    func danmaku(at time: UInt) -> [DanmakuEntity]? {
        self.lock.lock()
        let danmaku = self.filterDanmakus[time]
        self.lock.unlock()
        return danmaku
    }
    
    func setupDanmaku(_ danmakus: DanmakuMapResult) -> Observable<DanmakuFilterProgress> {
        self.lock.lock()
        self.filterDanmakus.removeAll()
        self.lock.unlock()
        
        self.rawDanmakus = danmakus
        return startFilter(from: 0, forceParse: true)
    }
    
    
    /// 开始过滤弹幕
    /// - Parameters:
    ///   - time: 从什么时间开始过滤
    ///   - forceParse: 是否强制解析，true时，会再次解析之前解析过的弹幕
    /// - Returns: 信号
    func startFilter(from time: UInt, forceParse: Bool) -> Observable<DanmakuFilterProgress>  {
        return Observable<DanmakuFilterProgress>.create { [weak self] sub in
            guard let self = self else { return Disposables.create() }
            
            if let filterList = (try? self.danmakuContext.filterDanmakus.value()) {
                
                let rawDanmakus = self.rawDanmakus
                let sortKeys = rawDanmakus.keys.sorted(by: <)
                
                DispatchQueue.global().async { [weak self] in
                    guard let self = self else { return }
                    
                    /// 如果指定了时间，则从>该时间的地方开始遍历
                    var startIndex = sortKeys.firstIndex { $0 >= time } ?? 0
                    var idx = 0
                    while idx < sortKeys.count {
                        
                        defer {
                            idx += 1
                            startIndex = (startIndex + 1) % sortKeys.count
                        }
                        
                        let aTime = sortKeys[startIndex]
                        
                        guard let danmakus = rawDanmakus[aTime] else { continue }
                        
                        self.lock.lock()
                        let isParsed = self.filterDanmakus[aTime] != nil
                        self.lock.unlock()
                        
                        /// 已经解析过
                        if isParsed && !forceParse {
                            continue
                        }
                        
//                        debugPrint("开始解析弹幕 time: \(aTime)")
                        
                        for danmaku in danmakus {
                            danmaku.isFilter = self.isMatch(danmaku: danmaku, filterDanmakus: filterList)
                        }
                        
                        self.lock.lock()
                        self.filterDanmakus[aTime] = danmakus
                        self.lock.unlock()
                        
                        sub.onNext((idx, sortKeys.count))
                    }
                    
//                    debugPrint("解析弹幕完成")
                    sub.onCompleted()
                }
            } else {
                self.lock.lock()
                self.filterDanmakus = self.rawDanmakus
                self.lock.unlock()
                
                sub.onCompleted()
            }
            
            return Disposables.create()
        }.observe(on: MainScheduler.instance)
    }
    
    /// 是否命中屏蔽列表
    private func isMatch(danmaku: DanmakuEntity, filterDanmakus: [FilterDanmaku]) -> Bool {
        /// 过滤弹幕
        for filterDanmaku in filterDanmakus {
            guard let text = filterDanmaku.text, filterDanmaku.isEnable else { continue }
            
            if filterDanmaku.isRegularExp {
                if danmaku.text.matchesRegex(text, options: []) {
                    return true
                }
            } else {
                if danmaku.text == text {
                    return true
                }
            }
        }
        
        return false
    }
    
}
