//
//  NSImage+Utils.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

#if os(macOS)

import Cocoa

extension NSImage {
    convenience init(cgImage: CGImage) {
        self.init(cgImage: cgImage, size: .zero)
    }

    /// 安全创建 SF Symbol 图像，避免强制解包
    static func safeSystemSymbol(_ name: String) -> NSImage {
        return NSImage(systemSymbolName: name, accessibilityDescription: nil) ?? NSImage()
    }

    /// 保存截图到本地目录（默认「图片/AniXPlayer」，可在设置中修改）
    /// - Parameters:
    ///   - fileName: 文件名（不含扩展名）
    ///   - completion: 主线程回调，成功时返回文件地址
    func saveSnapshot(fileName: String, completion: @escaping (_ result: Result<URL, Error>) -> Void) {
        DispatchQueue.global(qos: .utility).async {
            let result: Result<URL, Error>

            do {
                let resolved = try SnapshotLocation.resolveAccessibleDirectory()
                defer {
                    if resolved.needsStopAccess {
                        resolved.url.stopAccessingSecurityScopedResource()
                    }
                }

                let url = resolved.url.appendingPathComponent(fileName).appendingPathExtension("png")

                guard let tiffData = self.tiffRepresentation,
                      let bitmap = NSBitmapImageRep(data: tiffData),
                      let pngData = bitmap.representation(using: .png, properties: [:]) else {
                    throw NSError(domain: "AniXPlayer.Snapshot", code: -1,
                                  userInfo: [NSLocalizedDescriptionKey: NSLocalizedString("图片编码失败", comment: "")])
                }

                try pngData.write(to: url, options: .atomic)
                result = .success(url)
            } catch {
                result = .failure(error)
            }

            DispatchQueue.main.async { completion(result) }
        }
    }
}

#endif
