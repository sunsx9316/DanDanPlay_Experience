//
//  PlayerDanmakuModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/3.
//

import Foundation
import RxSwift
import RxCocoa
import DanmakuRender

// MARK: - 便捷接口
extension PlayerDanmakuModel {
    var danmakuSpeed: Double {
        return (try? self.context.danmakuSpeed.value()) ?? 0
    }
    
    var danmakuFontSize: CGFloat {
        return Preferences.shared.danmakuFontSize
    }
    
    var danmakuArea: DanmakuArea {
        return (try? self.context.danmakuArea.value()) ?? .area_1_1
    }
    
    var isShowDanmaku: Bool {
        return (try? self.context.isShowDanmaku.value()) ?? false
    }
    
    var danmakuOffsetTime: Int {
        return (try? self.context.danmakuOffsetTime.value()) ?? 0
    }
    
    var danmakuDensity: Float {
        return (try? self.context.danmakuDensity.value()) ?? 0
    }
    
    var isMergeSameDanmaku: Bool {
        return (try? self.context.isMergeSameDanmaku.value()) ?? false
    }
    
    var danmakuView: ANXView {
        return self.danmakuRender.canvas
    }
    
    var danmakuAlpha: Float {
        return (try? self.context.danmakuAlpha.value()) ?? 0
    }
    
    var danmakuSetting: [DanmakuSetting] {
        return DanmakuSetting.allCases
    }
}

/// 弹幕设置
class PlayerDanmakuModel {
    
    lazy var context = PlayerDanmakuContext()
    
    /// 当前弹幕的时间
    private var danmakuTime: UInt?
    
    private lazy var danmakuRender: DanmakuEngine = {
        let danmakuRender = DanmakuEngine()
        danmakuRender.layoutStyle = .nonOverlapping
        return danmakuRender
    }()
    
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = DanmakuMapResult()
    
    /// 记录当前屏幕展示的弹幕
    private lazy var danmuOnScreenMap = [String: BaseDanmaku]()
    
    private lazy var disposeBag = DisposeBag()
    
    private var mediaContext: PlayerMediaContext!
    
    
    // MARK: Public
    init(mediaContext: PlayerMediaContext) {
        self.mediaContext = mediaContext
        self.bindDanmakuContext()
        self.bindMediaContext()
    }
    
    // MARK: - 工具方法
    func onChangeDanmakuAlpha(_ danmakuAlpha: Float) {
        Preferences.shared.danmakuAlpha = Double(danmakuAlpha)
        self.context.danmakuAlpha.onNext(danmakuAlpha)
    }
    
    func onChangeDanmakuFontSize(_ danmakuFontSize: Double) {
        Preferences.shared.danmakuFontSize = danmakuFontSize
        let font = ANXFont.systemFont(ofSize: danmakuFontSize)
        self.context.danmakuFont.onNext(font)
    }
    
    func onChangeDanmakuSpeed(_ danmakuSpeed: Double) {
        Preferences.shared.danmakuSpeed = danmakuSpeed
        self.context.danmakuSpeed.onNext(danmakuSpeed)
    }
    
    func onChangeDanmakuArea(_ danmakuArea: DanmakuArea) {
        Preferences.shared.danmakuArea = danmakuArea
        self.context.danmakuArea.onNext(danmakuArea)
    }
    
    func onChangeIsShowDanmaku(_ showDanmaku: Bool) {
        Preferences.shared.isShowDanmaku = showDanmaku
        self.context.isShowDanmaku.onNext(showDanmaku)
    }
    
    func onChangeDanmakuOffsetTime(_ danmakuOffsetTime: Int) {
        Preferences.shared.danmakuOffsetTime = danmakuOffsetTime
        self.danmakuRender.offsetTime = TimeInterval(danmakuOffsetTime)
        
        self.context.danmakuOffsetTime.onNext(danmakuOffsetTime)
    }
    
    func onChangeDanmakuDensity(_ danmakuDensity: Float) {
        Preferences.shared.danmakuDensity = danmakuDensity
        self.context.danmakuDensity.onNext(danmakuDensity)
    }
    
    func onChangeIsMergeSameDanmaku(_ isMergeSameDanmaku: Bool) {
        Preferences.shared.isMergeSameDanmaku = isMergeSameDanmaku
        self.context.isMergeSameDanmaku.onNext(isMergeSameDanmaku)
    }
    
