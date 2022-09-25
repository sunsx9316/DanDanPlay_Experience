//
//  ScrollView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/15.
//

import Cocoa

class ScrollView<ContainerView: NSView>: NSScrollView {
    
    var containerView: ContainerView {
        get {
            return self.documentView as! ContainerView
        }
        
        set {
            self.documentView = newValue
        }
    }
    
    convenience init(containerView: ContainerView) {
        self.init(frame: .zero)
        
        self.documentView = containerView
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        self.setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
    }
    
    private func setupInit() {
        self.hasVerticalScroller = true
        self.hasHorizontalScroller = true
        self.scrollerStyle = .overlay
        self.horizontalScrollElasticity = .automatic
        self.verticalScrollElasticity = .automatic
        self.autoresizingMask = [.width, .height]
    }
    
}
