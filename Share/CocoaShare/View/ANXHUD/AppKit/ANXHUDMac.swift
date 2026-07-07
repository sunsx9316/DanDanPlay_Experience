//
//  ANXHUDMac.swift
//  AniXPlayer
//
//  Mac 版 HUD，SnapKit + NSStackView 自动布局
//

#if os(macOS)

import AppKit
import SnapKit

// MARK: - ANXHUD

protocol ANXHUDDelegate: AnyObject {
    func hudWasHidden(_ hud: ANXHUD)
}

class ANXHUD: NSView {

    // MARK: Mode

    enum Mode: Int {
        case indeterminate
        case determinate
        case determinateHorizontalBar
        case annularDeterminate
        case customView
        case text
    }

    // MARK: Animation

    enum Animation: Int {
        case fade
        case zoom
        case zoomOut
        case zoomIn
    }

    // MARK: Class Methods

    @discardableResult
    class func showAdded(to view: NSView, animated: Bool) -> ANXHUD {
        let hud = ANXHUD(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }

    @discardableResult
    class func hide(for view: NSView, animated: Bool) -> Bool {
        guard let hud = forView(view) else { return false }
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: animated)
        return true
    }

    class func forView(_ view: NSView) -> ANXHUD? {
        for subview in view.subviews.reversed() {
            if let hud = subview as? ANXHUD, !hud.isFinished {
                return hud
            }
        }
        return nil
    }

    // MARK: Lifecycle

    init(view: NSView) {
        super.init(frame: view.bounds)
        commonInit()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    private func commonInit() {
        animationType = .fade
        mode = .indeterminate
        margin = 20
        alphaValue = 0
        isHidden = true
        wantsLayer = true
        autoresizingMask = [.width, .height]

        setupViews()

        contentColor = .white
        bezelView.layer?.backgroundColor = NSColor.black.withAlphaComponent(0.6).cgColor
        updateIndicators()
    }

    // MARK: - Show & Hide

    func show(animated: Bool) {
        useAnimation = animated
        isFinished = false

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

    // MARK: - Public Properties

    weak var delegate: ANXHUDDelegate?
    var completionBlock: (() -> Void)?

    var graceTime: TimeInterval = 0
    var minShowTime: TimeInterval = 0
    var removeFromSuperViewOnHide: Bool = false

    var mode: Mode = .indeterminate {
        didSet {
            if mode != oldValue { updateIndicators() }
        }
    }

    var contentColor: NSColor? {
        didSet { updateViewsForColor(contentColor) }
    }

    var animationType: Animation = .fade
    var offset: CGPoint = .zero { didSet { needsUpdateConstraints = true } }
    var margin: CGFloat = 20 { didSet { needsUpdateConstraints = true } }
    var minSize: CGSize = .zero { didSet { needsUpdateConstraints = true } }
    var isSquare: Bool = false { didSet { needsUpdateConstraints = true } }

    var bezelColor: NSColor = NSColor.black.withAlphaComponent(0.6) {
        didSet { bezelView.layer?.backgroundColor = bezelColor.cgColor }
    }

    var progress: Float = 0 {
        didSet { updateProgress() }
    }

    var progressObject: Progress? {
        didSet {
            progressObservation?.invalidate()
            progressObservation = nil
            guard progressObject != nil else { return }
            progressObservation = progressObject?.observe(\.fractionCompleted, options: [.new]) { [weak self] _, change in
                guard let self = self, let value = change.newValue else { return }
                self.progress = Float(value)
            }
        }
    }

    // MARK: Views

    private(set) lazy var backgroundView: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.alphaValue = 0
        return v
    }()

    private(set) lazy var bezelView: NSView = {
        let v = NSView()
        v.wantsLayer = true
        v.layer?.cornerRadius = 5
        v.layer?.masksToBounds = true
        v.alphaValue = 0
        return v
    }()

    private(set) lazy var label: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.font = NSFont.systemFont(ofSize: 14, weight: .bold)
        tf.maximumNumberOfLines = 0
        return tf
    }()

