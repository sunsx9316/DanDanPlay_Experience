//
//  ProgressHUDHelper.swift
//  Runner
//
//  Created by JimHuang on 2020/3/22.
//  Copyright © 2020 The Flutter Authors. All rights reserved.
//

import Foundation

class ProgressHUDHelper {
    
    @discardableResult class func showHUD(text: String) -> ProgressHUD {
        let hud = createHUDOnMainScreen(mode: .text)
        hud.setStatus(text)
        hud.hide(true, dismissAfterDelay: 2)
        return hud
    }
    
    @discardableResult class func showProgressHUD(text: String, progress: Double) -> ProgressHUD {
        let hud = createHUDOnMainScreen(mode: .determinate)
        hud.setStatus(text)
        return hud
    }
    
    private class func createHUDOnMainScreen(mode: ProgressHUDMode) -> ProgressHUD {
        
        let hud = ProgressHUD()
        hud.show(withStatus: "", mode: mode)
        return hud
    }
    
}
