//
//  MPVFontHelper.swift
//  CocoaShare
//
//  共享字体准备工具：将自定义字体从 Bundle 复制到缓存目录，供播放器渲染字幕使用
//

import Foundation
#if !os(tvOS)
import ANXLog
#endif
import CoreText

/// 自定义字体文件名列表（不含扩展名）
let playerCustomFontNames = [
    "SourceHanSansSC-Regular",
    "SourceHanSansTC-Regular"
]

/// 自定义字体族名列表（与 playerCustomFontNames 一一对应，用于 libass 的 fontfamily 参数）
let playerCustomFontFamilies = [
    "Source Han Sans SC",
    "Source Han Sans TC"
]

/// MPV 兼容别名
let mpvCustomFontNames = playerCustomFontNames

/// 将自定义字体从 Bundle 复制到缓存目录，注册到 CoreText，返回字体目录路径
func playerPrepareFonts() -> String? {
    let fontCacheDir = FileManager.default
        .urls(for: .cachesDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Fonts")

    do {
        try FileManager.default.createDirectory(at: fontCacheDir, withIntermediateDirectories: true)

        for fontName in playerCustomFontNames {
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

                // 注册到 CoreText，使 libass/freetype 的 CoreText provider 能查找到
                CTFontManagerRegisterFontsForURL(destPath as CFURL, .process, nil)
            }
        }

        return fontCacheDir.path
    } catch {
        ANX.logError(.player, "[FontHelper] 字体准备失败: \(error)")
        return nil
    }
}

/// MPV 兼容别名
func mpvPrepareFonts() -> String? {
    return playerPrepareFonts()
}
