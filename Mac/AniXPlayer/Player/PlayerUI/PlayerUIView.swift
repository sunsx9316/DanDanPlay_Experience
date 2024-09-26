//
//  PlayerUIView.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import Cocoa
import AVFoundation
import SnapKit
import YYCategories

protocol PlayerUIViewDelegate: AnyObject {
    
    func onTouchDanmakuSettingButton(playerUIView: PlayerUIView, button: NSButton)
    
    func onTouchMediaSettingButton(playerUIView: PlayerUIView, button: NSButton)
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool)
    
    func onTouchPlayerList(playerUIView: PlayerUIView, button: NSButton)
    
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView)
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool)
    
    func onTouchNextButton(playerUIView: PlayerUIView)
    
    func doubleTap(playerUIView: PlayerUIView)
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat)
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool)
    
    func openButtonDidClick(playerUIView: PlayerUIView, button: NSButton)
    
    func onClickRightMouse(playerUIView: PlayerUIView, at point: NSPoint)
}

protocol PlayerUIViewDataSource: AnyObject {
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat
    
    func playerMediaThumbnailer(playerUIView: PlayerUIView) -> MediaThumbnailer?
    
}

class PlayerUIView: BaseView {
    
    var title: String? {
        didSet {
            if let title = self.title {
                self.topView.titleLabel.stringValue = title
                self.topView.titleLabel.toolTip = title
            } else {
                self.topView.titleLabel.stringValue = ""
                self.topView.titleLabel.toolTip = ""
            }
        }
    }
    
    var isPlay = false {
        didSet {
            if self.isPlay {
                self.bottomView.playButton.state = .on
            } else {
                self.bottomView.playButton.state = .off
            }
        }
    }
    
    weak var delegate: PlayerUIViewDelegate?
    
    weak var dataSource: PlayerUIViewDataSource?
    
