//
//  PiPManager.swift
//  CocoaShare
//
//  跨平台 PiP 核心管理器：持有 PiP 播放器，管理 AVSampleBufferDisplayLayer 管线，
//  通过 handleXxx() 钩子供平台层对接系统 PiP API
//

import AVFoundation
import ANXLog

let pipTimescale: CMTimeScale = 600
let pipFallbackDuration: Double = 3600
let pipCaptureInterval: TimeInterval = 1.0 / 30.0
let pipFallbackWidth = 480
let pipFallbackHeight = 270
let pipBufferAlignment = 64

// MARK: - PiP 状态

enum PiPState {
    case inactive
    case starting
    case active
    case stopping
}

// MARK: - PiPManager

class PiPManager: NSObject {

    // MARK: 公开属性

    private(set) var state: PiPState = .inactive

    var isPlaying: Bool { pipPlayer?.isPlaying ?? _wasPlayingAtStop }

    var duration: Double { pipPlayer?.duration ?? 0 }

    var currentPosition: Double {
        pipPlayer?.currentPosition ?? _latestPosition
    }
    
    var displayLayer: AVSampleBufferDisplayLayer {
        sampleBufferView.displayLayer
    }

    /// 给平台层创建 PiP ContentSource 用的 view（内部管理 AVSampleBufferDisplayLayer）
    let sampleBufferView = PiPSampleBufferView()

    // MARK: 回调（给 VC 用）

    var onStateChanged: ((PiPState) -> Void)?
    var onRestoreUI: (() -> Void)?
    /// 首帧已入队，平台层可以调用系统 PiP start
    var onReadyForPiPStart: (() -> Void)?
    /// 播放位置更新
    var onPositionUpdate: ((Double) -> Void)?

    // MARK: 私有

    private var pipPlayer: (any PiPPlayerProtocol)?
    private var pipTimebase: CMTimebase?
    private var _latestPosition: Double = 0
    private var _wasPlayingAtStop = false
    private var didStartPiPController = false
    private var frameCount = 0
    private var dropCount = 0

    // MARK: 初始化

    override init() {
        super.init()
    }

    // MARK: 启动 / 停止

    func start(with player: any PiPPlayerProtocol,
               filePath: String,
               startPosition: Double) {
        guard state == .inactive else {
            ANX.logError(.player, "[PiPManager] start 跳过，当前 state=\(state)")
            return
        }

        _latestPosition = startPosition
        self.pipPlayer = player
        player.delegate = self

        // CMTimebase
        let startCMTime = CMTime(seconds: startPosition, preferredTimescale: pipTimescale)
        var timebase: CMTimebase?
        CMTimebaseCreateWithSourceClock(allocator: nil, sourceClock: CMClockGetHostTimeClock(), timebaseOut: &timebase)
        if let tb = timebase {
            CMTimebaseSetTime(tb, time: startCMTime)
            CMTimebaseSetRate(tb, rate: 0.0)
            displayLayer.controlTimebase = tb
            self.pipTimebase = tb
        }

        state = .starting
        onStateChanged?(.starting)

        displayLayer.flush()
        didStartPiPController = false
        frameCount = 0
        dropCount = 0

        player.loadAndPlay(urlString: filePath, startPosition: startPosition)
    }

    func stop() {
        guard state != .inactive else { return }
        cleanup()
    }

    private func cleanup() {
        _latestPosition = pipPlayer?.currentPosition ?? _latestPosition

        if let tb = pipTimebase {
            CMTimebaseSetRate(tb, rate: 0.0)
            displayLayer.controlTimebase = nil
            pipTimebase = nil
        }

        pipPlayer?.terminate()
        pipPlayer = nil

        if state != .inactive {
            state = .inactive
            onStateChanged?(.inactive)
        }
    }

    // MARK: 平台层钩子

    func handlePiPStarted() {
        state = .active
        onStateChanged?(.active)
        if let tb = pipTimebase {
            CMTimebaseSetTime(tb, time: CMTime(seconds: currentPosition, preferredTimescale: pipTimescale))
            CMTimebaseSetRate(tb, rate: 1.0)
        }
    }

