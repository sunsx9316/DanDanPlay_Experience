//
//  VolumeControlView.swift
//  Runner
//
//  Created by jimhuang on 2020/12/20.
//

import UIKit
import MediaPlayer

class VolumeControlView: SliderControlView {
    
    override init(image: UIImage?) {
        super.init(image: image)
        
        let view = UIView()
        view.clipsToBounds = true
        view.addSubview(self.volumeView)
        self.insertSubview(view, belowSubview: self.bgView)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override var progress: CGFloat {
        didSet {
            self.volumeSilder?.value = Float(self.progress)
        }
    }
    
    private lazy var volumeView: MPVolumeView = {
        return MPVolumeView()
    }()
    
    private lazy var volumeSilder: UISlider? = {
        let view = self.volumeView
        if let systemClass = NSClassFromString("MPVolumeSlider") {
            return view.subviews.first(where: { $0.isMember(of: systemClass) }) as? UISlider
        }
        return nil
    }()
    
}
