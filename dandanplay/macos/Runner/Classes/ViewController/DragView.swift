//
//  DragView.swift
//  Runner
//
//  Created by JimHuang on 2020/3/22.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Cocoa
import DDPMediaPlayer

class DragView: NSView {
    
    var dragFilesCallBack: (([URL]) -> Void)?
    
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupInit()
    }
    
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupInit()
    }
    
    override var acceptsFirstResponder: Bool {
        return true
    }
    
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation {
        return .copy
    }
    
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        var paths = [URL]();
        sender.enumerateDraggingItems(options: [], for: nil, classes: [NSURL.self], searchOptions: [.urlReadingFileURLsOnly : true]) { (draggingItem, index, stop) in
            if let url = draggingItem.item as? URL {
                
                if url.hasDirectoryPath {
                    
                    if let content = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) {
                        let urls = content.filter({ $0.isMediaFile }).sorted { (url1, url2) -> Bool in
                            return url1.path.compare(url2.path) == .orderedAscending
                        }
                        paths.append(contentsOf: urls)
                    }
                } else if (url.isMediaFile) {
                    paths.append(url)
                }
            }
        }
        
        if !paths.isEmpty {
            dragFilesCallBack?(paths)
        }
        
        return true
    }
    
    //MARK: Private
    private func setupInit() {
        if #available(OSX 10.13, *) {
            registerForDraggedTypes([.fileURL])
        } else {
            registerForDraggedTypes([NSPasteboard.PasteboardType(rawValue: kUTTypeFileURL as String)])
        }
    }
}