    func handlePiPStopped() {
        guard state != .inactive else { return }
        _wasPlayingAtStop = pipPlayer?.isPlaying ?? false
        _latestPosition = pipPlayer?.currentPosition ?? _latestPosition
        pipPlayer?.terminate()
        pipPlayer = nil
        pipTimebase = nil
        displayLayer.controlTimebase = nil
        state = .inactive
        onStateChanged?(.inactive)
    }

    func handleRestoreUI(completion: @escaping (Bool) -> Void) {
        onRestoreUI?()
        completion(true)
    }

    func handleSetPlaying(_ playing: Bool) {
        if playing {
            pipPlayer?.play()
            if let tb = pipTimebase {
                CMTimebaseSetTime(tb, time: CMTime(seconds: currentPosition, preferredTimescale: pipTimescale))
                CMTimebaseSetRate(tb, rate: 1.0)
            }
        } else {
            pipPlayer?.pause()
            if let tb = pipTimebase {
                CMTimebaseSetRate(tb, rate: 0.0)
            }
        }
    }

    func handleSkip(by interval: Double, completion: @escaping () -> Void) {
        let newPosition = max(0, currentPosition + interval)
        pipPlayer?.seek(to: newPosition)
        _latestPosition = newPosition
        if let tb = pipTimebase {
            let newTime = CMTime(seconds: newPosition, preferredTimescale: pipTimescale)
            CMTimebaseSetTime(tb, time: newTime)
            CMTimebaseSetRate(tb, rate: isPlaying ? 1.0 : 0.0)
        }
        completion()
    }

    func handleTimeRangeRequest() -> CMTimeRange {
        let seconds = duration
        if seconds > 0 {
            return CMTimeRange(start: .zero, duration: CMTime(seconds: seconds, preferredTimescale: pipTimescale))
        }
        return CMTimeRange(start: .zero, duration: CMTime(seconds: pipFallbackDuration, preferredTimescale: pipTimescale))
    }
}

// MARK: - PiPPlayerDelegate

extension PiPManager: PiPPlayerDelegate {

    func pipPlayer(_ player: any PiPPlayerProtocol, didOutputFrame sampleBuffer: CMSampleBuffer) {
        guard state == .active || state == .starting else { return }

        // 同步 timebase
        if let tb = pipTimebase {
            let syncTime = CMTime(seconds: player.currentPosition, preferredTimescale: pipTimescale)
            CMTimebaseSetTime(tb, time: syncTime)
        }

        guard displayLayer.isReadyForMoreMediaData else {
            dropCount += 1
            if dropCount == 1 {
                ANX.logError(.player, "[PiPManager] Layer 未就绪，开始丢帧")
            }
            return
        }

        if frameCount == 0 {
            ANX.logInfo(.player, "[PiPManager] 首帧入队")
        }

        displayLayer.enqueue(sampleBuffer)

        if displayLayer.status == .failed {
            ANX.logError(.player, "[PiPManager] Layer 入队后失败: \(displayLayer.error?.localizedDescription ?? "nil")")
        }

        // 首帧入队后通知平台层启动 PiP
        if !didStartPiPController {
            didStartPiPController = true
            onReadyForPiPStart?()
        }

        frameCount += 1
    }

    func pipPlayer(_ player: any PiPPlayerProtocol, didChangeVideoSize size: CGSize) {
        ANX.logInfo(.player, "[PiPManager] 视频尺寸变更: \(Int(size.width))x\(Int(size.height)))")
    }

    func pipPlayer(_ player: any PiPPlayerProtocol, didChangePosition position: Double) {
        _latestPosition = position
        onPositionUpdate?(position)
    }

    func pipPlayer(_ player: any PiPPlayerProtocol, didChangePlayPause isPlaying: Bool) {
        // 可扩展：向上层通知播放状态变化
    }

    func pipPlayerDidEndFile(_ player: any PiPPlayerProtocol) {
        ANX.logInfo(.player, "[PiPManager] 播放结束")
        cleanup()
    }
}

// MARK: - PiPSampleBufferView

class PiPSampleBufferView: ANXView {

    fileprivate let displayLayer = AVSampleBufferDisplayLayer()

    override init(frame: CGRect) {
        super.init(frame: frame)
        #if os(iOS) || os(tvOS)
        layer.addSublayer(displayLayer)
        #endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        displayLayer.frame = bounds
    }
}
