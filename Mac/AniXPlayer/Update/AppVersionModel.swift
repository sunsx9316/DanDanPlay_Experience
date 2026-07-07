//
//  AppVersionModel.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/8/5.
//

import Foundation
import RxSwift

class AppVersionModel {
    
    func checkUpdate() -> Observable<UpdateInfo?> {
        return Observable<UpdateInfo?>.create { sub in
            ConfigNetworkHandle.checkUpdate { info, error in
                DispatchQueue.main.async {
                    if let error = error {
                        sub.onError(error)
                    } else {
                        sub.onNext(info)
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
        let appVersion = AppInfoHelper.buildNumber
        if !appVersion.isEmpty {
            //有版本更新
            if updateInfo.version.compare(appVersion, options: .numeric) == .orderedDescending {
                return true
            }
        }
        return false
    }
    
    private func isIgnoreVersion(updateInfo: UpdateInfo) -> Bool {
        if updateInfo.version == Preferences.shared.lastUpdateVersion {
            return true
        }
        return false
    }
    
}
