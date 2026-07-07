//
//  ANXHUD.swift
//  AniXPlayer
//
//  UIKit 版 HUD（iOS + tvOS），API 对齐 MBProgressHUD
//

#if os(iOS) || os(tvOS)

import UIKit
import SnapKit

// MARK: - Constants

let ANXHUDMaxOffset: CGFloat = 1_000_000

private let defaultPadding: CGFloat = 4
private let defaultLabelFontSize: CGFloat = 16
private let defaultDetailsLabelFontSize: CGFloat = 12

// MARK: - ANXHUD

protocol ANXHUDDelegate: AnyObject {
    func hudWasHidden(_ hud: ANXHUD)
}

class ANXHUD: UIView {

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

    // MARK: BackgroundStyle

    enum BackgroundStyle: Int {
        case solidColor
        case blur
    }

    // MARK: Class Methods

    @discardableResult
    class func showAdded(to view: UIView, animated: Bool) -> ANXHUD {
        let hud = ANXHUD(view: view)
        hud.removeFromSuperViewOnHide = true
        view.addSubview(hud)
        hud.show(animated: animated)
        return hud
    }

    @discardableResult
    class func hide(for view: UIView, animated: Bool) -> Bool {
        guard let hud = forView(view) else { return false }
        hud.removeFromSuperViewOnHide = true
        hud.hide(animated: animated)
        return true
    }

    class func forView(_ view: UIView) -> ANXHUD? {
        for subview in view.subviews.reversed() {
            if let hud = subview as? ANXHUD, !hud.isFinished {
                return hud
            }
        }
        return nil
    }

    // MARK: Lifecycle

    init(view: UIView) {
        super.init(frame: view.bounds)
        commonInit()
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        commonInit()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        commonInit()
    }

    private func commonInit() {
        animationType = .fade
        mode = .indeterminate
        margin = 20
        isOpaque = false
        backgroundColor = .clear
        alpha = 0
        autoresizingMask = [.flexibleWidth, .flexibleHeight]
        layer.allowsGroupOpacity = false

        setupViews()

        contentColor = .white
        bezelView.backgroundColor = UIColor(white: 0, alpha: 0.7)
        updateIndicators()
    }

    // MARK: - Show & Hide

