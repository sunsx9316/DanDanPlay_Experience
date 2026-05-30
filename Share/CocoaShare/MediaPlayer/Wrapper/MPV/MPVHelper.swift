//
//  MPVFontHelper.swift
//  CocoaShare
//
//  共享字体准备工具：将自定义字体从 Bundle 复制到缓存目录，供 mpv 渲染字幕使用
//

import Foundation
import ANXLog

let mpvCustomFontNames = [
    "SourceHanSansSC-Regular",
    "SourceHanSansTC-Regular"
]

/// 将自定义字体从 Bundle 复制到缓存目录，返回字体目录路径
func mpvPrepareFonts() -> String? {
    let fontCacheDir = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Fonts")

    do {
        try FileManager.default.createDirectory(at: fontCacheDir, withIntermediateDirectories: true)

        for fontName in mpvCustomFontNames {
            let ttfPath = Bundle.main.path(forResource: fontName, ofType: "ttf")
            let otfPath = Bundle.main.path(forResource: fontName, ofType: "otf")
            let sourcePath = ttfPath ?? otfPath
            let ext = ttfPath != nil ? "ttf" : "otf"

            if let bundlePath = sourcePath {
                let destPath = fontCacheDir.appendingPathComponent("\(fontName).\(ext)")
                if FileManager.default.fileExists(atPath: destPath.path) {
                    try FileManager.default.removeItem(at: destPath)
                }
                try FileManager.default.copyItem(atPath: bundlePath, toPath: destPath.path)
            }
        }

        return fontCacheDir.path
    } catch {
        ANX.logError(.player, "[MPV] 字体准备失败: \(error)")
        return nil
    }
}
