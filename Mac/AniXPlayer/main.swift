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
app.delegate = appDelegate
_ = NSApplicationMain(CommandLine.argc, CommandLine.unsafeArgv)
