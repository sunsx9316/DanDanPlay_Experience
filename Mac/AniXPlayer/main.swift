//
//  main.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/17.
//

import Foundation

import Foundation
import AppKit

let app: NSApplication = NSApplication.shared
let appDelegate = AppDelegate()  // Instantiates the class the @NSApplicationMain was attached to

// 会员门禁接线：业务功能统一走 EntitlementGate；菜单入口仍由集成方接入。
Task { @MainActor in
    MacMembershipIntegration.install()
}
app.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
