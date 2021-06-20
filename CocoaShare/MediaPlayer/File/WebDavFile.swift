//
//  WebDavFile.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/14.
//

import Foundation
#if os(iOS)
//import MobileVLCKit
import FilesProvider
#else
import VLCKit
#endif

private class Coordinator: NSObject, StreamDelegate {

    private weak var file: WebDavFile?

    init(file: WebDavFile) {
        super.init()
        self.file = file
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
    
    fileprivate var inputStream: WebDAVInputStream?
    
    private lazy var coordinator = Coordinator(file: self)
    
    //应该是vlc的bug，需要强引用InputStream对象，否则会crash
    private static var inputStream: WebDAVInputStream?
    
    static var rootFile: File = WebDavFile(url: URL(string: "/")!, fileSize: 0)
    
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
        let inputStream = WebDAVInputStream(file: self)
        WebDavFile.inputStream = inputStream
        inputStream?.delegate = self.coordinator
        self.inputStream = inputStream
        return VLCMedia(stream: inputStream!)
    }
    
    func getParseDataWithProgress(_ progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        let length = parseFileLength
        self.getDataWithRange(0...length, progress: progress, completion: completion)
    }
   
}
