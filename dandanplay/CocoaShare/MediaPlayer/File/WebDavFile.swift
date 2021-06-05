//
//  WebDavFile.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
import MobileVLCKit
#else
import VLCKit
#endif

struct Auth {
    let user: String?
    
    let password: String?
    
    
    
    init(user: String?, password: String?) {
        self.user = user
        self.password = password
    }
    
}

class WebDavFile: NSObject, File {
    
    var media: VLCMedia? {
        if let inputStream = self.inputStream {
            return VLCMedia(stream: inputStream)
        }
        return nil
    }
    
    var type: FileType = .file
    
    var fileManager: FileManagerProtocol {
        return LocalFileManager()
    }
    
    var url: URL
    
    var fileSize = 0
    
    var inputStream: WebDAVInputStream?
    
    private(set) var auth: Auth?
    
    
    init(with url: URL, fileSize: Int, auth: Auth? = nil) {
        self.url = url
        self.fileSize = fileSize
        self.inputStream = WebDAVInputStream(url: url, fileLength: fileSize, auth: auth)
        super.init()
        self.auth = auth
    }
    
    deinit {
        self.inputStream?.close()
    }
    
    func getDataWithRange(_ range: ClosedRange<Int>, progress: @escaping (FileProgressAction), completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        self.inputStream?.getDataWithRange(NSRange(location: range.lowerBound, length: range.upperBound - range.lowerBound), progressHandle: progress, completion: completion)
    }
   
}
