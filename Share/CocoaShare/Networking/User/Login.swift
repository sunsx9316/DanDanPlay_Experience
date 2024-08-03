//
//  Login.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import Foundation

/// 用户权益过期时间（全部为北京时间）
struct UserPrivileges: Codable {
    /// 会员权益过期时间（北京时间）
    var member: Date?
    /// 弹弹play资源监视器权益过期时间（北京时间）
    var resmonitor: Date?
    
    private enum CodingKeys: CodingKey {
        case member
        case resmonitor
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        
        let dateFormatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ssFormatter
        
        if let member = member {
            try container.encode(dateFormatter.string(from: member), forKey:.member)
        }
         
        if let resmonitor = resmonitor {
            try container.encode(dateFormatter.string(from: resmonitor), forKey:.resmonitor)
        }
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        let dateFormatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ssFormatter
        if let memberStr = try container.decodeIfPresent(String.self, forKey: .member),
           let data = dateFormatter.date(from: memberStr) {
            self.member = data
        }
        
        if let resmonitorStr = try container.decodeIfPresent(String.self, forKey: .resmonitor),
           let data = dateFormatter.date(from: resmonitorStr) {
            self.resmonitor = data
        }
    }
}

/// 登录信息
struct AnixLoginInfo: Codable {
    /// 该用户是否需要先注册弹弹play账号才可正常登录
    var registerRequired: Bool
    /// 用户编号
    var userId: Int
    /// 弹弹play用户名。如果用户使用第三方账号登录（如QQ微博）且没有关联弹弹play账号，此属性将为null
    var userName: String
    /// 旧API中使用的数字形式的token，仅为兼容性设置，不要在新代码中使用此属性
    var legacyTokenNumber: Int
    /// 字符串形式的JWT token。将来调用需要验证权限的接口时，需要在HTTP Authorization头中设置“Bearer token”
    var token: String
    /// JWT token过期时间，默认为21天。如果是APP应用开发者账号使用自己的应用登录则为1年
    var tokenExpireTime: Date?
    /// 用户注册来源类型
    var userType: String
    /// 昵称
    var screenName: String
    /// 头像图片的地址
    var profileImage: String
    /// 当前登录会话内应用权限列表，可以由此判断能否调用哪些API
    var appScope: String
    /// 用户权益过期时间（全部为北京时间）
    var privileges: UserPrivileges?
    
    private enum CodingKeys: CodingKey {
        case registerRequired
        case userId
        case userName
        case legacyTokenNumber
        case token
        case tokenExpireTime
        case userType
        case screenName
        case profileImage
        case appScope
        case privileges
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(registerRequired, forKey:.registerRequired)
        try container.encode(userId, forKey:.userId)
        try container.encode(userName, forKey:.userName)
        try container.encode(legacyTokenNumber, forKey:.legacyTokenNumber)
        try container.encode(token, forKey:.token)
        
        
        if let date = self.tokenExpireTime {
            let dateFormatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ss_SSSZFormatter
            let dateString = dateFormatter.string(from: date)
            try container.encode(dateString, forKey:.tokenExpireTime)
        }
        
        try container.encode(userType, forKey:.userType)
        try container.encode(screenName, forKey:.screenName)
        try container.encode(profileImage, forKey:.profileImage)
        try container.encode(appScope, forKey:.appScope)
        try container.encodeIfPresent(privileges, forKey:.privileges)
    }
    
    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.registerRequired = try container.decode(Bool.self, forKey: .registerRequired)
        self.userId = try container.decodeIfPresent(Int.self, forKey: .userId) ?? 0
        self.userName = try container.decodeIfPresent(String.self, forKey: .userName) ?? ""
        self.legacyTokenNumber = try container.decodeIfPresent(Int.self, forKey: .legacyTokenNumber) ?? 0
        self.token = try container.decodeIfPresent(String.self, forKey: .token) ?? ""
        
        let dateFormatter = DateFormatter.anix_YYYY_MM_dd_T_HH_mm_ss_SSSZFormatter
        if let dateString = try container.decodeIfPresent(String.self, forKey: .tokenExpireTime),
           let date = dateFormatter.date(from: dateString) {
            self.tokenExpireTime = date
        }
        
        self.userType = try container.decodeIfPresent(String.self, forKey: .userType) ?? ""
        self.screenName = try container.decodeIfPresent(String.self, forKey: .screenName) ?? ""
        self.profileImage = try container.decodeIfPresent(String.self, forKey: .profileImage) ?? ""
        self.appScope = try container.decodeIfPresent(String.self, forKey: .appScope) ?? ""
        self.privileges = try container.decodeIfPresent(UserPrivileges.self, forKey: .privileges)
    }
}
