//
//  AppVersionModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/5.
//

import Foundation
import RxSwift

class AppVersionModel {
    
    func checkUpdate() -> Observable<UpdateInfo> {
        return Observable<UpdateInfo>.create { sub in
            ConfigNetworkHandle.checkUpdate { info, error in
                if let info = info {
                    DispatchQueue.main.async {
                        sub.onNext(info)
                        sub.onCompleted()
                    }
                } else if let error = error {
                    DispatchQueue.main.async {
                        sub.onError(error)
                    }
                } else {
                    DispatchQueue.main.async {
                        sub.onCompleted()
                    }
                }
            }
            
            return Disposables.create()
        }
    }
    
    func shouldUpdate(updateInfo: UpdateInfo) -> Bool {
        return !isIgnoreVersion(updateInfo: updateInfo) && isNewVersion(updateInfo: updateInfo)
    }
    
    func updateIgnoreVersion(updateInfo: UpdateInfo) {
        Preferences.shared.lastUpdateVersion = updateInfo.version
    }
    
    private func isNewVersion(updateInfo: UpdateInfo) -> Bool {
        if let appVersion = InfoPlistUtils.appBuildNumber {
            //有版本更新
            if updateInfo.version.compare(appVersion, options: .numeric) == .orderedDescending {
                return true
            }
        }
        return false
    }
    
    private func isIgnoreVersion(updateInfo: UpdateInfo) -> Bool {
        if updateInfo.version != Preferences.shared.lastUpdateVersion {
            return true
        }
        return false
    }
    
}
