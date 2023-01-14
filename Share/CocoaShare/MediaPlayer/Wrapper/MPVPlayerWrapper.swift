//
//  MPVPlayerWrapper.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/10/22.
//

import Cocoa
import MPVPlayer

class MPVPlayerWrapper: NSObject, MediaPlayerProtocol {
    
    private let endFlagProgress = 0.99
    
    var mediaView: ANXView {
        return self.player.videoView
    }
    
    var currentPlayItem: File? {
        didSet {
            if let item = self.currentPlayItem {
                self.player.media = .init(url: item.url)
            } else {
                self.player.media = nil
            }
        }
    }
    
    var subtitleList = [SubtitleProtocol]()
    
    var currentSubtitle: SubtitleProtocol? {
        get {
            return nil
        }
        
        set {
            
        }
    }
    
    var audioChannelList = [AudioChannel]()
    
    var currentAudioChannel: AudioChannel? {
        get {
            return nil
        }
        
        set {}
    }
    
    var timeChangedCallBack: ((MediaPlayerProtocol, Double) -> Void)?
    
    var stateChangedCallBack: ((MediaPlayerProtocol, PlayerState) -> Void)?
    
    var bufferInfoDidChangeCallBack: ((MediaPlayerProtocol, File, MediaBufferInfo) -> Void)?
    
    var volume: Int {
        get {
            return Int(self.player.audio.volume)
        }
        
        set {
            self.player.audio.volume = Double(newValue)
        }
    }
    
    var subtitleDelay: Double = 0
    
    var speed: Double {
        get {
            return self.player.speed
        }
        
        set {
            self.player.speed = newValue
        }
    }
    
    var aspectRatio: PlayerAspectRatio = .default
    
    var position: Double {
        return self.player.duration > 0 ? self.player.currentTime / self.player.duration : 0
    }
    
    var length: TimeInterval {
        return self.player.duration
    }
    
    var currentTime: TimeInterval {
        return self.player.currentTime
    }
    
    var state: PlayerState {
        if self.player.isPlaying {
            return .playing
        }
        return .pause
    }
    
    var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    var fontSize: Int?
    
    var fontName: String?
    
    var fontColor: ANXColor?
    
    private lazy var player: MPVPlayer = {
        let player = MPVPlayer()
        return player
    }()
    
    func setPosition(_ position: Double) -> TimeInterval {
        let position = max(min(position, 1), 0)
        self.player.seek(percent: position)
        return self.length * position
    }
    
    func play(_ media: File) {
        self.currentPlayItem = media
        self.player.play()
    }
    
    func play() {
        self.player.play()
    }
    
    func pause() {
        self.player.pause()
    }
    
    func stop() {
        self.player.stop()
    }
    
    func isPlayAtEnd() -> Bool {
        return self.position >= self.endFlagProgress
    }
    

}
