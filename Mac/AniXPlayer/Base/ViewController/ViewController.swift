//
//  ViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa

class ViewController: NSViewController {
    
    init() {
        let nibName = "\(type(of: self).self)"
        let bundle = Bundle(for: type(of: self))
        super.init(nibName: nibName, bundle: bundle)
    }
    
    deinit {
        debugPrint("\(self) deinit")
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }
    
    override func loadView() {
        if self.nibBundle?.path(forResource: self.nibName, ofType: "nib") != nil {
            super.loadView()
        } else {
            self.view = .init(frame: .init(x: 0, y: 0, width: 500, height: 500))
        }
    }
    
}
