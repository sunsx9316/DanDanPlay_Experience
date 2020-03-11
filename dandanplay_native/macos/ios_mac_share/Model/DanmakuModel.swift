//
//  DanmakuModel.swift
//  DanDanPlayExperience
//
//  Created by JimHuang on 2020/2/2.
//  Copyright © 2020 JimHuang. All rights reserved.
//

import HandyJSON

#if os(iOS)
typealias DanmakuColor = UIColor
#else
typealias DanmakuColor = NSColor
#endif

open class DanmakuModel: BaseModel {
    public enum Mode: Int, HandyJSONEnum {
        case normal = 1
        case bottom = 4
        case top = 5
    }
    
    open var mode = Mode.normal
    open var time: TimeInterval = 0
    
    open var color = DanmakuColor.white
    open var message = ""
    open var id = ""
    private var p: [String : String]?
    
    override open func mapping(mapper: HelpingMapper) {
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
            color <-- ("Color", TransformOf<DanmakuColor, UInt32>(fromJSON: { (rawValue: UInt32?) -> DanmakuColor? in
                return DanmakuColor(rgb: rawValue ?? 0)
            }, toJSON: { (color: DanmakuColor?) -> UInt32 in
                if let color = color {
                    let r = color.redComponent * 255 * 256 * 256
                    let b = color.blueComponent * 255 * 256
                    let g = color.greenComponent * 255
                    
                    return UInt32(r + g + b)
                }
                return 0
            }))
        
        mapper <<<
            message <-- ["Message", "m"]
        
        mapper <<<
            id <-- ["CId", "cid"]
    }
    
    override open func didFinishMapping() {
        if let p = self.p {
            self.time = Double(p["Time"] ?? "0") ?? 0
            let modeRawValue = Int(p["Mode"] ?? "\(Mode.normal.rawValue)")!
            self.mode = Mode(rawValue: modeRawValue) ?? .normal
            self.color = DanmakuColor(rgb: UInt32(p["Color"] ?? "0") ?? 0)
            self.id = p["UId"] ?? ""
            
            self.p = nil
        }
    }
}

open class DanmakuCollectionModel: BaseCollectionModel<DanmakuModel> {
    open var count = 0
    
    override open func mapping(mapper: HelpingMapper) {
        mapper <<<
            collection <-- "comments"
    }
}
