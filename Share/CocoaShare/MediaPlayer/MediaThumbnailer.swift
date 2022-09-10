//
//  MediaThumbnailer.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/5/4.
//

import Foundation

#if os(iOS)
import MobileVLCKit
import AVFoundation
#else
import VLCKit
#endif

class MediaThumbnailer: NSObject {
    
    private class Task: VLCMediaThumbnailerDelegate {
        
        private(set) var snapshot: ANXImage?
        
        private(set) var isFinish = false
        
        private let media: VLCMedia
        
        private lazy var thumbnailer: VLCMediaThumbnailer? = {
            let thumbnailer = VLCMediaThumbnailer(media: self.media, andDelegate: self)
            return thumbnailer
        }()
        
        init(media: VLCMedia, progres: Float) {
            self.media = media
            self.thumbnailer?.snapshotPosition = progres
        }
        
        func start() {
            if !self.isFinish {
                self.thumbnailer?.fetchThumbnail()                
            }
        }
        
        //MARK: VLCMediaThumbnailerDelegate
        func mediaThumbnailerDidTimeOut(_ mediaThumbnailer: VLCMediaThumbnailer!) {
            DispatchQueue.main.async {
                self.isFinish = true
            }
        }
        
        func mediaThumbnailer(_ mediaThumbnailer: VLCMediaThumbnailer!, didFinishThumbnail thumbnail: CGImage!) {
            let img = ANXImage(cgImage: thumbnail)
            DispatchQueue.main.async {
                self.snapshot = img
                self.isFinish = true
            }
        }
    }
    
    private let media: VLCMedia
    
    private let interval: Int
    
    private lazy var snapshotTaskDic: [Int: Task] = {
        let count = Int(self.media.length.intValue) / self.interval
        var snapshotTaskDic = [Int: Task]()
        for i in 0..<count {
            let task = Task(media: media, progres: Float(i) / Float(count))
            snapshotTaskDic[i] = task
        }
        return snapshotTaskDic
    }()
    
    init(media: VLCMedia, interval: Int = 5) {
        self.media = media
        self.interval = max(interval, 1)
        super.init()
    }
    
    func start() {
        if media.parsedStatus == .`init` {
            media.delegate = self
            media.parse(withOptions: VLCMediaParsingOptions(VLCMediaParseLocal | VLCMediaParseNetwork))
        } else {
            self.snapshotTaskDic.values.forEach({ $0.start() })
        }
    }
    
    func snapshot(at time: Int) -> ANXImage? {
        let realTime = time - (time % interval)
        return self.snapshotTaskDic[realTime]?.snapshot
    }
}

extension MediaThumbnailer: VLCMediaDelegate {
    func mediaDidFinishParsing(_ aMedia: VLCMedia) {
        DispatchQueue.main.async {
            self.snapshotTaskDic.values.forEach({ $0.start() })
        }
    }
}