    private lazy var doubleTapGes: NSClickGestureRecognizer = {
        let doubleTap = NSClickGestureRecognizer(target: self, action: #selector(PlayerUIView.doubleTap))
        doubleTap.numberOfClicksRequired = 2
        return doubleTap
    }()
    
    private lazy var leftClickGes: NSClickGestureRecognizer = {
        let singleTap = NSClickGestureRecognizer(target: self, action: #selector(PlayerUIView.handleLeftClick))
        singleTap.numberOfClicksRequired = 1
        singleTap.delegate = self
        singleTap.buttonMask = 0x1
        return singleTap
    }()
    
    private lazy var rightClickGes: NSClickGestureRecognizer = {
        let singleTap = NSClickGestureRecognizer(target: self, action: #selector(PlayerUIView.handleRightClick))
        singleTap.numberOfClicksRequired = 1
        singleTap.buttonMask = 0x2
        singleTap.delegate = self
        return singleTap
    }()
    
    private lazy var openButton: Button = {
        var openButton = Button.custom()
        openButton.bezelStyle = .texturedSquare
        openButton.title = NSLocalizedString("打开...", comment: "")
        openButton.isBordered = true
        openButton.showsBorderOnlyWhileMouseInside = true
        openButton.addAction( { [weak self] (button) in
            guard let self = self, let button = button as? NSButton else { return }
            
            self.delegate?.openButtonDidClick(playerUIView: self, button: button)
        })
        return openButton
    }()
    
    private lazy var gestureView: BaseView = {
        let gestureView = BaseView()
        gestureView.addGestureRecognizer(self.doubleTapGes)
        gestureView.addGestureRecognizer(self.leftClickGes)
        gestureView.addGestureRecognizer(self.rightClickGes)
        return gestureView
    }()
    
    private lazy var topView: PlayerUITopView = {
        let topView = PlayerUITopView()
        return topView
    }()
    
    private lazy var bottomView: PlayerUIBottomView = {
        let bottomView = PlayerUIBottomView()
        bottomView.playerListButton.addTarget(self, action: #selector(onTouchPlayerList(_:)))
        bottomView.nextButton.addTarget(self, action: #selector(onTouchNextButton(_:)))
        bottomView.playButton.addTarget(self, action: #selector(onTouchPlayButton(_:)))
        bottomView.mediaSettingButton.addTarget(self, action: #selector(onTouchMediaButton(_:)))
        bottomView.danmakuSettingButton.addTarget(self, action: #selector(onTouchDanmakuButton(_:)))
        bottomView.progressSlider.addEvent(.mouseUp, action: { [weak self] (sender, _) in
            guard let self = self else { return }
            self.delegate?.tapSlider(playerUIView: self, progress: CGFloat(sender.progress))
        })
        
        bottomView.progressSlider.addEvent(.mouseMoved, action: { [weak self] (sender, parameter) in
            guard let self = self else { return }
            let progress = parameter?[.atProgress] as? Double ?? 0
            self.onSliderMouseMove(sender, progress: progress)
        })
        
        bottomView.progressSlider.addEvent(.mouseExited, action: { [weak self] (sender, _) in
            guard let self = self else { return }
            
            self.timeTipsView?.dismiss()
        })
        return bottomView
    }()
    
    private lazy var timeFormatter: DateFormatter = {
        var timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "mm:ss"
        return timeFormatter
    }()
    
    private weak var timeTipsView: TimeTipsView?
    
    private var autoHiddenTimer: Timer?
    
    private(set) var hiddenControlView = false {
        didSet {
            self.delegate?.playerUIView(self, didChangeControlViewState: !self.hiddenControlView)
        }
    }
    
    private var hiddenTime: TimeInterval = 4
    
    var showOpenButton: Bool = true {
        didSet {
            self.openButton.isHidden = !showOpenButton
        }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    override func hitTest(_ point: NSPoint) -> NSView? {
        let view = super.hitTest(point)
        if self.topView.frame.contains(point) || self.bottomView.frame.contains(point) {
            resumeTimer()
        }
        return view
    }
    
    override var isFlipped: Bool {
        return true
    }
    
    func updateTime() {
        let currentTime = dataSource?.playerCurrentTime(playerUIView: self) ?? 0
        let totalTime = dataSource?.playerTotalTime(playerUIView: self) ?? 0
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        
        self.bottomView.timeLabel.stringValue = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
        if !self.bottomView.progressSlider.isTracking {
            self.bottomView.progressSlider.progress = Double(dataSource?.playerProgress(playerUIView: self) ?? 0)
        }
    }
    
    func autoShowControlView(completion: (() -> ())? = nil) {
        func startHiddenTimerAction() {
            self.autoHiddenTimer?.invalidate()
            
            self.autoHiddenTimer = Timer.scheduledTimer(withTimeInterval: hiddenTime, block: { (timer) in
                self.autoHideControlView()
            }, repeats: false)
            self.autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: hiddenTime);
            
            completion?()
        }
        
        DispatchQueue.main.async {
            if self.hiddenControlView {
                self.hiddenControlView = false
                
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = .init(name: .easeInEaseOut)
                    
                    self.topView.animator().transform = .identity
                    self.bottomView.animator().transform = .identity
                } completionHandler: {
                    startHiddenTimerAction()
                }
            } else {
                startHiddenTimerAction();
            }
        }
    }
        
    func autoHideControlView() {
        DispatchQueue.main.async {
            //显示状态 隐藏
            if self.hiddenControlView == false {
                self.hiddenControlView = true
                self.autoHiddenTimer?.invalidate()
                NSAnimationContext.runAnimationGroup { ctx in
                    ctx.duration = 0.3
                    ctx.timingFunction = .init(name: .easeInEaseOut)
                    
                    self.topView.animator().transform = CGAffineTransform(translationX: 0, y: -self.topView.frame.height)
                    self.bottomView.animator().transform = CGAffineTransform(translationX: 0, y: self.bottomView.frame.height - 5)
                } completionHandler: {
                    self.timeTipsView?.dismiss()
                }
            }
        }
    }
    
    //MARK: - Private Method
    
    //MARK: 点击
    
    @IBAction private func onTouchMediaButton(_ sender: NSButton) {
        delegate?.onTouchMediaSettingButton(playerUIView: self, button: sender)
    }
    
    @IBAction private func onTouchDanmakuButton(_ sender: NSButton) {
        delegate?.onTouchDanmakuSettingButton(playerUIView: self, button: sender)
    }
    
    @IBAction private func onTouchPlayerList(_ sender: NSButton) {
        delegate?.onTouchPlayerList(playerUIView: self, button: sender)
    }
    
    @objc private func doubleTap(gesture: NSClickGestureRecognizer) {
        delegate?.doubleTap(playerUIView: self)
    }
    
    @objc private func handleLeftClick(gesture: NSClickGestureRecognizer) {
        autoHiddenTimer?.invalidate()
        if self.hiddenControlView {
            autoShowControlView()
        } else {
            autoHideControlView()
        }
    }
    
    @objc private func handleRightClick(_ ges: NSClickGestureRecognizer) {
        delegate?.onClickRightMouse(playerUIView: self, at: ges.location(in: self))
    }
    
    @objc private func onTouchPlayButton(_ sender: NSButton) {
        self.isPlay.toggle()
        delegate?.onTouchPlayButton(playerUIView: self, isSelected: self.isPlay)
    }
    
    @objc private func onTouchNextButton(_ sender: NSButton) {
        delegate?.onTouchNextButton(playerUIView: self)
    }
    
    
    //MARK: 滑动条
    
    @objc private func onSliderMouseMove(_ sender: PlayerSlider, progress: CGFloat) {
        
        guard let totalTime = dataSource?.playerTotalTime(playerUIView: self), totalTime > 0 else {
            self.timeTipsView?.dismiss()
            return
        }
        
        let currentTime = totalTime * progress
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        
        let timeStr = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
        
        let hud: TimeTipsView

        if let aHud = self.timeTipsView {
            hud = aHud
        } else {
            hud = TimeTipsView()
            hud.show(from: self)
            self.timeTipsView = hud
        }

        hud.timeLabel.text = timeStr
        
        let mouseLocation = self.window?.mouseLocationOutsideOfEventStream ?? .zero
        var frame = CGRect(x: 0, y: 0, width: 100, height: 35)
        frame.origin.x = mouseLocation.x - (frame.width / 2)
        frame.origin.y = self.bottomView.frame.minY - (frame.height + 5)
        
        if (frame.minX < 5) {
            frame.origin.x = 5
        }

        let rightEdge = self.frame.width
        if frame.maxX > rightEdge - 5 {
            frame.origin.x = rightEdge - frame.width - 5
        }

        hud.frame = frame
    }
    
    //MARK: 其他私有方法
    private func setupInit() {
        
        self.addSubview(self.gestureView)
        self.addSubview(self.topView)
        self.addSubview(self.bottomView)
        self.addSubview(openButton)
        
        self.openButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 150, height: 60))
        }
        
        self.gestureView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.topView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        self.bottomView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
        }
    }
    
    private func suspendTimer() {
        autoHiddenTimer?.fireDate = Date.distantFuture
    }
    
    private func resumeTimer() {
        autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: hiddenTime)
    }

    
}

extension PlayerUIView: NSGestureRecognizerDelegate {
    func gestureRecognizer(_ gestureRecognizer: NSGestureRecognizer, shouldBeRequiredToFailBy otherGestureRecognizer: NSGestureRecognizer) -> Bool {
        if otherGestureRecognizer == self.doubleTapGes {
            return true
        }
        return false
    }
}
