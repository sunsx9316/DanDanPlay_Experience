//
//  PlayerUIView.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit
import AVFoundation
import SnapKit

protocol PlayerUIViewDelegate: AnyObject {
    
    func onTouchMoreButton(playerUIView: PlayerUIView)
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool)
    
    func onTouchPlayerList(playerUIView: PlayerUIView)
    
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView)
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool)
    
    func onTouchNextButton(playerUIView: PlayerUIView)
    
    func doubleTap(playerUIView: PlayerUIView)
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat)
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool)
}

protocol PlayerUIViewDataSource: AnyObject {
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat
    
}

private class PlayerSnapTimeView: UIView {
    
    lazy var label: UILabel = {
        let label = UILabel()
        label.font = .ddp_small
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()
    
    override init(frame: CGRect) {
        super.init(frame: frame)
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.5)
        self.layer.cornerRadius = 5
        self.layer.masksToBounds = true
        self.addSubview(self.label)
        self.label.snp.makeConstraints { (make) in
            make.edges.equalToSuperview().inset(UIEdgeInsets(top: 10, left: 10, bottom: 10, right: 10))
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class PlayerUIView: UIView {
    
    enum PanType {
        case progress
        case brightness
        case volume
    }
    
    var title: String? {
        didSet {
            if let title = self.title {
                self.topView.titleLabel.attributedString = .init(string: title, attributes: [.font : UIFont.systemFont(ofSize: 15), .foregroundColor : UIColor.white])
            } else {
                self.topView.titleLabel.attributedString = nil
            }
        }
    }
    
    var isPlay = false {
        didSet {
            self.bottomView.playButton.isSelected = self.isPlay
        }
    }
    
    weak var delegate: PlayerUIViewDelegate?
    
    weak var dataSource: PlayerUIViewDataSource?
    
    private lazy var gestureView: UIView = {
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(PlayerUIView.doubleTap))
        doubleTap.numberOfTapsRequired = 2
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(PlayerUIView.singleTap))
        singleTap.numberOfTapsRequired = 1
        
        singleTap.require(toFail: doubleTap)
        
        let panGes = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        
        let gestureView = UIView()
        gestureView.addGestureRecognizer(doubleTap)
        gestureView.addGestureRecognizer(singleTap)
        gestureView.addGestureRecognizer(panGes)
        return gestureView
    }()
    
    private lazy var topView: PlayerUITopView = {
        let topView = PlayerUITopView()
        topView.backButton.addTarget(self, action: #selector(onTouchBackButton(_:)), for: .touchUpInside)
        topView.settingButton.addTarget(self, action: #selector(onTouchMoreButton(_:)), for: .touchUpInside)
        return topView
    }()
    
    private lazy var bottomView: PlayerUIBottomView = {
        let bottomView = PlayerUIBottomView()
        bottomView.progressSlider.addTarget(self, action: #selector(tapCancel(slider:)), for: .touchCancel)
        bottomView.progressSlider.addTarget(self, action: #selector(tapCancel(slider:)), for: .touchUpOutside)
        bottomView.progressSlider.addTarget(self, action: #selector(tapDown(slider:)), for: .touchDown)
        bottomView.progressSlider.addTarget(self, action: #selector(tapUp(slider:)), for: .touchUpInside)
        bottomView.progressSlider.addTarget(self, action: #selector(onSliderValueChange(_:)), for: .valueChanged)
        bottomView.playerListButton.addTarget(self, action: #selector(onTouchPlayerList(_:)), for: .touchUpInside)
        bottomView.nextButton.addTarget(self, action: #selector(onTouchNextButton(_:)), for: .touchUpInside)
        bottomView.playButton.addTarget(self, action: #selector(onTouchPlayButton(_:)), for: .touchUpInside)
        return bottomView
    }()
    
    private weak var _brightnessView: SliderControlView?
    
    private weak var _volumeView: VolumeControlView?
    
    private var brightnessView: SliderControlView {
        let brightnessView: SliderControlView
        if let view = self._brightnessView {
            brightnessView = view
        } else {
            brightnessView = SliderControlView(image: UIImage(named: "Player/player_brightness"))
            brightnessView.progress = UIScreen.main.brightness
            self._brightnessView = brightnessView
        }
        return brightnessView
    }
    
    private var volumeView: VolumeControlView {
        let controlView: VolumeControlView
        if let view = self._volumeView {
            controlView = view
        } else {
            controlView = VolumeControlView(image: UIImage(named: "Player/player_volume"))
            controlView.progress = CGFloat(AVAudioSession.sharedInstance().outputVolume)
            self._volumeView = controlView
        }
        return controlView
    }
    
    private lazy var snapTimeView: PlayerSnapTimeView = {
        return PlayerSnapTimeView()
    }()
    
    private var panType: PanType?
    
    private lazy var timeFormatter: DateFormatter = {
        var timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "mm:ss"
        return timeFormatter
    }()
    
    private var isDragingSlider = false {
        didSet {
            if isDragingSlider {
                suspendTimer()
            } else {
                resumeTimer()
            }
        }
        
    }
    
    private var autoHiddenTimer: Timer?
    
    private(set) var hiddenControlView = false {
        didSet {
            if self.hiddenControlView {
                self.topView.titleLabel.paused()
            } else {
                self.topView.titleLabel.start()
            }
            self.delegate?.playerUIView(self, didChangeControlViewState: !self.hiddenControlView)
        }
    }
    
    private var hiddenTime: TimeInterval = 4
    
    private var lastPanDate: Data?
    
    private var obsObj: AnyObject?

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        let view = super.hitTest(point, with: event)
        if self.topView.frame.contains(point) || self.bottomView.frame.contains(point) {
            resumeTimer()
        }
        return view
    }
    
    func updateTime() {
        let currentTime = dataSource?.playerCurrentTime(playerUIView: self) ?? 0
        let totalTime = dataSource?.playerTotalTime(playerUIView: self) ?? 0
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        
        self.bottomView.timeLabel.text = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
        if !isDragingSlider {
            self.bottomView.progressSlider.value = Float(dataSource?.playerProgress(playerUIView: self) ?? 0)
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
                
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    self.topView.transform = .identity
                    self.bottomView.transform = .identity
                    self.topView.alpha = 1
                    self.bottomView.alpha = 1
                }) { (finish) in
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
                
                UIView.animate(withDuration: 0.3, delay: 0, options: .curveEaseInOut, animations: {
                    self.topView.transform = CGAffineTransform(translationX: 0, y: -self.topView.frame.height)
                    self.bottomView.transform = CGAffineTransform(translationX: 0, y: self.bottomView.frame.height)
                    self.topView.alpha = 0
                    self.bottomView.alpha = 0
                })
            }
        }
    }
    
    //MARK: - Private Method
    
    //MARK: 点击
    @IBAction private func onTouchBackButton(_ sender: UIButton) {
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction private func onTouchMoreButton(_ sender: UIButton) {
        delegate?.onTouchMoreButton(playerUIView: self)
    }
    
    @IBAction private func onTouchPlayerList(_ sender: UIButton) {
        delegate?.onTouchPlayerList(playerUIView: self)
    }
    
    @objc private func doubleTap(gesture: UITapGestureRecognizer) {
        delegate?.doubleTap(playerUIView: self)
    }
    
    @objc private func singleTap(gesture: UITapGestureRecognizer) {
        autoHiddenTimer?.invalidate()
        if self.hiddenControlView {
            autoShowControlView()
        } else {
            autoHideControlView()
        }
    }
    
    @objc private func onTouchPlayButton(_ sender: UIButton) {
        sender.isSelected.toggle()
        delegate?.onTouchPlayButton(playerUIView: self, isSelected: sender.isSelected)
    }
    
    @objc private func onTouchNextButton(_ sender: UIButton) {
        delegate?.onTouchNextButton(playerUIView: self)
    }
    
    
    //MARK: 滑动条
    @objc private func onSliderValueChange(_ sender: UISlider) {
        let totalTime = dataSource?.playerTotalTime(playerUIView: self) ?? 0
        updateDataTimeSnapLabel(currentTime: TimeInterval(sender.value * Float(totalTime)))
    }
    
    @objc private func tapUp(slider: UISlider) {
        delegate?.tapSlider(playerUIView: self, progress: CGFloat(slider.value))
        isDragingSlider = false
        hideTimeSnapLabel()
    }
    
    @objc private func tapDown(slider: UISlider) {
        isDragingSlider = true
        showTimeSnapLabel()
    }
    
    @objc private func tapCancel(slider: UISlider) {
        isDragingSlider = false
        hideTimeSnapLabel()
    }
    
    @objc private func panGesture(_ ges: UIPanGestureRecognizer) {
 
        switch ges.state {
        case .began:
            let velocity = ges.velocity(in: nil)
            let location = ges.location(in: self)
            
            //横向运动
            if abs(velocity.x) > abs(velocity.y) {
                self.panType = .progress
                self.tapDown(slider: self.bottomView.progressSlider)
            } else if location.x < self.frame.size.width / 2 {
                self.panType = .brightness
                
                let brightnessView = self.brightnessView
                brightnessView.showFromView(self)
                
            } else {
                self.panType = .volume
                
                let controlView = self.volumeView
                controlView.showFromView(self)
            }
        case .changed:
            
            guard let panType = self.panType else { return }
            
            let translation = ges.translation(in: self)
            ges.setTranslation(.zero, in: nil)
            
            switch panType {
            case .progress:
                let width = self.frame.size.width
                let diff = width > 0 ? translation.x / width : 0;
                
                self.bottomView.progressSlider.value += Float(diff)
                self.onSliderValueChange(self.bottomView.progressSlider)
            case .brightness, .volume:
                let height = self.frame.size.height
                let diff = height > 0 ? -translation.y / height : 0;
                
                if panType == .brightness {
                    UIScreen.main.brightness += diff
                    self.brightnessView.progress = UIScreen.main.brightness
                } else {
                    self.volumeView.progress += diff
                }
            }
            break
        default:
            if self.panType == .progress {
                self.tapUp(slider: self.bottomView.progressSlider)
            }
            self.panType = nil
            self.brightnessView.dismiss()
            self.volumeView.dismiss()
            break
        }
    }
    
    //MARK: 其他私有方法
    private func setupInit() {
        
        self.addSubview(self.gestureView)
        self.addSubview(self.topView)
        self.addSubview(self.bottomView)
        
        self.gestureView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.topView.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        
        self.bottomView.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
        }
        
        let audioSession = AVAudioSession.sharedInstance()
        try? audioSession.setActive(true)
        self.obsObj = audioSession.observe(\.outputVolume, options: .new) { [weak self] (view, value) in
            guard let self = self else { return }
            
            //当前正在通过拖动调整音量
            if self.panType == .volume {
                return
            }
            
            let volume = value.newValue ?? 0
            
            let controlView = self.volumeView
            controlView.showFromView(self)
            controlView.dismissAfter(1)
            controlView.progress = CGFloat(volume)
        }
    }
    
    private func suspendTimer() {
        autoHiddenTimer?.fireDate = Date.distantFuture
    }
    
    private func resumeTimer() {
        autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: hiddenTime)
    }
    
    private func showTimeSnapLabel() {
        if self.snapTimeView.superview == nil {
            self.snapTimeView.alpha = 0
            self.addSubview(self.snapTimeView)
            self.snapTimeView.snp.makeConstraints { (make) in
                make.center.equalToSuperview()
                make.width.greaterThanOrEqualTo(110)
            }
            
            let currentTime = dataSource?.playerCurrentTime(playerUIView: self) ?? 0
            updateDataTimeSnapLabel(currentTime: currentTime)
        }
        
        UIView.animate(withDuration: 0.3) {
            self.snapTimeView.alpha = 1
        }
    }
    
    private func hideTimeSnapLabel() {
        if self.snapTimeView.superview == nil {
            return
        }
        
        UIView.animate(withDuration: 0.3) {
            self.snapTimeView.alpha = 0
        } completion: { (finish) in
            self.snapTimeView.removeFromSuperview()
        }
    }
    
    private func updateDataTimeSnapLabel(currentTime: TimeInterval) {
        let totalTime = dataSource?.playerTotalTime(playerUIView: self) ?? 0
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        snapTimeView.label.text = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
    }

    
}