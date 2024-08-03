//
//  PlayerModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/27.
//

import Foundation
import DanmakuRender
import RxSwift


class PlayerModel {

    /// 解析错误
    enum ParseError: Error {
        case notMatched(collection: MatchCollection, media: File)
    }
    
    /// 视频加载状态
    enum MediaLoadState {
        case parse(state: LoadingState, progress: Float)
        case subtitle(subtitle: SubtitleProtocol?)
        case lastWatchProgress(progress: Double)
    }
    
    lazy var parseMediaState = PublishSubject<Event<MediaLoadState>>()
    
    private(set) lazy var mediaModel = PlayerMediaModel()
    
    private(set) lazy var danmakuModel = PlayerDanmakuModel(mediaContext: self.mediaModel.context)
    
    private lazy var disposeBag = DisposeBag()
    
    
    init() {
        bindContext()
    }
    
    // MARK: - 工具方法
    
    /// 调整速度
    /// - Parameter speed: 速度
    func changeSpeed(_ speed: Double) {
        self.mediaModel.onChangePlayerSpeed(speed)
        self.danmakuModel.onChangeDanmakuSpeed(speed)
    }
    
    /// 调整进度
    /// - Parameter position: 播放进度
    func changePosition(_ position: CGFloat) {
        let positionValue = max(min(position, 1), 0)
        
        let mediaTime = self.mediaModel.changePosition(positionValue)
        self.danmakuModel.changeMediaTime(mediaTime)
    }
    
    /// 设置播放器进度
    /// - Parameters:
    ///   - from: 从什么时间开始，传nil时，默认从当前时间开始
    ///   - diffValue: 差值
    func changePosition(from: CGFloat? = nil, diffValue: CGFloat) {
        let length = self.mediaModel.length
        
        let fromValue = from ?? CGFloat(self.mediaModel.currentTime)
        
        if length > 0 {
            let progress = (fromValue + diffValue) / CGFloat(length)
            self.changePosition(progress)
        }
    }
    
    // MARK: Private
    private func bindContext() {
        self.mediaModel.context.playMediaEvent.subscribe(onNext: { [weak self] media in
            guard let self = self else { return }
            
            self.tryParseMedia(media)
        }).disposed(by: self.disposeBag)
    }
}

// MARK: - 加载视频全流程
extension PlayerModel {
    
    /// 解析视频，状态会传递给parseMediaState
    /// - Parameter media: 视频
    func tryParseMedia(_ media: File) {
        _ = self.tryParseMediaOneTime(media).subscribe { [weak self] event in
            guard let self = self else { return }
            
            self.parseMediaState.on(.next(event))
        }
    }
    
    
    /// 单次解析视频
    /// - Parameter media: 视频
    /// - Returns: 状态
    private func tryParseMediaOneTime(_ media: File) -> Observable<MediaLoadState> {
        
        return Observable<MediaLoadState>.create { [weak self] sub in
            
            self?.mediaModel.tryParseMediaOneTime(media)
            
            DanmakuManager.shared.loadDanmaku(media) { state in
                DispatchQueue.main.async {
                    
                    switch state {
                    case .parseMedia:
                        sub.onNext(.parse(state: state, progress: 0))
                    case .downloadLocalDanmaku:
                        sub.onNext(.parse(state: state, progress: 0.2))
                    case .matchMedia(progress: let progress):
                        sub.onNext(.parse(state: state, progress: Float(0.2 + 0.6 * progress)))
                    case .downloadDanmaku:
                        sub.onNext(.parse(state: state, progress: 0.9))
                    }
                }
            } matchCompletion: { (collection, error) in
                DispatchQueue.main.async {
                    
                    if let error = error {
                        sub.onError(error)
                    } else if let collection = collection {
                        sub.onError(ParseError.notMatched(collection: collection, media: media))
                    }
                    
                    sub.onCompleted()
                }
            } danmakuCompletion: { [weak self] result, episodeId, error in

                DispatchQueue.main.async {
                    
                    if let error = error {
                        sub.onError(error)
                    } else {
                        _ = self?.startPlay(media, episodeId: episodeId, danmakus: result ?? [:]).subscribe(onNext: { state in
                            sub.onNext(state)
                        }, onCompleted: {
                            sub.onCompleted()
                        })
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    
    /// 匹配后的流程，比如加载弹幕
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 节目id
    /// - Returns: 加载状态
    func didMatchMedia(_ media: File, episodeId: Int) -> Observable<MediaLoadState>  {
        return Observable<MediaLoadState>.create { sub in
            CommentNetworkHandle.getDanmaku(with: episodeId) { [weak self] (collection, error) in
                
                if let error = error {
                    DispatchQueue.main.async {
                        sub.onError(error)
                    }
                } else {
                    let danmakus = collection?.collection ?? []
                    DispatchQueue.main.async {
                        _ = self?.startPlay(media, episodeId: episodeId, danmakus: DanmakuManager.shared.conver(danmakus)).subscribe { event in
                            sub.on(event)
                        }
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    /// 开始播放
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 弹幕分级id
    ///   - danmakus: 弹幕
    func startPlay(_ media: File, episodeId: Int, danmakus: DanmakuMapResult) -> Observable<MediaLoadState> {
        self.danmakuModel.startPlay(danmakus)
        return self.mediaModel.startPlay(media, episodeId: episodeId)
    }
}
