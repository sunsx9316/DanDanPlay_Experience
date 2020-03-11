//
//  DanmakuModel.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import UIKit
import HandyJSON
import YYCategories

class DanmakuModel: BaseModel {
    enum Mode: Int, HandyJSONEnum {
        case normal = 1
        case bottom = 4
        case top = 5
    }
    
    var mode = Mode.normal
    var time: TimeInterval = 0
    var color = UIColor.white
    var message = ""
    var id = ""
    private var p: [String : String]?
    
    override func mapping(mapper: HelpingMapper) {
        mapper <<<
            p <-- TransformOf<[String : String], String>(fromJSON: { (rawString) -> [String : String]? in
                
                if let parameter = rawString?.components(separatedBy: ",") {
                    var dic = [String : String]()
                    
                    if parameter.count > 0 {
                        dic["Time"] = parameter[0]
                    }
                    
                    if parameter.count > 1 {
                        dic["Mode"] = parameter[1]
                    }
                    
                    if parameter.count > 2 {
                        dic["Color"] = parameter[2]
                    }
                    
                    if parameter.count > 3 {
                        dic["UId"] = parameter[3]
                    }
                    
                    return dic
                }
                return nil
            }, toJSON: { (value) -> String? in
                return "\(self.time),\(self.mode.rawValue),\(self.color),\(self.id)"
            })
        
        mapper <<<
            time <-- "Time"
        
        mapper <<<
            mode <-- "Mode"
        
        mapper <<<
            color <-- ("Color", TransformOf<UIColor, UInt32>(fromJSON: { (rawValue: UInt32?) -> UIColor? in
                return UIColor(rgb: rawValue ?? 0)
            }, toJSON: { (color: UIColor?) -> UInt32 in
                if let color = color {
                    let r = color.red * 255 * 256 * 256
                    let b = color.blue * 255 * 256
                    let g = color.green * 255
                    
                    return UInt32(r + g + b)
                }
                return 0
            }))
        
        mapper <<<
            message <-- ["Message", "m"]
        
        mapper <<<
            id <-- ["CId", "cid"]
    }
    
    override func didFinishMapping() {
        if let p = self.p {
            self.time = Double(p["Time"] ?? "0") ?? 0
            let modeRawValue = Int(p["Mode"] ?? "\(Mode.normal.rawValue)")!
            self.mode = Mode(rawValue: modeRawValue) ?? .normal
            self.color = UIColor(rgb: UInt32(p["Color"] ?? "0") ?? 0)
            self.id = p["UId"] ?? ""
            
            self.p = nil
        }
    }
}

class DanmakuCollectionModel: BaseCollectionModel<DanmakuModel> {
    var count = 0
    
    override func mapping(mapper: HelpingMapper) {
        mapper <<<
            collection <-- "comments"
    }
}
