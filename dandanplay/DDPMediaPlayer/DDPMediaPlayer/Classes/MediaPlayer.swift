//
//  MediaPlayer.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/1/14.
//

import Foundation
import GCDWebServer

#if os(iOS)
import UIKit
import MobileVLCKit
import AVFoundation
public typealias MediaView = UIView
#else
import AppKit
public typealias MediaView = NSView
#endif

public protocol MediaPlayerDelegate: class {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval)
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State)
    func player(_ player: MediaPlayer, mediaDidChange media: MediaItem?)
}

public extension MediaPlayerDelegate {
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {}
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {}
    func player(_ player: MediaPlayer, mediaDidChange media: MediaItem?) {}
}

public let MediaItemWebDavNameKey = "name"
public let MediaItemWebDavPasswordKey = "password"
public let MediaItemWebDavURLKey = "url"
public let MediaItemIsWebDavURLKey = "is_web_dav"

public protocol MediaItem {
    var url: URL { get }
    var option: [AnyHashable : Any]? { get }
}

extension MediaPlayer: URLSessionTaskDelegate {
    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {

        if challenge.previousFailureCount > 0 {
            completionHandler(.cancelAuthenticationChallenge, nil)
        } else {
            let option = self.currentPlayItem?.option
            let name = option?[MediaItemWebDavNameKey] as? String
            let password = option?[MediaItemWebDavPasswordKey] as? String
            if let name = name, let password = password {
                let credential = URLCredential(user: name, password: password, persistence: .forSession)
                completionHandler(.useCredential, credential)
            } else {
                completionHandler(.performDefaultHandling, nil)
            }
        }
    }
}

extension MediaPlayer: GCDWebServerDelegate {
    public func webServerDidDisconnect(_ server: GCDWebServer) {
//        try? server.start(options: [GCDWebServerOption_AutomaticallySuspendInBackground : false])
    }
    
    public func webServerDidStop(_ server: GCDWebServer) {
        
    }
}

open class MediaPlayer: NSObject {
    
    public enum PlayMode {
        case playOnce
        case autoPlayNext
        case repeatCurrentItem
        case repeatList
    }
    
    public enum State {
        case playing
        case pause
        case stop
    }
    
    public struct Subtitle {
        let index: Int
        let name: String
    }
    
    public struct AudioChannel {
        let index: Int
        let name: String
    }
    
    open private(set) lazy var mediaView = MediaView()
    
    open private(set) lazy var playList = [MediaItem]()
    
    class TestItem: MediaItem {
        
        var url: URL {
                return URL(string: "http://jimhuangdemacbook-pro.local:8080/%5BHYSUB%5DKaifuku%20Jutsushi%20no%20Yarinaoshi%5B01%5D%5BGB_MP4%5D%5B1280X720%5D.mp4")!
        }
        
        var option: [AnyHashable : Any]? {
            return ["is_web_dav" : true, "name" : "jimhuang", "password" : "123"]
        }
    }
    
    open private(set) var currentPlayItem: MediaItem? {
        didSet {
            if let item = self.currentPlayItem {
                if let isWebDavURL = item.option?[MediaItemIsWebDavURLKey] as? Bool, isWebDavURL {
                    //                if !self.webServer.isRunning {
                    //                    try? self.webServer.start(options:
                    //                                                [GCDWebServerOption_AutomaticallySuspendInBackground : NSNumber(value: false),
                    //                                                 GCDWebServerOption_ConnectedStateCoalescingInterval : NSNumber(value: true)])
                    //                }
                    if let url = self.createWebDavURL(with: item) {
                        self.player.media = VLCMedia(url: url)
                    } else {
                        self.player.media = nil
                    }
                } else {
                    self.player.media = VLCMedia(url: item.url)
                }
            } else {
                self.player.media = nil
            }
            
            self.delegate?.player(self, mediaDidChange: self.currentPlayItem)
        }
    }
    
