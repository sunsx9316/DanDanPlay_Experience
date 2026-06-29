//
//  ProgressHUD.swift
//  ProgressHUD
//
//  Mac 版 HUD，API 对齐 MBProgressHUD
//

import AppKit

// MARK: - Enums

enum ProgressHUDMode: Int {
    case indeterminate
    case determinate
    case determinateHorizontalBar
    case annularDeterminate
    case customView
    case text
}

enum ProgressHUDAnimation: Int {
    case fade
    case zoom
    case zoomOut
    case zoomIn
}

enum ProgressHUDBackgroundStyle: Int {
    case solidColor
    case blur
}

// MARK: - Delegate

protocol ProgressHUDDelegate: AnyObject {
    func hudWasHidden(_ hud: ProgressHUD)
}

// MARK: - ProgressHUD

class ProgressHUD: NSView {

    // MARK: Class Methods

    @discardableResult
    class func showAdded(to view: NSView, animated: Bool) -> ProgressHUD {
        let hud = ProgressHUD(view: view)
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }

    @discardableResult
    class func hide(for view: NSView, animated: Bool) -> Bool {
        guard let hud = forView(view) else { return false }
        hud.hide(animated: animated)
        return true
    }

    class func forView(_ view: NSView) -> ProgressHUD? {
        for subview in view.subviews.reversed() {
            if let hud = subview as? ProgressHUD, !hud.isFinished {
                return hud
            }
        }
        return nil
    }

    // MARK: Initialization

    init(view: NSView) {
        super.init(frame: view.bounds)
        setupViews()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Public Properties

    weak var delegate: ProgressHUDDelegate?
    var completionBlock: (() -> Void)?

    var graceTime: TimeInterval = 0
    var minShowTime: TimeInterval = 0
    var removeFromSuperViewOnHide: Bool = false

    var mode: ProgressHUDMode = .indeterminate {
        didSet { updateIndicators() }
    }

    var contentColor: NSColor? {
        didSet {
            guard let color = contentColor else { return }
            label.textColor = color
            detailsLabel.textColor = color
            (indicator as? RoundProgressView)?.progressTintColor = color
            (indicator as? BarProgressView)?.progressColor = color
            progressIndicatorLayer?.color = color
        }
    }

    var animationType: ProgressHUDAnimation = .fade
    var offset: CGPoint = .zero { didSet { needsLayout = true } }
    var margin: CGFloat = 20 { didSet { needsLayout = true } }
    var minSize: CGSize = .zero { didSet { needsLayout = true } }
    var isSquare: Bool = false { didSet { needsLayout = true } }

    var bezelStyle: ProgressHUDBackgroundStyle = .solidColor {
        didSet { updateBezelStyle() }
    }

    var bezelColor: NSColor = NSColor.black.withAlphaComponent(0.6) {
        didSet { updateBezelAppearance() }
    }

    var cornerRadius: CGFloat = 15 { didSet { bezelView.layer?.cornerRadius = cornerRadius } }

    var progress: Float = 0 {
        didSet { updateProgress() }
    }

    var progressObject: Progress? {
        didSet {
            progressObservation?.invalidate()
            progressObservation = nil
            guard let obj = progressObject else { return }
            progressObservation = obj.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
                guard let self = self, let value = change.newValue else { return }
                self.progress = Float(value)
            }
        }
    }

    // MARK: Readonly Views

    private(set) var backgroundView: NSView!
    private(set) var bezelView: NSView!
    private(set) var label: NSTextField!
    private(set) var detailsLabel: NSTextField!
    private(set) var button: NSButton!

    var customView: NSView? {
        didSet { updateIndicators() }
    }

    // MARK: Convenience

    var labelText: String? {
        get { label.stringValue.isEmpty ? nil : label.stringValue }
        set {
            label.stringValue = newValue ?? ""
            needsLayout = true
        }
    }

    var detailsLabelText: String? {
        get { detailsLabel.stringValue.isEmpty ? nil : detailsLabel.stringValue }
        set {
            detailsLabel.stringValue = newValue ?? ""
            needsLayout = true
        }
    }

    // MARK: - Private Properties

