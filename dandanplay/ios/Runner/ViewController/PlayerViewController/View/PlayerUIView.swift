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
    
    weak var delegate: PlayerUIViewDelegate?
    
    private lazy var timeFormatter: DateFormatter = {
        var timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "mm:ss"
        return timeFormatter
    }()
    
    private var isDragingSlider = false
    
    override func awakeFromNib() {
        super.awakeFromNib()
        danmakuSwitch.onTintColor = UIColor.mainColor
//        danmakuSwitch.thumbImage = UIImage(named: "Player/player_danmaku_switch_thumb")
        danmakuSwitch.addTarget(self, action: #selector(PlayerUIView.onTouchSwitch(_:)), for: .valueChanged)
        danmakuSwitch.backgroundColor = nil
        
        titleLabel.text = nil
        slider.tintColor = UIColor.mainColor
        
        slider.setThumbImage(UIImage(color: UIColor.white, size: CGSize(width: 16, height: 10))?.byRoundCornerRadius(2), for: .normal)
        
        let tap = UITapGestureRecognizer(target: self, action: #selector(PlayerUIView.doubleTap))
        tap.numberOfTapsRequired = 2
        self.gestureView.addGestureRecognizer(tap)
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
    
    //MARK: Private Method
    @IBAction func onTouchBackButton(_ sender: UIButton) {
        viewController?.dismiss(animated: true, completion: nil)
    }
    
    @IBAction func onTouchMoreButton(_ sender: UIButton) {
        delegate?.onTouchMoreButton(playerUIView: self)
    }
    
    @objc private func onTouchSwitch(_ sender: SevenSwitch) {
        delegate?.onTouchDanmakuSwitch(playerUIView: self, isOn: sender.isOn())
    }
    
    @IBAction func onTouchPlayerList(_ sender: UIButton) {
        delegate?.onTouchPlayerList(playerUIView: self)
    }
    
    //MARK: 滑动条
    @objc private func doubleTap(gesture: UITapGestureRecognizer) {
        delegate?.doubleTap(playerUIView: self)
    }
    
    @IBAction func tapUp(slider: UISlider) {
        delegate?.tapSlider(playerUIView: self, progress: CGFloat(slider.value))
        endSliderDraging()
    }
    
    @IBAction func tapDown(slider: UISlider) {
        isDragingSlider = true
    }
    
    @IBAction func tapCancel(slider: UISlider) {
        endSliderDraging()
    }
    
    
    private func endSliderDraging() {
        isDragingSlider = false
    }
    
}
