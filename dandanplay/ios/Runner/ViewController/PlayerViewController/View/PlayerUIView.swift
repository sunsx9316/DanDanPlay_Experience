//
//  PlayerUIView.swift
//  Runner
//
//  Created by JimHuang on 2020/7/12.
//

import UIKit

protocol PlayerUIViewDelegate: class {
    func onTouchMoreButton(playerUIView: PlayerUIView)
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool)
    func onTouchPlayerList(playerUIView: PlayerUIView)
    func doubleTap(playerUIView: PlayerUIView)
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat)
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat
}

extension PlayerUIViewDelegate {
    func onTouchMoreButton(playerUIView: PlayerUIView) {}
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {}
    func onTouchPlayerList(playerUIView: PlayerUIView) {}
    func doubleTap(playerUIView: PlayerUIView) {}
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {}
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval { return 0 }
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval { return 0 }
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat { return 0 }
}

class PlayerUIView: UIView {
    
    @IBOutlet weak var titleLabel: UILabel!
    @IBOutlet weak var timeLabel: UILabel!
    @IBOutlet weak var danmakuSwitch: SevenSwitch!
    @IBOutlet weak var gestureView: UIView!
    @IBOutlet weak var slider: UISlider!
    @IBOutlet weak var topView: UIView!
    @IBOutlet weak var bottomView: UIView!
    
    
    weak var delegate: PlayerUIViewDelegate?
    
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
        
        self.gestureView.addGestureRecognizer(doubleTap)
        self.gestureView.addGestureRecognizer(singleTap)
    }
    
    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        
        resumeTimer()
    }
    
    func updateTime() {
        let currentTime = delegate?.playerCurrentTime(playerUIView: self) ?? 0
        let totalTime = delegate?.playerTotalTime(playerUIView: self) ?? 0
        let current = Date(timeIntervalSince1970: currentTime)
        let total = Date(timeIntervalSince1970: totalTime)
        timeLabel.text = timeFormatter.string(from: current) + "/" + timeFormatter.string(from: total)
        if !isDragingSlider {
            slider.value = Float(delegate?.playerProgress(playerUIView: self) ?? 0)
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
    
    //MARK: -
    private func suspendTimer() {
        autoHiddenTimer?.fireDate = Date.distantFuture
    }
    
    private func resumeTimer() {
        autoHiddenTimer?.fireDate = Date(timeIntervalSinceNow: hiddenTime)
    }

    
}
