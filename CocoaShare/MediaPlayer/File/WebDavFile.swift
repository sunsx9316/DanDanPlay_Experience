//
//  WebDavFile.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
import MobileVLCKit
import FilesProvider
#else
import VLCKit
#endif

private class Coordinator: NSObject, StreamDelegate, DDPWebDAVInputStreamFile {
    
    private weak var file: WebDavFile?

    init(file: WebDavFile) {
        super.init()
        self.file = file
    }

    var url: URL {
        return self.file?.url ?? URL(fileURLWithPath: "/")
    }
    
    var fileSize: Int {
        return self.file?.fileSize ?? 0
    }
    
    func requestData(with range: NSRange, progressHandle progress: @escaping (Double) -> Void, completion: @escaping (Data?, Error?) -> Void) {
        self.file?.getDataWithRange(range.lowerBound...range.upperBound, progress: progress) { result in
            switch result {
            case .success(let data):
                completion(data, nil)
            case .failure(let err):
                completion(nil, err)
            }
        }
    }
    
    
//    func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
//        if eventCode == .endEncountered {
//            self.file?.inputStream = nil
//        }
//    }
}

class WebDavFile: File {
    
    var type: FileType = .file
    
    var url: URL
    
    var fileSize = 0
    
    fileprivate var inputStream: DDPWebDAVInputStream?
    
    private lazy var coordinator = Coordinator(file: self)
    
    //应该是vlc的bug，需要强引用InputStream对象，否则会crash
    private static var inputStream: DDPWebDAVInputStream?
    
    static var rootFile: File {
        return WebDavFile(url: URL(string: "/")!, fileSize: 0)
    }
    
    var parentFile: File? {
        return WebDavFile(url: self.url.deletingLastPathComponent(), fileSize: 0)
    }
    
    var fileManager: FileManagerProtocol {
        return WebDavFileManager.shared
    }
    
    init(with file: FileObject) {
        self.url = file.url
        self.fileSize = Int(file.size)
        self.type = (file.isDirectory || file.isSymLink) ? .folder : .file
    }
    
    private init(url: URL, fileSize: Int = 0) {
        self.url = url
        self.fileSize = fileSize
        self.type = .folder
    }
    
    deinit {
        debugPrint("webdavfile dealloc")
    }
    
    func createMedia() -> VLCMedia? {
        let inputStream = DDPWebDAVInputStream(file: self.coordinator)
        WebDavFile.inputStream = inputStream
        inputStream.delegate = self.coordinator
        self.inputStream = inputStream
        return VLCMedia(stream: inputStream)
    }
   
}
