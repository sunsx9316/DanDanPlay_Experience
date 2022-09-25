//
//  PlayerSlider.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/12.
//

import Cocoa

typealias PlayerSliderEventAction = ((PlayerSlider, [PlayerSlider.EventParameter: Any]?) -> Void)

class PlayerSlider: BaseView {
    
    enum EventParameter {
        case atProgress
    }
    
    enum Events {
        case mouseExited
        case mouseEntered
        case mouseMoved
        case mouseUp
        case mouseDown
        case mouseDragged
    }
    
    private lazy var eventMap = [Events: PlayerSliderEventAction]()

    private lazy var trackingArea: NSTrackingArea = {
        let trackingArea = NSTrackingArea(rect: self.frame, options: [.activeInKeyWindow, .mouseMoved, .mouseEnteredAndExited, .inVisibleRect], owner: self)
        return trackingArea
    }()
    
    private lazy var slider: BaseView = {
        let slider = BaseView()
        slider.wantsLayer = true
        slider.bgColor = .systemBlue
        slider.layer?.masksToBounds = true
        slider.layer?.maskedCorners = [.layerMaxXMaxYCorner, .layerMaxXMinYCorner]
        return slider
    }()
    
    private(set) var isTracking = false
    
    var progress: Double = 0 {
        didSet {
            self.needsLayout = true
        }
    }
    
    var isContinue = false
    
    var trackFillColor: NSColor? = NSColor.mainColor {
        didSet {
            self.slider.bgColor = self.trackFillColor
        }
    }
    
    var progressHeight: CGFloat = 5 {
        didSet {
            self.needsLayout = true
            self.slider.layer?.cornerRadius = self.progressHeight / 2
        }
    }
    
    // MARK: Life Circle
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    deinit {
        self.removeTrackingArea(self.trackingArea)
    }
    
    override func mouseExited(with event: NSEvent) {
        self.eventMap[.mouseExited]?(self, [.atProgress: self.progress(with: event)])
    }
    
    override func mouseEntered(with event: NSEvent) {
        self.eventMap[.mouseEntered]?(self, [.atProgress: self.progress(with: event)])
    }
    
    override func mouseMoved(with event: NSEvent) {
        self.eventMap[.mouseMoved]?(self, [.atProgress: self.progress(with: event)])
    }
    
    override func mouseUp(with event: NSEvent) {
        self.progress = self.progress(with: event)
        self.eventMap[.mouseUp]?(self, [.atProgress: self.progress])
        self.isTracking = false
    }
    
    override func mouseDown(with event: NSEvent) {
        self.eventMap[.mouseDown]?(self, [.atProgress: self.progress(with: event)])
    }
    
    override func mouseDragged(with event: NSEvent) {
        self.isTracking = true
        let value = self.progress(with: event)
        self.progress = value
        if self.isContinue {
            self.eventMap[.mouseDragged]?(self, [.atProgress: value])
        } else {
            self.eventMap[.mouseMoved]?(self, [.atProgress: value])
        }
    }
    
    override var mouseDownCanMoveWindow: Bool {
        return false
    }
    
    override func layout() {
        super.layout()
        
        let width = self.frame.width
        let height = self.progressHeight
        self.slider.frame = CGRect(x: 0, y: (self.bounds.height - height) / 2, width: width * self.progress, height: height)
    }
    
    func addEvent(_ event: Events, action: @escaping(PlayerSliderEventAction)) {
        self.eventMap[event] = action
    }
    
    // MARK: Private Method
    private func setupInit() {
        self.wantsLayer = true
        self.bgColor = NSColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.3)
        self.slider.bgColor = self.trackFillColor
        self.progressHeight = 5
        
        self.addTrackingArea(self.trackingArea)
        self.addSubview(self.slider)
    }
    
    private func progress(with event: NSEvent) -> Double {
        let point = event.locationInWindow
        let pointInView = self.convert(point, to: nil)
        
        var progress = pointInView.x / self.frame.width
        if (progress.isNaN || progress < 0) {
            progress = 0
        }
        
        return progress;
    }
}