    private func createWebDavURL(with medieItem: MediaItem) -> URL? {
        
        if let serverURLString = self.webServer.serverURL?.absoluteString {
            var components = URLComponents(string: serverURLString)
            
            var queryItems = [URLQueryItem]()
            
            if let userName = medieItem.option?[MediaItemWebDavNameKey] as? String {
                queryItems.append(URLQueryItem(name: MediaItemWebDavNameKey, value: userName))
            }
            
            if let password = medieItem.option?[MediaItemWebDavPasswordKey] as? String {
                queryItems.append(URLQueryItem(name: MediaItemWebDavPasswordKey, value: password))
            }
            
            if let urlEnbodeString = medieItem.url.absoluteString.data(using: .utf8)?.base64EncodedString() {
                queryItems.append(URLQueryItem(name: MediaItemWebDavURLKey, value: urlEnbodeString))
            }
            
            components?.queryItems = queryItems
            return components?.url
        }
        
        return nil
    }
    
    private lazy var session: URLSession = {
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
        return session
    }()
    
    private lazy var webServer: GCDWebServer = {
        let svr = GCDWebServer()
        svr.delegate = self
        svr.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { (request, completion) in
            if let encodeStr = request.query?[MediaItemWebDavURLKey], let data = Data(base64Encoded: encodeStr) {
                let urlString = String(data: data, encoding: .utf8)
                
                if let urlString = urlString, let url = URL(string: urlString) {
                    var req = URLRequest(url: url)
                    req.httpMethod = request.method
                    for (key, value) in request.headers {
                        req.addValue(value, forHTTPHeaderField: key)
                    }
                    /*
                    self.session.downloadTask(with: req) { (url, res, err) in
                        if let url = url, let res = res as? HTTPURLResponse {
                            if let range = res.allHeaderFields["Content-Range"] as? String,
                               let value = range.components(separatedBy: " ").last?.components(separatedBy: "/").first {
                                let result = value.components(separatedBy: "-")
                                if result.count == 2 {
                                    let f = Int(result[0]) ?? 0
                                    let e = Int(result[1]) ?? 0
                                    let r = NSRange(location: f, length: e - f)
                                    let response = GCDWebServerFileResponse(file: url.path, byteRange: r)
        //                            let response = GCDWebServerDataResponse(data: data, contentType: res.mimeType ?? "")
                                    completion(response)
                                } else {
                                    let response = GCDWebServerDataResponse(statusCode: -999)
                                    completion(response)
                                }
                            } else {
                                let response = GCDWebServerDataResponse(statusCode: -999)
                                completion(response)
                            }
                            
//                            let response = GCDWebServerFileResponse(file: url.path, byteRange: request.byteRange)
//                            let response = GCDWebServerDataResponse(data: data, contentType: res.mimeType ?? "")
//                            completion(response)
                        } else if let err = err as NSError? {
                            let response = GCDWebServerDataResponse(statusCode: err.code)
                            completion(response)
                        } else {
                            let response = GCDWebServerDataResponse(statusCode: -999)
                            completion(response)
                        }
                    }.resume()
                    */
                    self.session.dataTask(with: req) { (data, res, err) in
                        if let data = data, let res = res as? HTTPURLResponse {
                            let response = GCDWebServerDataResponse(data: data, contentType: res.mimeType ?? "")
                            completion(response)
                        } else if let err = err as NSError? {
                            let response = GCDWebServerDataResponse(statusCode: err.code)
                            completion(response)
                        } else {
                            let response = GCDWebServerDataResponse(statusCode: -999)
                            completion(response)
                        }
                    }.resume()
                }
            }
        }
        return svr
    }()
    
    open var subtitleList: [Subtitle] {
        return self.player.videoSubTitlesIndexes.indices.compactMap({ subtitleWithIndexInPlayer($0) })
    }
    
