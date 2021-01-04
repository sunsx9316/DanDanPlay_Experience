//
//  StartPlayMessage.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import HandyJSON

public class FilesModel: BaseModel {
    public var path: String?
    public var urlDataString: String?
}

public class LoadFilesMessage: BaseModel {
    public var fileDatas = [FilesModel]()
}