    private(set) lazy var detailsLabel: NSTextField = {
        let tf = NSTextField(labelWithString: "")
        tf.alignment = .center
        tf.font = NSFont.systemFont(ofSize: 12)
        tf.maximumNumberOfLines = 0
        tf.isHidden = true
        return tf
    }()

    private(set) lazy var button: NSButton = {
        let btn = NSButton(title: "", target: nil, action: nil)
        btn.isBordered = true
        btn.bezelStyle = .rounded
        btn.isHidden = true
        return btn
    }()

    var customView: NSView? {
        didSet {
            if customView !== oldValue, mode == .customView {
                updateIndicators()
            }
        }
    }

    // MARK: Convenience

    var labelText: String? {
        get { label.stringValue.isEmpty ? nil : label.stringValue }
        set {
            label.stringValue = newValue ?? ""
            label.isHidden = (newValue == nil || newValue?.isEmpty == true)
        }
    }

    var detailsLabelText: String? {
        get { detailsLabel.stringValue.isEmpty ? nil : detailsLabel.stringValue }
        set {
            detailsLabel.stringValue = newValue ?? ""
            detailsLabel.isHidden = (newValue == nil || newValue?.isEmpty == true)
        }
    }

    // MARK: - Private

    private var indicator: NSView?
    private var progressIndicatorLayer: ANXHUDProgressIndicatorLayer?
    private var useAnimation: Bool = true
    private var isFinished: Bool = false
    private var showStarted: Date?
    private var graceTimer: Timer?
    private var hideDelayTimer: Timer?
    private var progressObservation: NSKeyValueObservation?
    private let defaultSpinnerSize: CGFloat = 60

    private lazy var contentStack: NSStackView = {
        let stack = NSStackView(views: [label, detailsLabel, button])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 0
        return stack
    }()

    // MARK: - Setup

    private func setupViews() {
        backgroundView.frame = bounds
        backgroundView.autoresizingMask = [.width, .height]
        addSubview(backgroundView)
        addSubview(bezelView)
        bezelView.addSubview(contentStack)
    }

    // MARK: - Update Indicators

    private func updateIndicators() {
        progressIndicatorLayer?.stopProgressAnimation()
        progressIndicatorLayer?.removeFromSuperlayer()
        progressIndicatorLayer = nil
        indicator?.removeFromSuperview()
        indicator = nil

        switch mode {
        case .indeterminate:
            let spinner = ANXHUDProgressIndicatorLayer(size: defaultSpinnerSize, color: contentColor ?? .white)
            spinner.startProgressAnimation()
            progressIndicatorLayer = spinner

            let container = NSView()
            container.wantsLayer = true
            container.layer?.addSublayer(spinner)
            container.snp.makeConstraints { make in
                make.width.height.equalTo(defaultSpinnerSize)
            }
            indicator = container
            contentStack.insertArrangedSubview(container, at: 0)
            contentStack.setCustomSpacing(4, after: container)

        case .determinate:
            let round = ANXHUDRoundProgressView()
            round.progress = progress
            round.progressTintColor = contentColor ?? .white
            indicator = round
            contentStack.insertArrangedSubview(round, at: 0)
            contentStack.setCustomSpacing(4, after: round)

        case .annularDeterminate:
            let round = ANXHUDRoundProgressView()
            round.isAnnular = true
            round.progress = progress
            round.progressTintColor = contentColor ?? .white
            indicator = round
            contentStack.insertArrangedSubview(round, at: 0)
            contentStack.setCustomSpacing(4, after: round)

        case .determinateHorizontalBar:
            let bar = ANXHUDBarProgressView()
            bar.progress = progress
            bar.progressColor = contentColor ?? .white
            bar.lineColor = contentColor ?? .white
            bar.snp.makeConstraints { make in
                make.width.equalTo(120)
            }
            indicator = bar
            contentStack.insertArrangedSubview(bar, at: 0)
            contentStack.setCustomSpacing(4, after: bar)

        case .customView:
            if let cv = customView {
                indicator = cv
                contentStack.insertArrangedSubview(cv, at: 0)
                contentStack.setCustomSpacing(4, after: cv)
            }

        case .text:
            break
        }

        updateViewsForColor(contentColor)
        needsUpdateConstraints = true
    }

