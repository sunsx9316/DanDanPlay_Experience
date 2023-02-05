//
//  SMBFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/4/29.
//

#if os(iOS)

import Foundation
import MobileVLCKit

class SMBFile: File {
    
    enum PathType {
        case root
        case share
        case normal
    }
    
    let url: URL
    
    var fileSize: Int = 0
    
    let type: FileType
    
    let pathType: PathType
    
    let shareName: String
    
    static var fileManager: FileManagerProtocol {
        return SMBFileManager.shared
    }
    
    var fileName: String {
        switch self.pathType {
        case .normal:
            return self.url.lastPathComponent
        case.root:
            return self.url.absoluteString
        case .share:
            return self.url.host ?? ""
        }
    }
    
    let path: String
    
    static var rootFile: File = SMBFile(rootPath: "/")
    
    var parentFile: File? {
        //根目录
        if self.path == "" {
            return SMBFile(shareName: self.shareName)
        } else {
            let path = (self.path as NSString).deletingLastPathComponent
            return SMBFile(file: [.pathKey : path,
                                  .fileResourceTypeKey : URLFileResourceType.directory],
                           shareName: self.shareName)
        }
    }
    
    var isCanDelete: Bool {
        if self.url == SMBFile.rootFile.url {
            return false
        }
        return self.pathType == .normal
    }
    
    init(shareName: String) {
        self.pathType = .share
        self.type = .folder
        self.path = shareName
        self.shareName = ""
        
        var urlComponents = URLComponents(string: "")
        urlComponents?.scheme = "smbshare"
        urlComponents?.host = shareName
        if let url = urlComponents?.url {
            self.url = url
        } else {
            self.url = URL(fileURLWithPath: "")
            assert(false, "url初始化失败 shareName:\(shareName)")
        }
    }
    
    init(file: [URLResourceKey: Any], shareName: String) {
        self.pathType = .normal
        self.shareName = shareName
        self.path = file[.pathKey] as? String ?? ""
        
        var svrURL: URL
        if let loginInfo = SMBFileManager.shared.loginInfo {
            svrURL = loginInfo.url

        } else {
            svrURL = URL(fileURLWithPath: "/")
            ANX.logError(.SMB, "loginfo初始化失败")
        }
        
        if #available(iOS 16.0, *) {
            svrURL.append(path: shareName)
            svrURL.append(path: self.path)
        } else {
            svrURL.appendPathComponent(shareName)
            svrURL.appendPathComponent(self.path)
        }
        
        self.url = svrURL
        
        if let size = file[.fileSizeKey] as? NSNumber {
            self.fileSize = size.intValue
        }
        
        if let type = file[.fileResourceTypeKey] as? URLFileResourceType {
            switch type {
            case .directory, .symbolicLink:
                self.type = .folder
            default:
                self.type = .file
            }
        } else {
            self.type = .file
            assert(false, "type初始化失败 \(file)")
        }
    }
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        let media = VLCMedia(url: self.url)
        let auth = SMBFileManager.shared.loginInfo?.auth
        
        var options = [AnyHashable : Any]()
        options["smb-user"] = auth?.userName
        options["smb-pwd"] = auth?.password
        media.addOptions(options)
        return media
    }
    
    //MARK: Private Method
    private init(rootPath: String) {
        self.pathType = .root
        self.type = .folder
        self.path = rootPath
        self.shareName = ""
        
        if let url = URL(string: self.path) {
            self.url = url
        } else {
            self.url = URL(fileURLWithPath: "")
            assert(false, "url初始化失败 rootPath:\(rootPath)")
        }
    }
    
}

#endif
