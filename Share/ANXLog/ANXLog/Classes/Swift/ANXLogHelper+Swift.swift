//
//  ANXLogHelper+Swift.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/4/11.
//

import Foundation
#if SPM_MODE
import ANXLog_Objc
#endif

fileprivate extension ANXLogLevel {
    var prefix: String {
        switch self {
            
        case .all:
            return ""
        case .debug:
            return "Debug:"
        case .info:
            return "Info:"
        case .warn:
            return "Warn:"
        case .error:
            return "Error:"
        case .fatal:
            return "Fatal:"
        case .none:
            return ""
        @unknown default:
            return ""
        }
    }
}

public struct ANX {
    
    private init() {}
    
    public static func logError(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module, message: String(format: format, arguments), fileName: fileName, line: line, funcName: funcName, level: .error)
    }
    
    public static func logWarning(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module, message: String(format: format, arguments), fileName: fileName, line: line, funcName: funcName, level: .warn)
    }
    
    public static func logInfo(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module, message: String(format: format, arguments), fileName: fileName, line: line, funcName: funcName, level: .info)
    }
    
    public static func logDebug(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module, message: String(format: format, arguments), fileName: fileName, line: line, funcName: funcName, level: .debug)
    }
    
    private static func log(_ module: ANXLogHelperModule, message: String, fileName: String, line: Int, funcName: String, level: ANXLogLevel) {
        
        ANXLogHelper.__log(with: level, moduleName: module, fileName: (fileName as NSString).utf8String!, lineNumber: Int32(line), funcName: (funcName as NSString).utf8String!, message: message)
    }
}
