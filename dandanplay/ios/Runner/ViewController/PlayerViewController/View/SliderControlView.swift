//
//  SliderControlView.swift
//  Runner
//
//  Created by jimhuang on 2020/12/20.
//

import UIKit

class SliderControlView: UIView {
    
    var dismissCallBack: (() -> Void)?
    
    var progress: CGFloat = 0 {
        didSet {
            self.setNeedsLayout()
        }
    }
    
    private(set) var isShowing = false
    private(set) lazy var bgView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0, alpha: 0.8)
        return view
    }()
    
    private lazy var progressView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 1, alpha: 0.4)
        return view
    }()
    
    private lazy var iconImgView: UIImageView = {
        return UIImageView()
    }()
    
    private var timer: Timer?
    
    deinit {
        self.timer?.invalidate()
    }
    
    init(image: UIImage?) {
        super.init(frame: .zero)
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        self.iconImgView.image = image?.byTintColor(.black)
        
        self.addSubview(self.bgView)
        self.addSubview(self.progressView)
        self.addSubview(self.iconImgView)
        
        self.bgView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.progressView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.iconImgView.snp.makeConstraints { (make) in
            make.bottom.equalTo(-10)
            make.centerX.equalToSuperview()
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        var frame = self.bounds
        frame.origin.y = frame.size.height * (1 - self.progress);
        self.progressView.frame = frame
    }
    
    func showFromView(_ view: UIView) {
        if self.isShowing {
            return
        }
        
        view.addSubview(self)
        self.snp.makeConstraints { (make) in
            make.center.equalToSuperview()
            make.width.equalTo(60)
            make.height.equalTo(120)
        }
        
        self.alpha = 1
        self.isShowing = true
        self.timer?.invalidate()
    }
    
    func dismiss() {
        if !self.isShowing {
            return
        }
        
        self.timer?.invalidate()
        
        UIView.animate(withDuration: 0.2) {
            self.alpha = 0
        } completion: { (finish) in
            if !self.isShowing {
                return
            }
            
            self.isShowing = false
            self.removeFromSuperview()
            self.dismissCallBack?()
        }

    }
    
    func dismissAfter(_ second: TimeInterval) {
        if !self.isShowing {
            return
        }
        
        self.timer?.invalidate()
        self.timer = Timer.scheduledTimer(withTimeInterval: second, block: { [weak self] (_) in
            guard let self = self else { return }
            
            self.dismiss()
        }, repeats: false)
    }
    
}
