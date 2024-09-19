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
    
    var danmakuFont: ANXFont? {
        return (try? self.context.danmakuFont.value())
    }
    
    var danmakuArea: DanmakuAreaType {
        return (try? self.context.danmakuArea.value()) ?? .area_1_1
    }
    
    var danmakuEffectStyle: DanmakuEffectStyle {
        return (try? self.context.danmakuEffectStyle.value()) ?? .stroke
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
    
    var danmakuSetting: [DanmakuSettingType] {
        return DanmakuSettingType.allCases
    }
    
    var filterDanmakus: [FilterDanmaku]? {
        return (try? self.context.filterDanmakus.value())
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
        danmakuRender.delegate = self
        return danmakuRender
    }()
    
    //当前弹幕时间/弹幕数组映射
    private lazy var danmakuProducer = PlayerDanmakuProducer(danmakuContext: self.context)
    
    
    /// 记录当前屏幕展示的弹幕
    private lazy var danmuOnScreenMap: NSMapTable<NSString, BaseDanmaku> = NSMapTable.strongToWeakObjects()
    
    private lazy var disposeBag = DisposeBag()
    
    private var mediaContext: PlayerMediaContext!
    
    /// 当前选中的弹幕
    private weak var selectedDanmakuContainer: DanmakuContainerProtocol?
    
    
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
    
    func onChangeDanmakuArea(_ danmakuArea: DanmakuAreaType) {
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
        _ = self.danmakuProducer.startFilter(from: UInt(mediaTime), forceParse: false).subscribe(onNext: nil)
    }
    
    func onChangeDanmaEffectStyle(_ danmakuEffectStyle: DanmakuEffectStyle) {
        Preferences.shared.danmakuEffectStyle = danmakuEffectStyle
        self.context.danmakuEffectStyle.onNext(danmakuEffectStyle)
    }
    
    func selectedDanmaku(at point: CGPoint) -> DanmakuContainerProtocol? {
#if os(macOS)
        let container = self.danmakuRender.canvas.hitTest(point)
#else
        let container = self.danmakuRender.canvas.hitTest(point, with: nil)
#endif
        
        if let container = container as? DanmakuContainerProtocol {
            if container !== self.selectedDanmakuContainer {
                self.deselectDanmaku()
                self.selectedDanmakuContainer = container
                container.danmaku.isPause = true
                return container
            }
        } else {
            self.deselectDanmaku()
        }
        
        return nil
    }
    
    func deselectDanmaku() {
        self.selectedDanmakuContainer?.danmaku.isPause = false
        self.selectedDanmakuContainer = nil
    }
    
    /// 将弹幕文案粘贴到剪贴板
    /// - Parameter container: 弹幕容器
    func copyDanmkuText(_ container: DanmakuContainerProtocol) {
#if os(macOS)
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(container.danmaku.text, forType: .string)
#else
        UIPasteboard.general.string = container.danmaku.text
#endif
        
    }
    
    /// 添加屏蔽弹幕
    /// - Parameter container: 弹幕文案
    func onAddFilterDanmku(_ container: DanmakuContainerProtocol) {
        onAddFilterDanmku(container.danmaku.text)
    }
    
    /// 添加屏蔽弹幕
    /// - Parameter container: 弹幕文案
    func onAddFilterDanmku(_ text: String) {
        let newFilterDanmaku = FilterDanmaku(isRegularExp: false, text: text, isEnable: true)
        var filterDanmakus = self.filterDanmakus ?? []
        if !filterDanmakus.contains(where: { $0 == newFilterDanmaku }) {
            filterDanmakus.insert(newFilterDanmaku, at: 0)
            self.context.filterDanmakus.onNext(filterDanmakus)
            Preferences.shared.filterDanmakus = filterDanmakus
        }
    }
    
    /// 移除屏蔽弹幕
    /// - Parameter container: 弹幕
    func onRemoveFilterDanmkus(_ filterDanmaku: FilterDanmaku) {
        var filterDanmakus = self.filterDanmakus ?? []
        if filterDanmakus.contains(where: { $0 == filterDanmaku }) {
            filterDanmakus.removeAll(where: { $0 == filterDanmaku })
            self.context.filterDanmakus.onNext(filterDanmakus)
            Preferences.shared.filterDanmakus = filterDanmakus
        }
    }
    
    /// 修改过滤弹幕列表
    /// - Parameter filterDanmakus: 过滤弹幕列表
    func onChangeFilterDanmkus(_ filterDanmakus: [FilterDanmaku]?) {
        self.context.filterDanmakus.onNext(filterDanmakus)
        Preferences.shared.filterDanmakus = filterDanmakus
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
    func loadDanmakuByUser(_ file: File) -> Observable<LoadingState> {
        return Observable<LoadingState>.create { [weak self] (sub) in
            
            DanmakuManager.shared.downCustomDanmaku(file) { [weak self] result1 in
                
                switch result1 {
                case .success(let url):
                    do {
                        let converResult = try DanmakuManager.shared.conver(url)
                        DispatchQueue.main.async {
                            _ = self?.danmakuProducer.setupDanmaku(converResult).subscribe(onNext: nil)
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
    
    /// 设置弹幕
    /// - Parameters:
    ///   - danmakus: 弹幕
    func setupDanmaku(_ danmakus: DanmakuMapResult) -> Observable<DanmakuFilterProgress> {
        return Observable<DanmakuFilterProgress>.create { sub in
            self.danmakuRender.time = 0
            self.danmakuTime = nil
            _ = self.danmakuProducer.setupDanmaku(danmakus).subscribe(onNext: { progress in
                sub.onNext(progress)
            }, onCompleted: {
                sub.onCompleted()
            })
            
            return Disposables.create()
        }
    }
    
    // MARK: - Private Method
    
    /// 发送弹幕
    private func sendDanmakus(at currentTime: UInt) {
        
        self.danmakuTime = currentTime
        
        if let danmakus = self.danmakuProducer.danmaku(at: currentTime) {
            
            let danmakuDensity = self.danmakuDensity
            for danmaku in danmakus {
                
                /// 弹幕被过滤 不发送
                if danmaku.isFilter {
                    continue
                }
                
                /// 小于弹幕密度才允许发射
                let shouldSendDanmaku = Float.random(in: 0...10) <= danmakuDensity
                if !shouldSendDanmaku {
                    continue
                }
                
                /// 重设弹幕字体
                if let danmakuFont = self.danmakuFont, danmaku.font != danmakuFont {
                    danmaku.font = danmakuFont
                }
                
                /// 重设弹幕边缘
                if danmaku.effectStyle != self.danmakuEffectStyle {
                    danmaku.effectStyle = self.danmakuEffectStyle
                }
                
                
                /// 修复因为时间误差的问题，导致少数弹幕突然出现在屏幕上的问题
                if danmaku.appearTime > 0 {
                    if danmaku.originAppearTime == nil {
                        danmaku.originAppearTime = danmaku.appearTime
                    }
                    
                    let originAppearTime = danmaku.originAppearTime ?? 0
                    let timeOffset = originAppearTime - Double(currentTime)
                    danmaku.appearTime = self.danmakuRender.time + timeOffset
                }
                
                /// 合并弹幕启用时，查找屏幕上与本弹幕文案相同的弹幕，进行更新
                if self.isMergeSameDanmaku {
                    let danmakuTextKey = danmaku.text as NSString
                    
                    /// 文案与当前弹幕相同
                    if let oldDanmaku = self.danmuOnScreenMap.object(forKey: danmakuTextKey) as? DanmakuEntity {
                        oldDanmaku.repeatDanmakuInfo?.repeatCount += 1
                    } else {
                        danmaku.repeatDanmakuInfo = .init(danmaku: danmaku)
                        self.danmakuRender.send(danmaku)
                        self.danmuOnScreenMap.setObject(danmaku, forKey: danmakuTextKey)
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
            callBack(con.danmaku)
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
            
            self.setupDanmakuRenderSpeed()
        }).disposed(by: self.disposeBag)
        
        self.context.filterDanmakus.subscribe(onNext: { [weak self] filterDanmakus in
            guard let self = self else { return }
            
            let time = (try? self.mediaContext.time.value().currentTime) ?? 0
            _ = self.danmakuProducer.startFilter(from: UInt(time), forceParse: true).subscribe(onNext: nil)
        }).disposed(by: self.disposeBag)
        
        self.context.danmakuEffectStyle.subscribe(onNext: { [weak self] danmakuEffectStyle in
            guard let self = self else { return }
            
            self.forEachDanmakus { danmaku in
                danmaku.effectStyle = danmakuEffectStyle
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
        
        self.mediaContext.playerSpeed.subscribe(onNext: { [weak self] _ in
            self?.setupDanmakuRenderSpeed()
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
    
    
    /// 设置弹幕速度
    private func setupDanmakuRenderSpeed() {
        let playerSpeed = (try? self.mediaContext.playerSpeed.value()) ?? 1
        let danmakuSpeed = self.danmakuSpeed
        self.danmakuRender.speed = danmakuSpeed * playerSpeed
    }
}


extension PlayerDanmakuModel: DanmakuEngineDelegate {
    func willMoveOutCanvas(danmaku: BaseDanmaku, engine: DanmakuEngine) {
        self.danmuOnScreenMap.removeObject(forKey: danmaku.text as NSString)
    }
}
