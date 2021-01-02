//
//  PlayerUIView.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit
import AVFoundation

protocol PlayerUIViewDelegate: class {
    func onTouchMoreButton(playerUIView: PlayerUIView)
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool)
    func onTouchPlayerList(playerUIView: PlayerUIView)
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView)
    func doubleTap(playerUIView: PlayerUIView)
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat)
}

protocol PlayerUIViewDataSource: class {
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat
}

extension PlayerUIViewDelegate {
    func onTouchMoreButton(playerUIView: PlayerUIView) {}
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {}
    func onTouchPlayerList(playerUIView: PlayerUIView) {}
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView) {}
    func doubleTap(playerUIView: PlayerUIView) {}
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {}
}

class PlayerUIView: UIView {
    
    enum PanType {
        case progress
        case brightness
        case volume
    }
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var danmakuSwitch: SevenSwitch!
    @IBOutlet weak var gestureView: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var bottomView: UIView!
    
    
    weak var delegate: PlayerUIViewDelegate?
    weak var dataSource: PlayerUIViewDataSource?
    
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
    private var hiddenControlView = false
    private var hiddenTime: TimeInterval = 4
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
    
    private var lastPanDate: Data?
    private var obsObj: AnyObject?
    
    override func awakeFromNib() {
        super.awakeFromNib()
        
        danmakuSwitch.onTintColor = UIColor.mainColor
//        danmakuSwitch.thumbImage = UIImage(named: "Player/player_danmaku_switch_thumb")
        danmakuSwitch.addTarget(self, action: #selector(PlayerUIView.onTouchSwitch(_:)), for: .valueChanged)
        danmakuSwitch.backgroundColor = nil
        
        titleLabel.text = nil
        slider.tintColor = UIColor.mainColor
        
        slider.setThumbImage(UIImage(color: UIColor.white, size: CGSize(width: 16, height: 10))?.byRoundCornerRadius(2), for: .normal)
        
        let doubleTap = UITapGestureRecognizer(target: self, action: #selector(PlayerUIView.doubleTap))
        doubleTap.numberOfTapsRequired = 2
        
        let singleTap = UITapGestureRecognizer(target: self, action: #selector(PlayerUIView.singleTap))
        singleTap.numberOfTapsRequired = 1
        
        singleTap.require(toFail: doubleTap)
        
        let panGes = UIPanGestureRecognizer(target: self, action: #selector(panGesture(_:)))
        
        self.gestureView.addGestureRecognizer(doubleTap)
        self.gestureView.addGestureRecognizer(singleTap)
        self.gestureView.addGestureRecognizer(panGes)
        
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
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        resumeTimer()
    }
    
    func updateTime() {
        let currentTime = dataSource?.playerCurrentTime(playerUIView: self) ?? 0
        let totalTime = dataSource?.playerTotalTime(playerUIView: self) ?? 0
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        timeLabel.text = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
        if !isDragingSlider {
            slider.value = Float(dataSource?.playerProgress(playerUIView: self) ?? 0)
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
                })
            }
        }
    }
    
    //MARK: - Private Method
    //MARK: 点击
    @IBAction func onTouchBackButton(_ sender: UIButton) {
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onTouchMoreButton(_ sender: UIButton) {
        delegate?.onTouchMoreButton(playerUIView: self)
    }
    
    @objc private func onTouchSwitch(_ sender: SevenSwitch) {
        delegate?.onTouchDanmakuSwitch(playerUIView: self, isOn: sender.isOn())
        resumeTimer()
    }
    
    @IBAction func onTouchPlayerList(_ sender: UIButton) {
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
    
    @IBAction func onTouchSendDanmakuButon(_ sender: UIButton) {
        delegate?.onTouchSendDanmakuButton(playerUIView: self)
    }
    
    //MARK: 滑动条
    @IBAction func tapUp(slider: UISlider) {
        delegate?.tapSlider(playerUIView: self, progress: CGFloat(slider.value))
        isDragingSlider = false
    }
    
    @IBAction func tapDown(slider: UISlider) {
        isDragingSlider = true
    }
    
    @IBAction func tapCancel(slider: UISlider) {
        isDragingSlider = false
    }
    
    @objc private func panGesture(_ ges: UIPanGestureRecognizer) {
 
        switch ges.state {
        case .began:
            let velocity = ges.velocity(in: nil)
            let location = ges.location(in: self)
            
            //横向运动
            if abs(velocity.x) > abs(velocity.y) {
                self.panType = .progress
                self.tapDown(slider: self.slider)
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
                
                self.slider.value += Float(diff)
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
                self.tapUp(slider: self.slider)
            }
            self.panType = nil
            self.brightnessView.dismiss()
            self.volumeView.dismiss()
            break
        }
    }
    
    //MARK: -
    private func suspendTimer() {
        autoHiddenTimer?.fireDate = Date.distantFuture
    }
    
    private func resumeTimer() {
        autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: hiddenTime)
    }

    
}