    private var indicator: NSView?
    private var progressIndicatorLayer: ProgressIndicatorLayer?
    private var useAnimation: Bool = true
    private var isFinished: Bool = false
    private var showStarted: Date?
    private var graceTimer: Timer?
    private var hideDelayTimer: Timer?
    private var progressObservation: NSKeyValueObservation?
    private var defaultSpinnerSize: CGFloat = 60

    // MARK: - Show / Hide

    func show(animated: Bool) {
        useAnimation = animated
        isFinished = false
        showStarted = Date()

        if graceTime > 0 {
            isHidden = true
            alphaValue = 0
            graceTimer?.invalidate()
            graceTimer = Timer.scheduledTimer(withTimeInterval: graceTime, repeats: false) { [weak self] _ in
                guard let self = self, !self.isFinished else { return }
                self.performShow(animated: animated)
            }
        } else {
            performShow(animated: animated)
        }
    }

    func hide(animated: Bool) {
        hide(animated: animated, afterDelay: 0)
    }

    func hide(animated: Bool, afterDelay delay: TimeInterval) {
        graceTimer?.invalidate()
        graceTimer = nil

        if delay > 0 {
            hideDelayTimer?.invalidate()
            hideDelayTimer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
                self?.performHide(animated: animated)
            }
        } else {
            performHide(animated: animated)
        }
    }

    // MARK: - Private Show / Hide

    private func performShow(animated: Bool) {
        // If already finished (hide called during graceTime), don't show
        guard !isFinished else { return }

        isHidden = false
        updateIndicators()
        needsLayout = true

        NotificationCenter.default.post(name: ProgressHUD.willAppear, object: self)

        if animated {
            switch animationType {
            case .fade:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in
                    guard let self = self else { return }
                    NotificationCenter.default.post(name: ProgressHUD.didAppear, object: self)
                }
                animator().alphaValue = 1.0
                NSAnimationContext.endGrouping()

            case .zoom, .zoomIn:
                alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(1.3, 1.3, 1)
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in
                    guard let self = self else { return }
                    NotificationCenter.default.post(name: ProgressHUD.didAppear, object: self)
                }
                animator().alphaValue = 1.0
                bezelView.layer?.transform = CATransform3DIdentity
                NSAnimationContext.endGrouping()

            case .zoomOut:
                alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(0.7, 0.7, 1)
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in
                    guard let self = self else { return }
                    NotificationCenter.default.post(name: ProgressHUD.didAppear, object: self)
                }
                animator().alphaValue = 1.0
                bezelView.layer?.transform = CATransform3DIdentity
                NSAnimationContext.endGrouping()
            }
        } else {
            alphaValue = 1.0
            NotificationCenter.default.post(name: ProgressHUD.didAppear, object: self)
        }
    }

    private func performHide(animated: Bool) {
        // If not yet shown (still in graceTime), just mark finished
        if isHidden {
            isFinished = true
            done()
            return
        }

        let minInterval = minShowTime - Date().timeIntervalSince(showStarted ?? Date())
        if minInterval > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + minInterval) { [weak self] in
                self?.performHideAnimated(animated: animated)
            }
        } else {
            performHideAnimated(animated: animated)
        }
    }

    private func performHideAnimated(animated: Bool) {
        guard !isFinished else { return }
        NotificationCenter.default.post(name: ProgressHUD.willDisappear, object: self)

        if animated {
            switch animationType {
            case .fade:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in
                    self?.done()
                }
                animator().alphaValue = 0
                NSAnimationContext.endGrouping()

            case .zoom, .zoomIn:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in
                    self?.done()
                }
                animator().alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(0.7, 0.7, 1)
                NSAnimationContext.endGrouping()

            case .zoomOut:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in
                    self?.done()
                }
                animator().alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(1.3, 1.3, 1)
                NSAnimationContext.endGrouping()
            }
        } else {
            alphaValue = 0
            done()
        }
    }

    private func done() {
        isFinished = true
        progressIndicatorLayer?.stopProgressAnimation()
        graceTimer?.invalidate()
        hideDelayTimer?.invalidate()
        progressObservation?.invalidate()

        if removeFromSuperViewOnHide {
            removeFromSuperview()
        } else {
            isHidden = true
        }

        completionBlock?()
        delegate?.hudWasHidden(self)
        NotificationCenter.default.post(name: ProgressHUD.didDisappear, object: self)
    }

    // MARK: - Setup

    private func setupViews() {
        autoresizingMask = [.maxXMargin, .minXMargin, .maxYMargin, .minYMargin]
        alphaValue = 0
        isHidden = true
        wantsLayer = true

        // Background
        backgroundView = NSView(frame: bounds)
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)

        // Bezel
        bezelView = NSView()
        bezelView.wantsLayer = true
        bezelView.layer?.cornerRadius = cornerRadius
        bezelView.layer?.masksToBounds = true
        updateBezelAppearance()
        addSubview(bezelView)

        // Label
        label = NSTextField(frame: .zero)
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.alignment = .center
        label.backgroundColor = .clear
        label.drawsBackground = false
        label.font = NSFont.systemFont(ofSize: 14)
        label.textColor = contentColor ?? .white
        label.maximumNumberOfLines = 0
        label.cell?.wraps = true
        bezelView.addSubview(label)

        // Details label
        detailsLabel = NSTextField(frame: .zero)
        detailsLabel.isEditable = false
        detailsLabel.isSelectable = false
        detailsLabel.isBordered = false
        detailsLabel.alignment = .center
        detailsLabel.backgroundColor = .clear
        detailsLabel.drawsBackground = false
        detailsLabel.font = NSFont.systemFont(ofSize: 12)
        detailsLabel.textColor = contentColor ?? .white
        detailsLabel.maximumNumberOfLines = 0
        detailsLabel.cell?.wraps = true
        bezelView.addSubview(detailsLabel)

        // Button
        button = NSButton(frame: .zero)
        button.isBordered = true
        button.bezelStyle = .rounded
        button.isHidden = true
        bezelView.addSubview(button)
    }

    private func updateBezelStyle() {
        // For .blur, we'd replace bezelView with NSVisualEffectView
        // Keeping it simple for now — solid color covers most use cases
        updateBezelAppearance()
    }

    private func updateBezelAppearance() {
        bezelView.layer?.backgroundColor = bezelColor.cgColor
    }

    // MARK: - Indicators

    private func updateIndicators() {
        progressIndicatorLayer?.stopProgressAnimation()
        progressIndicatorLayer?.removeFromSuperlayer()
        progressIndicatorLayer = nil
        indicator?.removeFromSuperview()
        indicator = nil

        switch mode {
        case .indeterminate:
            let spinner = ProgressIndicatorLayer(size: defaultSpinnerSize, color: contentColor ?? .white)
            spinner.startProgressAnimation()
            progressIndicatorLayer = spinner

            let container = NSView(frame: NSRect(x: 0, y: 0, width: defaultSpinnerSize, height: defaultSpinnerSize))
            container.wantsLayer = true
            container.layer?.addSublayer(spinner)
            indicator = container
            bezelView.addSubview(container)

        case .determinate:
            let roundView = RoundProgressView(frame: NSRect(x: 0, y: 0, width: 37, height: 37))
            roundView.progress = progress
            roundView.progressTintColor = contentColor ?? .white
            indicator = roundView
            bezelView.addSubview(roundView)

        case .annularDeterminate:
            let roundView = RoundProgressView(frame: NSRect(x: 0, y: 0, width: 37, height: 37))
            roundView.isAnnular = true
            roundView.progress = progress
            roundView.progressTintColor = contentColor ?? .white
            indicator = roundView
            bezelView.addSubview(roundView)

        case .determinateHorizontalBar:
            let barView = BarProgressView(frame: NSRect(x: 0, y: 0, width: 120, height: 20))
            barView.progress = progress
            barView.progressColor = contentColor ?? .white
            barView.lineColor = contentColor ?? .white
            indicator = barView
            bezelView.addSubview(barView)

        case .customView:
            if let view = customView {
                indicator = view
                bezelView.addSubview(view)
            }

        case .text:
            break
        }

        needsLayout = true
    }

    private func updateProgress() {
        (indicator as? RoundProgressView)?.progress = progress
        (indicator as? BarProgressView)?.progress = progress
    }

    // MARK: - Layout

    override func layout() {
        super.layout()

        frame = superview?.bounds ?? .zero

        let maxWidth = bounds.width - margin * 4
        var totalSize = CGSize.zero
        let indicatorSize = indicator?.frame.size ?? .zero
        let indicatorHeight = indicatorSize.height > 0 ? indicatorSize.height : (mode == .text ? 0 : defaultSpinnerSize)

        // Calculate label sizes
        let labelFont = label.font ?? NSFont.systemFont(ofSize: 14)
        let detailsFont = detailsLabel.font ?? NSFont.systemFont(ofSize: 12)

        var labelSize: CGSize = .zero
        if !label.stringValue.isEmpty {
            labelSize = (label.stringValue as NSString).boundingRect(
                with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: labelFont]
            ).size
            labelSize.width = min(ceil(labelSize.width) + 10, maxWidth)
            labelSize.height = ceil(labelSize.height)
        }

        var detailsSize: CGSize = .zero
        if !detailsLabel.stringValue.isEmpty {
            detailsSize = (detailsLabel.stringValue as NSString).boundingRect(
                with: NSSize(width: maxWidth, height: .greatestFiniteMagnitude),
                options: [.usesLineFragmentOrigin],
                attributes: [.font: detailsFont]
            ).size
            detailsSize.width = min(ceil(detailsSize.width) + 10, maxWidth)
            detailsSize.height = ceil(detailsSize.height)
        }

        // Calculate total size
        totalSize.width = max(indicatorHeight, labelSize.width, detailsSize.width)
        totalSize.height = indicatorHeight
        if indicatorHeight > 0 && labelSize.height > 0 { totalSize.height += 4 }
        totalSize.height += labelSize.height
        if labelSize.height > 0 && detailsSize.height > 0 { totalSize.height += 4 }
        totalSize.height += detailsSize.height
        totalSize.width += margin * 2
        totalSize.height += margin * 2

        // Apply minSize
        totalSize.width = max(totalSize.width, minSize.width)
        totalSize.height = max(totalSize.height, minSize.height)

        // Apply isSquare
        if isSquare {
            let maxSide = max(totalSize.width, totalSize.height)
            totalSize = CGSize(width: maxSide, height: maxSide)
        }

        // Position bezel
        let bezelX = round((bounds.width - totalSize.width) / 2) + offset.x
        let bezelY = round((bounds.height - totalSize.height) / 2) + offset.y
        bezelView.frame = CGRect(origin: CGPoint(x: bezelX, y: bezelY), size: totalSize)

        // Position indicator
        var y = totalSize.height - margin - indicatorHeight
        if let ind = indicator {
            ind.frame = CGRect(x: round((totalSize.width - ind.frame.width) / 2), y: y, width: ind.frame.width, height: indicatorHeight)
            if indicatorHeight > 0 { y -= 4 }
        } else if indicatorHeight > 0 {
            y -= 4
        }

        // Position label
        if labelSize.height > 0 {
            y -= labelSize.height
            label.frame = CGRect(x: round((totalSize.width - labelSize.width) / 2), y: y, width: labelSize.width, height: labelSize.height)
            if detailsSize.height > 0 { y -= 4 }
        }

        // Position details label
        if detailsSize.height > 0 {
            y -= detailsSize.height
            detailsLabel.frame = CGRect(x: round((totalSize.width - detailsSize.width) / 2), y: y, width: detailsSize.width, height: detailsSize.height)
        }

        // Position button (if visible)
        if !button.isHidden {
            let buttonSize = button.intrinsicContentSize
            let buttonY = margin
            button.frame = CGRect(x: round((totalSize.width - buttonSize.width) / 2), y: buttonY, width: buttonSize.width, height: buttonSize.height)
        }
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {
        NotificationCenter.default.post(name: ProgressHUD.didReceiveMouseDownEvent, object: self)
    }

    // MARK: - Notifications

    static let didReceiveMouseDownEvent = NSNotification.Name("ProgressHUD.didReceiveMouseDownEvent")
    static let willAppear = NSNotification.Name("ProgressHUD.willAppear")
    static let didAppear = NSNotification.Name("ProgressHUD.didAppear")
    static let willDisappear = NSNotification.Name("ProgressHUD.willDisappear")
    static let didDisappear = NSNotification.Name("ProgressHUD.didDisappear")
}
