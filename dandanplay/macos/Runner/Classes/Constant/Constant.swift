//
//  Constant.swift
//  Runner
//
//  Created by JimHuang on 2020/3/11.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

enum MessageType: String {
    case loadDanmaku = "LoadDanmakuMessage"
    case HUDMessage = "HUDMessage"
    case syncSetting = "SyncSettingMessage"
    case becomeKeyWindow = "BecomeKeyWindowMessage"
    case appVersion = "AppVersionMessage"
}