    func show(animated: Bool) {
        minShowTimer?.invalidate()
        useAnimation = animated
        isFinished = false

        if graceTime > 0 {
            let timer = Timer(timeInterval: graceTime, target: self, selector: #selector(handleGraceTimer(_:)), userInfo: nil, repeats: false)
            RunLoop.current.add(timer, forMode: .common)
            graceTimer = timer
        } else {
            showUsingAnimation(useAnimation)
        }
    }

    func hide(animated: Bool) {
        graceTimer?.invalidate()
        useAnimation = animated
        isFinished = true

        if minShowTime > 0, let showStarted = showStarted {
            let interval = Date().timeIntervalSince(showStarted)
            if interval < minShowTime {
                let timer = Timer(timeInterval: minShowTime - interval, target: self, selector: #selector(handleMinShowTimer(_:)), userInfo: nil, repeats: false)
                RunLoop.current.add(timer, forMode: .common)
                minShowTimer = timer
                return
            }
        }
        hideUsingAnimation(useAnimation)
    }

    func hide(animated: Bool, afterDelay delay: TimeInterval) {
        hideDelayTimer?.invalidate()
        let timer = Timer(timeInterval: delay, target: self, selector: #selector(handleHideTimer(_:)), userInfo: animated, repeats: false)
        RunLoop.current.add(timer, forMode: .common)
        hideDelayTimer = timer
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

    var contentColor: UIColor? {
        didSet { updateViewsForColor(contentColor) }
    }

    var animationType: Animation = .fade
    var offset: CGPoint = .zero { didSet { setNeedsUpdateConstraints() } }
    var margin: CGFloat = 20 { didSet { setNeedsUpdateConstraints() } }
    var minSize: CGSize = .zero { didSet { setNeedsUpdateConstraints() } }
    var isSquare: Bool = false { didSet { setNeedsUpdateConstraints() } }

    var bezelStyle: BackgroundStyle = .solidColor {
        didSet {
            bezelView.style = bezelStyle
            backgroundView.style = bezelStyle
        }
    }

    var progress: Float = 0 {
        didSet { updateProgress() }
    }

    var progressObject: Progress? {
        didSet {
            progressObjectDisplayLink?.invalidate()
            progressObjectDisplayLink = nil
            guard progressObject != nil else { return }
            let link = CADisplayLink(target: self, selector: #selector(updateProgressFromProgressObject))
            link.add(to: .main, forMode: .default)
            progressObjectDisplayLink = link
        }
    }

    var customView: UIView? {
        didSet {
            if customView !== oldValue, mode == .customView {
                updateIndicators()
            }
        }
    }

    // MARK: Views

    private(set) lazy var backgroundView: BackgroundView = {
        let v = BackgroundView(frame: bounds)
        v.style = .solidColor
        v.backgroundColor = .clear
        v.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        v.alpha = 0
        return v
    }()

    private(set) lazy var bezelView: BackgroundView = {
        let v = BackgroundView()
        v.layer.cornerRadius = 5
        v.alpha = 0
        return v
    }()

    private(set) lazy var label: UILabel = {
        let lbl = UILabel()
        lbl.textAlignment = .center
        lbl.font = UIFont.boldSystemFont(ofSize: defaultLabelFontSize)
        lbl.numberOfLines = 0
        lbl.isOpaque = false
        lbl.backgroundColor = .clear
        return lbl
    }()

    private(set) lazy var detailsLabel: UILabel = {
        let detail = UILabel()
        detail.textAlignment = .center
        detail.numberOfLines = 0
        detail.font = UIFont.boldSystemFont(ofSize: defaultDetailsLabelFontSize)
        detail.isOpaque = false
        detail.backgroundColor = .clear
        return detail
    }()

    private(set) lazy var button: UIButton = {
        let btn = UIButton(type: .custom)
        btn.titleLabel?.textAlignment = .center
        btn.titleLabel?.font = .systemFont(ofSize: defaultDetailsLabelFontSize)
        btn.isHidden = true
        return btn
    }()

    // MARK: Convenience

    var labelText: String? {
        get { label.text }
        set {
            label.text = newValue
            label.isHidden = (newValue == nil || newValue?.isEmpty == true)
        }
    }

    var detailsLabelText: String? {
        get { detailsLabel.text }
        set {
            detailsLabel.text = newValue
            detailsLabel.isHidden = (newValue == nil || newValue?.isEmpty == true)
        }
    }

    // MARK: Private

    private var useAnimation: Bool = true
    private var isFinished: Bool = false
    private var indicator: UIView?
    private var showStarted: Date?

    private lazy var contentStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [label, detailsLabel, button])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 0
        return stack
    }()

    private weak var graceTimer: Timer?
    private weak var minShowTimer: Timer?
    private weak var hideDelayTimer: Timer?
    private var progressObjectDisplayLink: CADisplayLink?

    // MARK: - Setup

    private func setupViews() {
        addSubview(backgroundView)
        addSubview(bezelView)
        bezelView.addSubview(contentStack)
    }

    // MARK: - Update Indicators

    private func updateIndicators() {
        let oldIndicator = indicator
        let isActivityIndicator = oldIndicator is UIActivityIndicatorView
        let isRoundIndicator = oldIndicator is ANXHUDRoundProgressView

        switch mode {
        case .indeterminate:
            if !isActivityIndicator {
                oldIndicator?.removeFromSuperview()
                let spinner = UIActivityIndicatorView(style: .large)
                spinner.color = .white
                spinner.startAnimating()
                indicator = spinner
                contentStack.insertArrangedSubview(spinner, at: 0)
                contentStack.setCustomSpacing(defaultPadding, after: spinner)
            }
        case .determinateHorizontalBar:
            oldIndicator?.removeFromSuperview()
            let bar = ANXHUDBarProgressView()
            bar.progress = progress
            indicator = bar
            contentStack.insertArrangedSubview(bar, at: 0)
            contentStack.setCustomSpacing(defaultPadding, after: bar)
        case .determinate, .annularDeterminate:
            if !isRoundIndicator {
                oldIndicator?.removeFromSuperview()
                let round = ANXHUDRoundProgressView()
                indicator = round
                contentStack.insertArrangedSubview(round, at: 0)
                contentStack.setCustomSpacing(defaultPadding, after: round)
            }
            (indicator as? ANXHUDRoundProgressView)?.isAnnular = (mode == .annularDeterminate)
        case .customView:
            if let cv = customView, cv !== oldIndicator {
                oldIndicator?.removeFromSuperview()
                indicator = cv
                contentStack.insertArrangedSubview(cv, at: 0)
                contentStack.setCustomSpacing(defaultPadding, after: cv)
            } else if customView == nil {
                oldIndicator?.removeFromSuperview()
                indicator = nil
            }
        case .text:
            oldIndicator?.removeFromSuperview()
            indicator = nil
        }

        updateViewsForColor(contentColor)
        setNeedsUpdateConstraints()
    }

    private func updateProgress() {
        (indicator as? ANXHUDRoundProgressView)?.progress = progress
        (indicator as? ANXHUDBarProgressView)?.progress = progress
    }

    @objc private func updateProgressFromProgressObject() {
        if let obj = progressObject {
            progress = Float(obj.fractionCompleted)
        }
    }

    private func updateViewsForColor(_ color: UIColor?) {
        guard let color = color else { return }
        label.textColor = color
        detailsLabel.textColor = color
        button.setTitleColor(color, for: .normal)

        if let spinner = indicator as? UIActivityIndicatorView {
            spinner.color = color
        } else if let round = indicator as? ANXHUDRoundProgressView {
            round.progressTintColor = color
            round.backgroundTintColor = color.withAlphaComponent(0.1)
        } else if let bar = indicator as? ANXHUDBarProgressView {
            bar.progressColor = color
            bar.lineColor = color
        } else {
            indicator?.tintColor = color
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

    // MARK: - Show & Hide Internals

    private func showUsingAnimation(_ animated: Bool) {
        bezelView.layer.removeAllAnimations()
        backgroundView.layer.removeAllAnimations()
        hideDelayTimer?.invalidate()

        showStarted = Date()
        alpha = 1
        progressObjectDisplayLink?.isPaused = false

        if animated {
            animateIn(true, type: animationType, completion: nil)
        } else {
            bezelView.alpha = 1
            backgroundView.alpha = 1
        }
    }

    private func hideUsingAnimation(_ animated: Bool) {
        hideDelayTimer?.invalidate()

        if animated, showStarted != nil {
            showStarted = nil
            animateIn(false, type: animationType) { [weak self] _ in
                self?.done()
            }
        } else {
            showStarted = nil
            bezelView.alpha = 0
            backgroundView.alpha = 1
            done()
        }
    }

    private func animateIn(_ animatingIn: Bool, type: Animation, completion: ((Bool) -> Void)?) {
        var animType = type
        if animType == .zoom {
            animType = animatingIn ? .zoomIn : .zoomOut
        }

        let small = CGAffineTransform(scaleX: 0.5, y: 0.5)
        let large = CGAffineTransform(scaleX: 1.5, y: 1.5)

        if animatingIn, bezelView.alpha == 0 {
            bezelView.transform = (animType == .zoomIn) ? small : large
        }

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 0, options: .beginFromCurrentState, animations: {
            if animatingIn {
                self.bezelView.transform = .identity
            } else {
                self.bezelView.transform = (animType == .zoomIn) ? large : small
            }
            let alpha: CGFloat = animatingIn ? 1 : 0
            self.bezelView.alpha = alpha
            self.backgroundView.alpha = alpha
        }, completion: completion)
    }

    private func done() {
        progressObjectDisplayLink?.invalidate()
        progressObjectDisplayLink = nil

        if isFinished {
            alpha = 0
            if removeFromSuperViewOnHide {
                removeFromSuperview()
            }
        }
        completionBlock?()
        delegate?.hudWasHidden(self)
    }

    // MARK: - Timer Callbacks

    @objc private func handleGraceTimer(_ timer: Timer) {
        if !isFinished {
            showUsingAnimation(useAnimation)
        }
    }

    @objc private func handleMinShowTimer(_ timer: Timer) {
        hideUsingAnimation(useAnimation)
    }

    @objc private func handleHideTimer(_ timer: Timer) {
        hide(animated: (timer.userInfo as? Bool) ?? true)
    }
}

// MARK: - BackgroundView

extension ANXHUD {

    class BackgroundView: UIView {

        var style: BackgroundStyle = .solidColor {
            didSet { updateStyle() }
        }

        /// 兼容旧 API，等价于 backgroundColor
        var color: UIColor? {
            get { backgroundColor }
            set { backgroundColor = newValue }
        }

        private var effectView: UIVisualEffectView?

        override init(frame: CGRect) {
            super.init(frame: frame)
            clipsToBounds = true
        }

        required init?(coder: NSCoder) {
            super.init(coder: coder)
            clipsToBounds = true
        }

        private func updateStyle() {
            effectView?.removeFromSuperview()
            effectView = nil

            switch style {
            case .solidColor:
                break
            case .blur:
                let effect = UIBlurEffect(style: .dark)
                let ev = UIVisualEffectView(effect: effect)
                ev.frame = bounds
                ev.autoresizingMask = [.flexibleWidth, .flexibleHeight]
                insertSubview(ev, at: 0)
                effectView = ev
                super.backgroundColor = .clear
            }
        }
    }
}

#endif
