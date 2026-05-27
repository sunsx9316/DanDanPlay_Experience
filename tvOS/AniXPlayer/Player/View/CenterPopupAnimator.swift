//
//  CenterPopupAnimator.swift
//  AniXPlayer
//
//  tvOS 居中弹窗动画 — 居中放大弹出 + 半透明遮罩
//

import UIKit

class CenterPopupAnimator: NSObject, UIViewControllerTransitioningDelegate {

    func presentationController(forPresented presented: UIViewController,
                                presenting: UIViewController?,
                                source: UIViewController) -> UIPresentationController? {
        return CenterPopupPresentationController(presentedViewController: presented, presenting: presenting)
    }

    func animationController(forPresented presented: UIViewController,
                             presenting: UIViewController,
                             source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CenterPopupPresentAnimate()
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return CenterPopupDismissAnimate()
    }
}

// MARK: - Presentation Controller

class CenterPopupPresentationController: UIPresentationController {

    private lazy var dimmingView: UIView = {
        let view = UIView()
        view.backgroundColor = .clear
        view.alpha = 0
        return view
    }()

    override var frameOfPresentedViewInContainerView: CGRect {
        guard let containerView = containerView else { return .zero }
        let size: CGFloat = 400
        return CGRect(
            x: (containerView.bounds.width - size) / 2,
            y: (containerView.bounds.height - size) / 2,
            width: size,
            height: 220
        )
    }

    override func presentationTransitionWillBegin() {
        guard let containerView = containerView else { return }
        dimmingView.frame = containerView.bounds
        containerView.insertSubview(dimmingView, at: 0)

        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 1
        })
    }

    override func dismissalTransitionWillBegin() {
        presentedViewController.transitionCoordinator?.animate(alongsideTransition: { _ in
            self.dimmingView.alpha = 0
        })
    }

    override func containerViewDidLayoutSubviews() {
        super.containerViewDidLayoutSubviews()
        dimmingView.frame = containerView?.bounds ?? .zero
        presentedView?.frame = frameOfPresentedViewInContainerView
    }
}

// MARK: - Present Animation

class CenterPopupPresentAnimate: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.3
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let toView = transitionContext.view(forKey: .to) else { return }

        let containerView = transitionContext.containerView
        let finalFrame = transitionContext.finalFrame(for: transitionContext.viewController(forKey: .to)!)

        toView.frame = finalFrame
        toView.transform = CGAffineTransform(scaleX: 0.8, y: 0.8)
        toView.alpha = 0

        containerView.addSubview(toView)

        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       usingSpringWithDamping: 0.8,
                       initialSpringVelocity: 0,
                       options: .curveEaseOut,
                       animations: {
            toView.transform = .identity
            toView.alpha = 1
        }, completion: { finished in
            transitionContext.completeTransition(finished)
        })
    }
}

// MARK: - Dismiss Animation

class CenterPopupDismissAnimate: NSObject, UIViewControllerAnimatedTransitioning {

    func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
        return 0.2
    }

    func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
        guard let fromView = transitionContext.view(forKey: .from) else { return }

        UIView.animate(withDuration: transitionDuration(using: transitionContext),
                       delay: 0,
                       options: .curveEaseIn,
                       animations: {
            fromView.alpha = 0
            fromView.transform = CGAffineTransform(scaleX: 0.9, y: 0.9)
        }, completion: { finished in
            transitionContext.completeTransition(finished)
        })
    }
}