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
    
    public var url: URL? {
        if let urlDataString = self.urlDataString, let data = Data(base64Encoded: urlDataString) {
            var isStale = false
            return try? URL(resolvingBookmarkData: data, bookmarkDataIsStale: &isStale)
        }
        
        let characterSet = CharacterSet.urlQueryAllowed.union(CharacterSet.urlPathAllowed)
        
        if let path = self.path?.addingPercentEncoding(withAllowedCharacters: characterSet) {
            return URL(string: path)
        }
        
        return nil
    }
    
    public var type: FileType = .localFile
    public var size = 0
    public var otherParameter: [String : Any]?
    
    private var urlDataString: String?
    private var path: String?
}

public class LoadFilesMessage: BaseModel {
    public var fileDatas = [FileModel]()
}
