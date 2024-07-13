//
//  DateFormatter+Helper.swift.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import Foundation

extension DateFormatter {
    
    /// 解析YYYY-MM-ddTHH:mm:ss
    static var anix_YYYY_MM_dd_T_HH_mm_ssFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "YYYY-MM-dd'T'HH:mm:ss"
        return dateFormatter
    }()
    
    
    /// 解析 yyyy-MM-dd'T'HH:mm:ss.SSS'Z'
    static var anix_YYYY_MM_dd_T_HH_mm_ss_SSSFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSS"
        return dateFormatter
    }()
    
    /// 解析 yyyy-MM-dd'T'HH:mm:ss.SSS'Z'
    static var anix_YYYY_MM_dd_T_HH_mm_ss_SSSZFormatter: DateFormatter = {
        var dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss.SSSZ"
        return dateFormatter
    }()
}
