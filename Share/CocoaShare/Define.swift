//
//  Define.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/6/26.
//

import Foundation

#if os(iOS)
import UIKit
typealias ANXColor = UIColor
typealias ANXView = UIView
typealias ANXImage = UIImage
typealias ANXViewController = UIViewController
#else
import Cocoa
typealias ANXColor = NSColor
typealias ANXView = NSView
typealias ANXImage = NSImage
typealias ANXViewController = NSViewController
#endif
