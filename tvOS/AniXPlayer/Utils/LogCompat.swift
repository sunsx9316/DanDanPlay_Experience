//
//  LogCompat.swift
//  AniXPlayer
//
//  tvOS os_log wrapper — 替代 ANXLog pod，直接使用 Apple os_log API
//

#if os(tvOS)

import Foundation
import os.log

public typealias ANXLogHelperModule = String

extension ANXLogHelperModule {
    static var player: ANXLogHelperModule { "Player" }
    static var HTTP: ANXLogHelperModule { "HTTP" }
    static var UI: ANXLogHelperModule { "UI" }
    static var subtitle: ANXLogHelperModule { "Subtitle" }
    static var webDav: ANXLogHelperModule { "WebDav" }
    static var SMB: ANXLogHelperModule { "SMB" }
}

public struct ANX {
    private init() {}

    public static func logInfo(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module: module, level: .info, format: format, arguments: arguments)
    }

    public static func logDebug(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module: module, level: .debug, format: format, arguments: arguments)
    }

    public static func logError(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module: module, level: .error, format: format, arguments: arguments)
    }

    public static func logWarning(_ module: ANXLogHelperModule, _ format: String, _ arguments: CVarArg..., fileName: String = #file, line: Int = #line, funcName: String = #function) {
        log(module: module, level: .default, format: format, arguments: arguments)
    }

    private static func log(module: ANXLogHelperModule, level: OSLogType, format: String, arguments: [CVarArg]) {
        let message = arguments.isEmpty ? format : String(format: format, arguments: arguments)
        let log = OSLog(subsystem: "com.dandanplay.anixplayer", category: module)
        os_log(level, log: log, "%{public}s", message)
    }
}

public class ANXLogHelper {
    public static func setup() {}
    public static func close() {}
    public static func flush() {}
    public static func logPath() -> String {
        return NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first?.appending("/log") ?? ""
    }
}

#endif
