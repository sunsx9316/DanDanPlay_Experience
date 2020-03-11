//
//  PlayerViewController.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/3.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import UIKit
import SnapKit
import JHDanmakuRender

protocol MediaItemProtocol {
    var collectionModel: DanmakuCollectionModel? { get set }
    var media: DDPMediaItemProtocol? { get }
}

class PlayerViewController: UIViewController, DDPMediaPlayerDelegate, JHDanmakuEngineDelegate {
    
    private lazy var interfaceView: UIView = {
        var interfaceView = UIView()
        return interfaceView
    }()
    
    private lazy var danmakuRender: JHDanmakuEngine = {
        let danmakuRender = JHDanmakuEngine()
        danmakuRender.delegate = self
        danmakuRender.setUserInfoWithKey(JHScrollDanmakuExtraSpeedKey, value: 1)
        return danmakuRender
    }()
    
    private lazy var player: DDPMediaPlayer = {
        let player = DDPMediaPlayer()
        player.delegate = self
        return player
    }()
    
    private var collectionModel: DanmakuCollectionModel? {
        didSet {
            self.danmakuDic.removeAll()
            self.danmakuDic = DanmakuManager.shared.conver(self.collectionModel?.collection ?? [])
        }
    }
    
    private var meida: DDPMediaItemProtocol?
    
    private var danmakuDic = [UInt : [JHDanmakuProtocol]]()
    
    private var containerView: UIView = {
        return UIView()
    }()
    
    
    init(mediaItem: MediaItemProtocol) {
        super.init(nibName: nil, bundle: nil)
        update(mediaItem)
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuRender.canvas)
//        self.view.addSubview(self.interfaceView)
        
        self.containerView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.view)
        }
        
        self.player.mediaView.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
        self.danmakuRender.canvas.snp.makeConstraints { (make) in
            make.edges.equalTo(self.containerView)
        }
        
//        self.interfaceView.snp.makeConstraints { (make) in
//            make.edges.equalTo(self.view)
//        }
        
        self.player.media = self.meida
        self.player.play()
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        navigationController?.setNavigationBarHidden(true, animated: animated)
    }
    
    override var prefersStatusBarHidden: Bool {
        return true
    }
    
    override var prefersHomeIndicatorAutoHidden: Bool {
        return true
    }
    
    //MARK: Private
    private func update(_ mediaItem: MediaItemProtocol) {
        self.meida = mediaItem.media
        self.collectionModel = mediaItem.collectionModel
    }
    
    //MARK: DDPMediaPlayerDelegate
    func mediaPlayer(_ player: DDPMediaPlayer, statusChange status: DDPMediaPlayerStatus) {
        switch status {
        case .playing:
            danmakuRender.start()
        case .nextEpisode:
            break
        case .pause, .stop:
            danmakuRender.pause()
        @unknown default:
            break
        }
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, rateChange rate: Float) {
        danmakuRender.systemSpeed = CGFloat(rate)
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, userJumpWithTime time: TimeInterval) {
        danmakuRender.currentTime = time
        if !player.isPlaying {
            danmakuRender.pause()
        }
    }
    
    func mediaPlayer(_ player: DDPMediaPlayer, progress: Float) {
        
    }
    
    //MARK: JHDanmakuEngineDelegate
    func danmakuEngine(_ danmakuEngine: JHDanmakuEngine, didSendDanmakuAtTime time: UInt) -> [JHDanmakuProtocol] {
     return danmakuDic[time] ?? []
    }

}
