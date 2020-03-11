//
//  StartPlayMessage.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import UIKit
import HandyJSON

extension StartPlayMessage {
    private class MediaItem: NSObject, DDPMediaItemProtocol {
        var url: URL?
        var mediaOptions: [AnyHashable : Any]?
    }
}

class StartPlayMessage: BaseModel, MediaItemProtocol {
    
    private(set) var path = "";
    private(set) var danmaku: DanmakuCollectionModel?
    
    private lazy var _meida: MediaItem = {
        var _meida = MediaItem()
        _meida.url = URL(fileURLWithPath: path)
        return _meida
    }()
    
    
    var collectionModel: DanmakuCollectionModel? {
        get {
            return self.danmaku
        }
        
        set {
            self.danmaku = newValue
        }
    }
    
    var media: DDPMediaItemProtocol? {
        return _meida
    }
}
