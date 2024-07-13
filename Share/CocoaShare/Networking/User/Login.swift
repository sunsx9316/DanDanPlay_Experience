//
//  Login.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/7/13.
//

import Foundation

/// 用户权益过期时间（全部为北京时间）
struct UserPrivileges: Decodable {
    /// 会员权益过期时间（北京时间）
    @Default<String> var member: String
    /// 弹弹play资源监视器权益过期时间（北京时间）
    @Default<String> var resmonitor: String
}

/// 登录响应
struct LoginResponse: Decodable {
    /// 该用户是否需要先注册弹弹play账号才可正常登录
    @Default<Bool> var registerRequired: Bool
    /// 用户编号
    @Default<Int> var userId: Int
    /// 弹弹play用户名。如果用户使用第三方账号登录（如QQ微博）且没有关联弹弹play账号，此属性将为null
    @Default<String> var userName: String
    /// 旧API中使用的数字形式的token，仅为兼容性设置，不要在新代码中使用此属性
    @Default<Int> var legacyTokenNumber: Int
    /// 字符串形式的JWT token。将来调用需要验证权限的接口时，需要在HTTP Authorization头中设置“Bearer token”
    @Default<String> var token: String
    /// JWT token过期时间，默认为21天。如果是APP应用开发者账号使用自己的应用登录则为1年
    @Default<String> var tokenExpireTime: String
    /// 用户注册来源类型
    @Default<String> var userType: String
    /// 昵称
    @Default<String> var screenName: String
    /// 头像图片的地址
    @Default<String> var profileImage: String
    /// 当前登录会话内应用权限列表，可以由此判断能否调用哪些API
    @Default<String> var appScope: String
    /// 用户权益过期时间（全部为北京时间）
    var privileges: UserPrivileges?
    /// 消息体验证码
    @Default<String> var code: String
    /// 当前时间戳
    @Default<Int> var ts: Int
    /// 错误代码，0表示没有发生错误，非0表示有错误，详细信息会包含在errorMessage属性中
    @Default<Int> var errorCode: Int
    /// 接口是否调用成功
    @Default<Bool> var success: Bool
    /// 当发生错误时，说明错误具体原因
    @Default<String> var errorMessage: String
}
