//
//  ParseFileMessage.swift
//  dandanplay_native
//
//  Created by JimHuang on 2020/2/16.
//

import Foundation

public class ParseFileMessage: BaseModel, MessageProtocol {
    public var fileName: String?
    public var fileHash: String?
    public var fileSize = 0
    public var mediaId = ""
}
