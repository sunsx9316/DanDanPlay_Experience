//
//  GotoLastWatchPointViewController.swift
//  AniXPlayer
//
//  tvOS 显示上次播放进度的弹窗 — 居中显示 + 倒计时 + 自动关闭
//

import UIKit
import SnapKit

class GotoLastWatchPointViewController: ViewController {

    // MARK: - Properties

    private var countdownTimer: Timer?
    private var countdownSeconds: Int = 5

    var timeString: String? {
        didSet {
            self.timeLabel.text = self.timeString
        }
    }

    var didClickGotoButton: (() -> Void)?
    var didDismiss: (() -> Void)?

    // MARK: - UI

    private lazy var containerView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var contentView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        view.layer.cornerRadius = 12
        view.layer.masksToBounds = true
        return view
    }()

    private lazy var timeLabel: Label = {
        let label = Label()
        label.textColor = .white
        label.font = .ddp_large()
        label.textAlignment = .center
        return label
    }()

    private lazy var countdownLabel: Label = {
        let label = Label()
        label.textColor = .lightGray
        label.font = .ddp_normal()
        label.textAlignment = .center
        return label
    }()

    private lazy var gotoButton: Button = {
        let button = Button()
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.titleLabel?.font = .ddp_normal()
        button.addTarget(self, action: #selector(onTouchGotoButton), for: .primaryActionTriggered)
        button.setTitle(NSLocalizedString("跳转", comment: ""), for: .normal)
        button.backgroundColor = .mainColor
        return button
    }()

    private lazy var cancelButton: Button = {
        let button = Button()
        button.layer.cornerRadius = 8
        button.layer.masksToBounds = true
        button.titleLabel?.font = .ddp_normal()
        button.addTarget(self, action: #selector(onTouchCancelButton), for: .primaryActionTriggered)
        button.setTitle(NSLocalizedString("取消", comment: ""), for: .normal)
        button.backgroundColor = UIColor(white: 0.3, alpha: 1)
        return button
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        view.backgroundColor = .clear

        view.addSubview(containerView)
        containerView.addSubview(contentView)
        contentView.addSubview(timeLabel)
        contentView.addSubview(countdownLabel)
        contentView.addSubview(gotoButton)
        contentView.addSubview(cancelButton)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(400)
            make.height.equalTo(220)
        }

        contentView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        timeLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(20)
            make.centerX.equalToSuperview()
        }

        countdownLabel.snp.makeConstraints { make in
            make.top.equalTo(timeLabel.snp.bottom).offset(20)
            make.centerX.equalToSuperview()
        }

        gotoButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(20)
            make.bottom.equalToSuperview().offset(-20)
            make.height.equalTo(50)
        }

        cancelButton.snp.makeConstraints { make in
            make.leading.equalTo(gotoButton.snp.trailing).offset(20)
            make.trailing.equalToSuperview().offset(-20)
            make.size.equalTo(gotoButton)
            make.bottom.equalTo(gotoButton)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        startCountdown()
    }

    // MARK: - Countdown

    private func startCountdown() {
        updateCountdownLabel()

        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            self.countdownSeconds -= 1
            self.updateCountdownLabel()

            if self.countdownSeconds <= 0 {
                self.dismiss()
            }
        }
    }

    private func updateCountdownLabel() {
        countdownLabel.text = String(format: NSLocalizedString("%d秒后自动关闭", comment: ""), countdownSeconds)
    }

    func dismiss() {
        countdownTimer?.invalidate()
        countdownTimer = nil

        dismiss(animated: true)
    }

    // MARK: - Actions

    @objc private func onTouchGotoButton() {
        didClickGotoButton?()
        dismiss()
    }

    @objc private func onTouchCancelButton() {
        dismiss()
    }
}

// MARK: - GotoLastWatchPointViewController (PopTransition)

class GotoLastWatchPointAnimator: NSObject, UIViewControllerTransitioningDelegate, UIViewControllerAnimatedTransitioning {

    var isPresenting = true

    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = true
        return self
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        isPresenting = false
        return self
    }

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        if isPresenting {
            animatePresentation(transitionContext: transitionContext)
        } else {
            animateDismissal(transitionContext: transitionContext)
        }
    }

    private func animatePresentation(transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to),
              let _ = transitionContext.viewController(forKey: .to) else {
            transitionContext.completeTransition(false)
            return
        }

        toView.frame = transitionContext.containerView.bounds
        toView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        toView.alpha = 0

        transitionContext.containerView.addSubview(toView)

        UIView.animate(withDuration: 0.3, delay: 0, usingSpringWithDamping: 0.8, initialSpringVelocity: 0) {
            toView.transform = .identity
            toView.alpha = 1
        } completion: { _ in
            transitionContext.completeTransition(true)
        }
    }

    private func animateDismissal(transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from) else {
            transitionContext.completeTransition(false)
            return
        }

        UIView.animate(withDuration: 0.2) {
            fromView.alpha = 0
        } completion: { _ in
            fromView.removeFromSuperview()
            transitionContext.completeTransition(true)
        }
    }
}