    func changeMediaTime(_ mediaTime: TimeInterval) {
        self.danmakuRender.time = mediaTime
    }
    
    
    /// 发送弹幕
    /// - Parameter danmaku: 弹幕
    func sendDanmaku(_ danmaku: Comment) {
        //            if !text.isEmpty {
        //                let danmaku = DanmakuModel()
        //                danmaku.mode = .normal
        //                danmaku.time = self.danmakuRender.currentTime + self.danmakuRender.offsetTime
        //                danmaku.message = text
        //                danmaku.id = "\(Date().timeIntervalSince1970)"
        //
        //                let msg = SendDanmakuMessage()
        //                msg.danmaku = danmaku
        //                msg.episodeId = episodeId
        //                #warning("待处理")
        ////                MessageHandler.sendMessage(msg)
        //
        ////                self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
        //            }
    }
    
    
    /// 用户手动加载弹幕
    /// - Parameter file: 文件
    /// - Returns: 加载状态
    func loadDanmakuByUser(_ file: File) -> Observable<Void> {
        return Observable<Void>.create { [weak self] (sub) in
            
            DanmakuManager.shared.downCustomDanmaku(file) { [weak self] result1 in
                
                switch result1 {
                case .success(let url):
                    do {
                        let converResult = try DanmakuManager.shared.conver(url)
                        DispatchQueue.main.async {
                            self?.danmakuDic = converResult
                            
                            sub.onCompleted()
                        }
                    } catch let error {
                        DispatchQueue.main.async {
                            sub.onError(error)
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        sub.onError(error)
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// 开始播放
    /// - Parameters:
    ///   - danmakus: 弹幕
    func startPlay(_ danmakus: DanmakuMapResult) {
        self.danmuOnScreenMap.removeAll()
        self.danmakuDic = danmakus
        self.danmakuRender.time = 0
        self.danmakuTime = nil
    }
    
    // MARK: - Private Method
    
    /// 发送弹幕
    private func sendDanmakus(at currentTime: UInt) {
        
        self.danmakuTime = currentTime
        
        if let danmakus = danmakuDic[currentTime] {
            let danmakuDensity = self.danmakuDensity
            for danmakuBlock in danmakus {
                /// 小于弹幕密度才允许发射
                let shouldSendDanmaku = Float.random(in: 0...10) <= danmakuDensity
                if !shouldSendDanmaku {
                    continue
                }
                
                let danmaku = danmakuBlock()
                
                /// 修复因为时间误差的问题，导致少数弹幕突然出现在屏幕上的问题
                if danmaku.appearTime > 0 {
                    danmaku.appearTime = self.danmakuRender.time + (danmaku.appearTime - Double(currentTime))
                }
                
                /// 合并弹幕启用时，查找屏幕上与本弹幕文案相同的弹幕，进行更新
                if self.isMergeSameDanmaku {
                    let danmakuTextKey = danmaku.text
                    
                    /// 文案与当前弹幕相同
                    if let oldDanmaku = self.danmuOnScreenMap[danmakuTextKey] as? DanmakuEntity {
                        oldDanmaku.repeatDanmakuInfo?.repeatCount += 1
                        self.danmakuRender.update(oldDanmaku)
                    } else {
                        danmaku.repeatDanmakuInfo = .init(danmaku: danmaku)
                        
                        self.danmakuRender.send(danmaku)
                        self.danmuOnScreenMap[danmakuTextKey] = danmaku
                    }
                } else {
                    self.danmakuRender.send(danmaku)
                }
            }
        }
    }
    
    /// 遍历当前的弹幕
    /// - Parameter callBack: 回调
    private func forEachDanmakus(_ callBack: (BaseDanmaku) -> Void) {
        for con in danmakuRender.containers {
            if let danmaku = con.danmaku as? BaseDanmaku {
                callBack(danmaku)
            }
        }
    }
    
    private func bindDanmakuContext() {
        
        self.context.danmakuFont.subscribe(onNext: { [weak self] font in
            guard let self = self else { return }
            
            self.forEachDanmakus { danmaku in
                danmaku.font = font
            }
        }).disposed(by: self.disposeBag)
        
        self.context.danmakuOffsetTime.subscribe(onNext: { [weak self] offsetTime in
            guard let self = self else { return }
            
            self.danmakuRender.offsetTime = TimeInterval(offsetTime)
        }).disposed(by: self.disposeBag)
        
        self.context.danmakuSpeed.subscribe(onNext: { [weak self] speed in
            guard let self = self else { return }
            
            self.danmakuRender.speed = speed
            self.forEachDanmakus { danmaku in
                if let scrollDanmaku = danmaku as? ScrollDanmaku {
                    scrollDanmaku.extraSpeed = speed
                }
            }
        }).disposed(by: self.disposeBag)
    }
    
    private func bindMediaContext() {
        self.mediaContext.isPlay.subscribe(onNext: { [weak self] isPlay in
            guard let self = self else { return }
            
            if isPlay {
                self.danmakuRender.start()
            } else {
                self.danmakuRender.pause()
            }
        }).disposed(by: self.disposeBag)
        
        self.mediaContext.time.map({ [weak self] timeInfo in
            return Int(timeInfo.currentTime + (self?.danmakuRender.offsetTime ?? 0))
        }).filter({ [weak self] danmakuRenderTime in
  
            if danmakuRenderTime < 0 {
                return false
            }
            
            let intTime = UInt(danmakuRenderTime)
            /// 一秒只发射一次弹幕
            if intTime == self?.danmakuTime {
                return false
            }
            
            return true
        }).subscribe(onNext: { [weak self] time in
            self?.sendDanmakus(at: UInt(time))
        }).disposed(by: self.disposeBag)
    }
}
