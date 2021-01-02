//
//  UIDevice+Helper.swift
//  Runner
//
//  Created by jimhuang on 2020/11/30.
//

import UIKit

extension UIDevice {
    var isiPad: Bool {
        return self.userInterfaceIdiom == .pad
    }
}
