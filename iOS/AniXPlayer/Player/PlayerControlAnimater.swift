//
//  PlayerControlAnimater.swift
//  Runner
//
//  Created by JimHuang on 2020/7/26.
//

import UIKit

typealias PlayerControlFinishAnimateAction = ((Bool) -> Void)

private enum PlayerControlPanelLayout {
    static let widthRatio: CGFloat = 0.5
    static let minWidth: CGFloat = 320
    static let maxWidth: CGFloat = 420
}

class PlayerControlAnimater: NSObject, UIViewControllerTransitioningDelegate {
    var didFinishAnimateCallBack: PlayerControlFinishAnimateAction?
    
    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let anime = DismissAnimate()
        anime.didFinishAnimateCallBack = didFinishAnimateCallBack
        return anime
    }
    
    func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        return ShowAnimate()
    }
}

extension PlayerControlAnimater {
    
    class ShowAnimate: NSObject, UIViewControllerAnimatedTransitioning {
        
        var didFinishAnimateCallBack: PlayerControlFinishAnimateAction?
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.3
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            
            guard let toVC = transitionContext.viewController(forKey: .to) else { return }
            let containerView = transitionContext.containerView
            
            let holdView = UIView(frame: containerView.bounds)
            containerView.addSubview(holdView)
            
            holdView.addGestureRecognizer(UITapGestureRecognizer(actionBlock: { [weak toVC] (sender) in
                guard let toVC = toVC else {
                    return
                }
                
                toVC.dismiss(animated: true, completion: nil)
            }))
            
            containerView.addSubview(toVC.view)
            let containerWidth = containerView.bounds.width
            let width = min(
                max(containerWidth * PlayerControlPanelLayout.widthRatio, PlayerControlPanelLayout.minWidth),
                PlayerControlPanelLayout.maxWidth
            )
            toVC.view.frame = CGRect(x: containerWidth, y: 0, width: width, height: containerView.bounds.height)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 9, options: .curveEaseInOut, animations: {
                toVC.view.frame.origin.x = containerWidth - width
            }) { (finished) in
                transitionContext.completeTransition(finished)
            }
        }
    }
    
    class DismissAnimate: NSObject, UIViewControllerAnimatedTransitioning {
        
        var didFinishAnimateCallBack: PlayerControlFinishAnimateAction?
        
        func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
            return 0.3
        }
        
        func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
            
            guard let fromVC = transitionContext.viewController(forKey: .from) else { return }
            let containerView = transitionContext.containerView
            
            containerView.addSubview(fromVC.view)
            
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 9, options: .curveEaseInOut, animations: {
                fromVC.view.frame.origin.x = containerView.bounds.width
            }) { (finished) in
                transitionContext.completeTransition(finished)
                self.didFinishAnimateCallBack?(finished)
            }
        }
    }
    
}


