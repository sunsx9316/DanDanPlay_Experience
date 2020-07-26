//
//  PlayerControlAnimater.swift
//  Runner
//
//  Created by JimHuang on 2020/7/26.
//

import UIKit

typealias PlayerControlFinishAnimateAction = ((Bool) -> Void)

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
            let width = containerView.frame.width * 0.5
            toVC.view.frame = CGRect(x: containerView.frame.width, y: 0, width: width, height: containerView.frame.height)
            UIView.animate(withDuration: self.transitionDuration(using: transitionContext), delay: 0, usingSpringWithDamping: 1, initialSpringVelocity: 9, options: .curveEaseInOut, animations: {
                toVC.view.frame.origin.x = containerView.frame.width - width
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
                fromVC.view.frame.origin.x = containerView.frame.width
            }) { (finished) in
                transitionContext.completeTransition(finished)
                self.didFinishAnimateCallBack?(finished)
            }
        }
    }
    
}