    open var currentSubtitle: Subtitle? {
        let currentVideoSubTitleIndex = self.player.currentVideoSubTitleIndex
        if let fristIndex = self.player.videoSubTitlesIndexes.firstIndex(where: { (value) -> Bool in
            if let value = value as? Int, value == currentVideoSubTitleIndex {
                return true
            }
            return false
        }) {
            return subtitleWithIndexInPlayer(fristIndex)
        }
        return nil
    }
    
    open var audioChannelList: [AudioChannel] {
        return self.player.audioTrackIndexes.indices.compactMap({ audioChannelWithIndexInPlayer($0) })
    }
    
    open var currentAudioChannel: AudioChannel?  {
        let currentAudioTrackIndex = self.player.currentAudioTrackIndex
        if let fristIndex = self.player.audioTrackIndexes.firstIndex(where: { (value) -> Bool in
            if let value = value as? Int, value == currentAudioTrackIndex {
                return true
            }
            return false
        }) {
            return audioChannelWithIndexInPlayer(fristIndex)
        }
        return nil
    }
    
    private lazy var player: VLCMediaPlayer = {
        var player = VLCMediaPlayer()
        player.drawable = self.mediaView
        player.delegate = self
        return player
    }()
    
    open var playMode = PlayMode.autoPlayNext
    open var volume: Int {
        get {
            return Int(self.player.audio.volume)
        }
        
        set {
            self.player.audio.volume = Int32(newValue)
        }
    }
    
    open var subtitleDelay: CGFloat {
        get {
            return CGFloat(self.player.currentVideoSubTitleDelay) / 1000000.0
        }
        
        set {
            self.player.currentVideoSubTitleDelay = Int(newValue * 1000000.0)
        }
    }
    
    open var speed: CGFloat {
        get {
            return CGFloat(self.player.rate)
        }
        
        set {
            self.player.rate = Float(newValue)
        }
    }
    
    open var videoAspectRatio: CGSize {
        get {
            let str = String(cString: self.player.videoAspectRatio)
            let arr = str.components(separatedBy: ":")
            if arr.count < 2 {
                return .zero
            }
            return .init(width: CGFloat(Double(arr[0]) ?? 0),
                         height: CGFloat(Double(arr[1]) ?? 0))
        }
        
        set {
            let str = "\(newValue.width):\(newValue.height)"
            self.player.videoAspectRatio = UnsafeMutablePointer(mutating: (str as NSString).utf8String)
        }
    }
    
    open var position: CGFloat {
        return CGFloat(self.player.position)
    }
    
    open var length: TimeInterval {
        return self.player.media.length.value.doubleValue / 1000
    }
    
    open var currentTime: TimeInterval {
        return self.player.time.value.doubleValue / 1000
    }
    
    open var state: State {
        switch self.player.state {
        case .stopped:
            return .stop
        case .paused:
            return .pause
        case .playing:
            return .playing
        case .buffering:
            if self.timeIsUpdate {
                return .playing
            } else {
                return .pause
            }
        default:
            return .pause
        }
    }
    
    open var isPlaying: Bool {
        return self.player.isPlaying
    }
    
    open weak var delegate: MediaPlayerDelegate?
    
