//
//  HostStubs.swift
//  AniXPlayerTests
//
//  无宿主单元测试：被测源码直接编进测试 target。
//  这里只提供被测文件引用到的少量 App 符号，不包含任何业务逻辑。
//

import Foundation

let DefaultHost = "https://api.dandanplay.net"

final class Preferences {
    static let shared = Preferences()
    var host = DefaultHost
}

enum AppInfoHelper {
    static var appVersion: String { "0.0-test" }
}

extension DateFormatter {
    static let anix_YYYY_MM_dd_T_HH_mm_ssFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 8 * 3600)
        return formatter
    }()
}

extension Notification.Name {
    static let AnixUserLoginStateDidChange = Notification.Name("userLoginStateDidChange")
}
