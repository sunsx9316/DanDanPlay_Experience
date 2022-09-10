//
//  HttpServer.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/9.
//

import Foundation
import GCDWebServer

private class _GCDWebUploader: GCDWebUploader {
    override func shouldDeleteItem(atPath path: String) -> Bool {
        return false
    }
    
}

private class Coordinator: NSObject, GCDWebUploaderDelegate {
    
    weak var svr: HttpServer?
    
    init(svr: HttpServer) {
        super.init()
        self.svr = svr
    }
    
    func webUploader(_ uploader: GCDWebUploader, didUploadFileAtPath path: String) {
        guard let svr = self.svr else { return }
        svr.delegate?.httpServer(svr, didReceiveFileAtPath: path)
    }
    
    func webServerDidStart(_ server: GCDWebServer) {
        guard let svr = self.svr else { return }
        svr.delegate?.httpServerDidStart(svr)
    }
}

protocol HttpServerDelegate: AnyObject {
    func httpServer(_ httpServer: HttpServer, didReceiveFileAtPath path: String)
    func httpServerDidStart(_ httpServer: HttpServer)
}

class HttpServer {
    
    private lazy var svr: GCDWebUploader = {
        let svr = _GCDWebUploader(uploadDirectory: UIApplication.shared.documentsPath)
        svr.prologue = NSLocalizedString("拖拽到窗口 或 点击“Upload Files…” 上传文件", comment: "")
        svr.footer = "http://www.dandanplay.com"
        svr.delegate = self.coordinator
        return svr
    }()
    
    private lazy var coordinator = Coordinator(svr: self)
    
    var serverURL: URL? {
        return self.svr.serverURL
    }
    
    weak var delegate: HttpServerDelegate?
    
    func start() {
        self.svr.start(withPort: 2333, bonjourName: nil)
    }
    
    func stop() {
        self.svr.stop()
    }
    
    deinit {
        self.stop()
    }
}
