//
//  Constant.swift
//  Runner
//
//  Created by JimHuang on 2020/3/11.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

#if os(iOS)
public typealias DDPColor = UIColor
#else
public typealias DDPColor = NSColor
#endif

enum MessageType: String {
    case loadDanmaku = "LoadDanmakuMessage"
    case HUDMessage = "HUDMessage"
    case syncSetting = "SyncSettingMessage"
    case loadFiles = "LoadFilesMessage"
    case appVersion = "AppVersionMessage"
    case inputDanmaku = "InputDanmakuMessage"
    case reloadMatch = "ReloadMatchWidgetMessage"
    case loadCustomDanmaku = "LoadCustomDanmakuMessage"
    //iOS only
    case naviBack = "NaviBackMessage"
    //mac only
    case becomeKeyWindow = "BecomeKeyWindowMessage"
}

public enum WebDavKey: String {
    case url
    case user = "web_dav_user"
    case password = "web_dav_password"
}
