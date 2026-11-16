//
//  OnlineEpisodeFile.swift
//  AniXPlayer
//
//  macOS：在线剧集 / 网络串流的 File 封装。
//
//  - `url` 使用稳定的 anix-online:// 虚拟地址，避免多集共用 index.m3u8 时 fileId 碰撞；
//  - 真正交给 VLC/MPV 的是 `streamURL`；
//  - 请求头通过 File.httpHeaders 注入（VLCMedia options / MPV http-header-fields）；
//  - 不做文件哈希匹配；在线剧集后续用「作品名 + 剧集名」虚拟文件名匹配弹幕。
//

import Foundation
import VLCKit
import MPVFramework

final class OnlineEpisodeFile: File {

    static var fileManager: FileManagerProtocol {
        LocalFileManager.shared
    }

    static var rootFile: File {
        OnlineEpisodeFile(
            streamURL: URL(string: "https://invalid.local/online-stream.mp4")!,
            displayName: "在线视频",
            headers: [:],
            pageURL: nil,
            sourceName: nil
        )
    }

    let type: FileType = .file
    let url: URL
    let streamURL: URL
    let fileSize: Int = 0
    let fileId: String
    let fileName: String
    let httpHeaders: [String: String]
    let pageURL: URL?
    let sourceName: String?

    init(
        streamURL: URL,
        displayName: String,
        headers: [String: String] = [:],
        pageURL: URL? = nil,
        sourceName: String? = nil
    ) {
        self.streamURL = streamURL
        self.httpHeaders = headers
        self.pageURL = pageURL
        self.sourceName = sourceName

        let cleanedName = displayName.trimmingCharacters(in: .whitespacesAndNewlines)
        let baseName = cleanedName.isEmpty ? "在线视频" : cleanedName
        // 在线播放器标题/弹幕匹配使用虚拟 .mp4 名（对齐 Windows 版）；
        // 真实流扩展名仍由 pathExtension 通过 streamURL 提供。
        self.fileName = (baseName as NSString).pathExtension.isEmpty
            ? "\(baseName).mp4"
            : baseName

        let stableKey = "\(sourceName ?? "online")|\(pageURL?.absoluteString ?? streamURL.absoluteString)"
        let hash = (stableKey as NSString).md5() ?? UUID().uuidString
        self.fileId = hash
        self.url = URL(string: "anix-online://\(hash)") ?? streamURL
    }

    var parentFile: File? { nil }

    var isCanDelete: Bool { false }

    var isVirtualFile: Bool { true }

    var danmakuMatchFileName: String? {
        return (fileName as NSString).deletingPathExtension
    }

    var pathExtension: String {
        streamURL.pathExtension.uppercased()
    }

    func getFileHashWithProgress(
        _ progress: FileProgressAction?,
        completion: @escaping ((Result<String, Error>) -> Void)
    ) {
        // 在线流不读取文件哈希；调用方应回退到虚拟文件名匹配。
        completion(.failure(Self.hashUnsupportedError))
    }

    func getDataWithRange(
        _ range: ClosedRange<Int>,
        progress: FileProgressAction?,
        completion: @escaping ((Result<Data, Error>) -> Void)
    ) {
        var request = URLRequest(url: streamURL)
        request.setValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
        for (key, value) in httpHeaders {
            request.setValue(value, forHTTPHeaderField: key)
        }

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error = error {
                completion(.failure(error))
                return
            }
            guard let data = data else {
                completion(.failure(Self.hashUnsupportedError))
                return
            }
            progress?(1)
            completion(.success(data))
        }.resume()
    }

    func createVLCMedia(delegate: FileDelegate) -> VLCMedia? {
        let media = VLCMedia(url: streamURL)
        var options: [AnyHashable: Any] = [:]
        for (key, value) in httpHeaders {
            switch key.lowercased() {
            case "referer":
                options["http-referrer"] = value
            case "user-agent":
                options["http-user-agent"] = value
            case "cookie":
                options["http-cookie"] = value
            default:
                break
            }
        }
        if !options.isEmpty {
            media?.addOptions(options)
        }
        return media
    }

    func createMPVMedia() -> MPVMedia? {
        return MPVMedia(url: streamURL)
    }

    func sortCompare(to other: any File, option: FileSortOption, ascending: Bool) -> Bool {
        let result = fileName.localizedStandardCompare(other.fileName) == .orderedAscending
        return ascending ? result : !result
    }

    private static let hashUnsupportedError = NSError(
        domain: "AniXPlayer.OnlineEpisodeFile",
        code: -1,
        userInfo: [
            NSLocalizedDescriptionKey: NSLocalizedString("在线视频不提供文件哈希", comment: "")
        ]
    )
}