    private var playerTimer: Timer?
    private var timeIsUpdate = false

    
    public override init() {
        super.init()
        NotificationCenter.default.addObserver(self, selector: #selector(handleInterreption(_:)), name: AVAudioSession.interruptionNotification, object: nil)
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
        self.playerTimer?.invalidate()
    }
    
    open func setPosition(_ position: CGFloat) -> TimeInterval {
        let p = max(min(position, 1), 0)
        
        self.player.position = Float(p)
        return self.length * TimeInterval(position)
    }
    
    open func play(_ media: MediaItem) {
        
        if !self.playList.contains(where: { $0.url == media.url }) {
            self.playList.append(media)
        }
        
        if self.currentPlayItem?.url != media.url {
            self.currentPlayItem = media
        }
        
        self.player.play()
    }
    
    open func play() {
        self.player.play()
    }
    
    open func pause() {
        self.player.pause()
    }
    
    open func stop() {
        self.currentPlayItem = nil
        self.player.stop()
    }
    
    open func openVideoSubTitle(with url: URL) {
        self.player.addPlaybackSlave(url, type: .subtitle, enforce: true)
    }
    
    open func addMediaToPlayList(_ media: MediaItem) {
        self.playList.append(media)
    }
    
    open func removeMediaFromPlayList(_ media: MediaItem) {
        self.playList.removeAll(where: { $0.url == media.url })
    }
    
    //MARK: Private Method
    private func subtitleWithIndexInPlayer(_ index: Int) -> Subtitle? {
        if index < self.player.videoSubTitlesIndexes.count,
           let indexNumber = self.player.videoSubTitlesIndexes[index] as? Int {
            
            let name: String
            if index < self.player.videoSubTitlesNames.count {
                name = self.player.videoSubTitlesNames[index] as? String ?? "未知名称"
            } else {
                name = "未知名称"
            }
            
            return Subtitle(index: indexNumber, name: name)
        } else {
            return nil
        }
    }
    
    private func audioChannelWithIndexInPlayer(_ index: Int) -> AudioChannel? {
        if index < self.player.audioTrackIndexes.count,
           let indexNumber = self.player.audioTrackIndexes[index] as? Int {
            
            let name: String
            if index < self.player.audioTrackNames.count {
                name = self.player.audioTrackNames[index] as? String ?? "未知名称"
            } else {
                name = "未知名称"
            }
            
            return AudioChannel(index: indexNumber, name: name)
        } else {
            return nil
        }
    }
    
    @objc private func handleInterreption(_ notice: Notification) {
        guard let interruptionType = notice.userInfo?[AVAudioSessionInterruptionTypeKey] as? AVAudioSession.InterruptionType else { return }
        
        switch interruptionType {
        case .began:
            if self.isPlaying {
                self.pause()
            }
        default:
            break
        }
    }
}

extension MediaPlayer: VLCMediaPlayerDelegate {
    public func mediaPlayerTimeChanged(_ aNotification: Notification!) {
        let nowTime = self.currentTime
        let length = self.length
        
        self.delegate?.player(self, currentTime: nowTime, totalTime: length)
        self.playerTimer?.invalidate()
        self.playerTimer = Timer.scheduledTimer(timeInterval: 1, target: self, selector: #selector(playerTimerStart), userInfo: nil, repeats: false)
        
        if self.timeIsUpdate == false {
            self.timeIsUpdate = true
            self.stateChanged()
        }
    }
    
    public func mediaPlayerStateChanged(_ aNotification: Notification!) {
        stateChanged()
    }
    
    private func stateChanged() {
        self.delegate?.player(self, stateDidChange: self.state)
        if self.isPlayAtEnd() {
            self.tryPlayNextItem()
        }
    }
    
    @objc private func playerTimerStart() {
        self.timeIsUpdate = false
        self.stateChanged()
    }
    
    private func isPlayAtEnd() -> Bool {
        return self.position >= 0.999
    }
    
    private func tryPlayNextItem() {
        
        func nextItemWithCycle(_ cycle: Bool) -> MediaItem? {
            if let index = self.playList.firstIndex(where: { $0.url == self.currentPlayItem?.url }) {
                if index == self.playList.count - 1 {
                    return cycle ? self.playList.first : nil
                }
                return self.playList[index + 1]
            }
            return nil
        }
        
        switch self.playMode {
        case .playOnce:
            break
        case .autoPlayNext:
            if isPlayAtEnd() {
                self.stop()
                if let nextItem = nextItemWithCycle(false) {
                    self.play(nextItem)
                }
            }
        case .repeatCurrentItem:
            if isPlayAtEnd() {
                self.stop()
                if let currentPlayItem = self.currentPlayItem {
                    self.play(currentPlayItem)                    
                }
            }
        case .repeatList:
            if isPlayAtEnd() {
                self.stop()
                if let nextItem = nextItemWithCycle(true) {
                    self.play(nextItem)
                }
            }
        }
    }
}
