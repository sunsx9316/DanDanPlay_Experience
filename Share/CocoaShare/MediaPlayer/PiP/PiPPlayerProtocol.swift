//
//  PiPPlayerProtocol.swift
//  CocoaShare
//
//  画中画播放器通用协议，任何播放器后端实现此协议即可支持 PiP
//

import AVFoundation

// MARK: - Delegate

protocol PiPPlayerDelegate: AnyObject {
    func pipPlayer(_ player: any PiPPlayerProtocol, didOutputFrame sampleBuffer: CMSampleBuffer)
    func pipPlayer(_ player: any PiPPlayerProtocol, didChangeVideoSize size: CGSize)
    func pipPlayer(_ player: any PiPPlayerProtocol, didChangePosition position: Double)
    func pipPlayer(_ player: any PiPPlayerProtocol, didChangePlayPause isPlaying: Bool)
    func pipPlayerDidEndFile(_ player: any PiPPlayerProtocol)
}

// MARK: - Protocol

protocol PiPPlayerProtocol: AnyObject {
    var delegate: PiPPlayerDelegate? { get set }

    var currentPosition: Double { get }
    var duration: Double { get }
    var isPlaying: Bool { get }
    var config: PiPPlayerConfig { get set }

    /// 加载并播放，startPosition / startPaused 从 config 读取
    func loadAndPlay(urlString: String)
    func play()
    func pause()
    func seek(to position: Double)
    func terminate()
    func applyConfig(_ config: PiPPlayerConfig)
}