    private func updateProgress() {
        (indicator as? ANXHUDRoundProgressView)?.progress = progress
        (indicator as? ANXHUDBarProgressView)?.progress = progress
    }

    private func updateViewsForColor(_ color: NSColor?) {
        guard let color = color else { return }
        label.textColor = color
        detailsLabel.textColor = color
        progressIndicatorLayer?.color = color

        if let round = indicator as? ANXHUDRoundProgressView {
            round.progressTintColor = color
        } else if let bar = indicator as? ANXHUDBarProgressView {
            bar.progressColor = color
            bar.lineColor = color
        }
    }

    // MARK: - Layout

    override func updateConstraints() {
        let bezel = bezelView
        let m = margin

        [bezel, contentStack].forEach { $0.snp.removeConstraints() }

        bezel.snp.makeConstraints { make in
            make.centerX.equalToSuperview().offset(offset.x)
            make.centerY.equalToSuperview().offset(offset.y)
            make.leading.greaterThanOrEqualToSuperview().offset(m)
            make.trailing.lessThanOrEqualToSuperview().offset(-m)
            make.top.greaterThanOrEqualToSuperview().offset(m)
            make.bottom.lessThanOrEqualToSuperview().offset(-m)

            if minSize.width > 0 {
                make.width.greaterThanOrEqualTo(minSize.width)
            }
            if minSize.height > 0 {
                make.height.greaterThanOrEqualTo(minSize.height)
            }
            if isSquare {
                make.height.equalTo(bezel.snp.width)
            }
        }

        contentStack.snp.makeConstraints { make in
            make.edges.equalTo(bezel).inset(m)
        }

        super.updateConstraints()
    }

    // MARK: - Show / Hide Internals

    private func performShow(animated: Bool) {
        guard !isFinished else { return }

        isHidden = false
        updateIndicators()

        if animated {
            switch animationType {
            case .fade:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                animator().alphaValue = 1.0
                bezelView.animator().alphaValue = 1.0
                backgroundView.animator().alphaValue = 1.0
                NSAnimationContext.endGrouping()

            case .zoom, .zoomIn:
                alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(1.3, 1.3, 1)
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                animator().alphaValue = 1.0
                bezelView.animator().alphaValue = 1.0
                backgroundView.animator().alphaValue = 1.0
                bezelView.layer?.transform = CATransform3DIdentity
                NSAnimationContext.endGrouping()

            case .zoomOut:
                alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(0.7, 0.7, 1)
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                animator().alphaValue = 1.0
                bezelView.animator().alphaValue = 1.0
                backgroundView.animator().alphaValue = 1.0
                bezelView.layer?.transform = CATransform3DIdentity
                NSAnimationContext.endGrouping()
            }
        } else {
            alphaValue = 1.0
            bezelView.alphaValue = 1.0
            backgroundView.alphaValue = 1.0
        }
    }

    private func performHide(animated: Bool) {
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

        if animated {
            switch animationType {
            case .fade:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in self?.done() }
                animator().alphaValue = 0
                bezelView.animator().alphaValue = 0
                backgroundView.animator().alphaValue = 0
                NSAnimationContext.endGrouping()

            case .zoom, .zoomIn:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in self?.done() }
                animator().alphaValue = 0
                bezelView.animator().alphaValue = 0
                backgroundView.animator().alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(0.7, 0.7, 1)
                NSAnimationContext.endGrouping()

            case .zoomOut:
                NSAnimationContext.beginGrouping()
                NSAnimationContext.current.duration = 0.2
                NSAnimationContext.current.completionHandler = { [weak self] in self?.done() }
                animator().alphaValue = 0
                bezelView.animator().alphaValue = 0
                backgroundView.animator().alphaValue = 0
                bezelView.layer?.transform = CATransform3DMakeScale(1.3, 1.3, 1)
                NSAnimationContext.endGrouping()
            }
        } else {
            alphaValue = 0
            bezelView.alphaValue = 0
            backgroundView.alphaValue = 0
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
    }

    // MARK: - Mouse Events

    override func mouseDown(with event: NSEvent) {}
}

#endif
