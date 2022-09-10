//
//  StartPlayMessage.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import HandyJSON

public class FileModel: BaseModel {
    public enum FileType: Int, HandyJSONEnum {
        case localFile
        case webDav
    }
    
    var file: File? {
        guard let path = self.path else { return nil }
        
//        switch self.type {
//        case .localFile:
//            let url = URL(fileURLWithPath: path)
//            return LocalFile(with: url, fileSize: self.size)
//        case .webDav:
//            let user = self.otherParameter?[WebDavKey.user.rawValue] as? String
//            let password = self.otherParameter?[WebDavKey.password.rawValue] as? String
//            let characterSet = CharacterSet.urlQueryAllowed.union(CharacterSet.urlPathAllowed)
//            if let aPath = path.addingPercentEncoding(withAllowedCharacters: characterSet),
//               let url = URL(string: aPath) {
//                return WebDavFile(with: url, fileSize: self.size, auth: .init(userName: user, password: password))
//            }
//        }
        
        return nil
    }
    
    
    public var type: FileType = .localFile
    public var size = 0
    public var otherParameter: [String : Any]?
    
    private var path: String?
}

public class LoadFilesMessage: BaseModel {
    public var fileDatas = [FileModel]()
}
