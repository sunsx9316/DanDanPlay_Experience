import YYCategories
//
//  EmbyFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

#if os(iOS) || os(tvOS)

import Foundation
import VLCKit
import MPVFramework

class EmbyFile: File {

    var url: URL

    var fileSize: Int

    var type: FileType

    var fileName: String

    var subtitle: String = ""

    var coverImageURL: URL? {
        return EmbyFileManager.shared.coverImageURL(for: self.embyItem)
    }

    static var fileManager: FileManagerProtocol = EmbyFileManager.shared

    static var rootFile: File = EmbyFile(rootFileURL: URL(fileURLWithPath: "/"))

    var parentFile: File?

    let embyItem: EmbyItem?

    private(set) var streamURL: URL

    var isCanDelete: Bool { return false }

    var pathExtension: String {
        guard let item = embyItem else { return "" }
        // 非文件夹优先使用源文件真实扩展名
        if !item.isFolder, let path = item.path {
            let ext = (path as NSString).pathExtension
            if !ext.isEmpty { return ext }
        }
        // 文件夹或无路径时回退到类型标签
        switch item.type {
        case "Movie": return "电影"
        case "Episode": return "剧集"
        case "Series": return "系列"
        case "Season": return "季"
        case "Video": return "视频"
        case "Audio": return "音频"
        default: return String(item.type.prefix(4)).uppercased()
        }
    }

    var sourceFileName: String? {
        guard let path = embyItem?.path else { return nil }
        return (path as NSString).lastPathComponent
    }

    var fileId: String {
        return embyItem?.id ?? url.absoluteString
    }

    // MARK: - Init

    private init(rootFileURL: URL) {
        self.url = rootFileURL
        self.fileSize = 0
        self.type = .folder
        self.fileName = ""
        self.embyItem = nil
        self.streamURL = rootFileURL
    }

    init(item: EmbyItem) {
        self.embyItem = item
        self.fileName = item.name
        self.type = item.isFolder ? .folder : .file
        self.fileSize = Int(item.size ?? 0)
        self.url = URL(string: "emby://\(item.id)") ?? URL(fileURLWithPath: "/")
        self.streamURL = EmbyFileManager.shared.streamURL(for: item.id)

        if !item.isFolder {
            let parts: [String] = [
                item.seriesName,
                item.seasonName,
                item.indexNumber.map { "第\($0)集" }
            ].compactMap { $0 }
            self.subtitle = parts.isEmpty ? "" : parts.joined(separator: " - ")
        }
    }

    // MARK: - Sort

    func sortCompare(to other: any File, option: FileSortOption, ascending: Bool) -> Bool {
        if option == .fileType {
            if self.type == .folder && other.type != .folder { return ascending }
            if self.type != .folder && other.type == .folder { return !ascending }
        } else {
            if self.type == .folder && other.type != .folder { return true }
            if self.type != .folder && other.type == .folder { return false }
        }

        let result: Bool
        switch option {
        case .default, .episodeNumber:
            let epA = self.embyItem?.indexNumber ?? Int.max
            let epB = (other as? EmbyFile)?.embyItem?.indexNumber ?? Int.max
            if epA != epB {
                result = epA < epB
            } else {
                let pathA = self.embyItem?.path ?? ""
                let pathB = (other as? EmbyFile)?.embyItem?.path ?? ""
                if !pathA.isEmpty || !pathB.isEmpty {
                    result = pathA < pathB
                } else {
                    result = self.fileName.localizedStandardCompare(other.fileName) == .orderedAscending
                }
            }
        case .fileName:
            result = self.fileName.localizedStandardCompare(other.fileName) == .orderedAscending
        case .path:
            let pathA = self.embyItem?.path ?? ""
            let pathB = (other as? EmbyFile)?.embyItem?.path ?? ""
            if !pathA.isEmpty || !pathB.isEmpty {
                result = pathA < pathB
            } else {
                result = self.fileName.localizedStandardCompare(other.fileName) == .orderedAscending
            }
        case .fileType:
            result = self.fileName.localizedStandardCompare(other.fileName) == .orderedAscending
        }
        return ascending ? result : !result
    }

    // MARK: - Media

    func createVLCMedia(delegate: FileDelegate) -> VLCMedia? {
        return VLCMedia(url: streamURL)
    }

    #if os(iOS) || os(tvOS)
    func createMPVMedia() -> MPVMedia? {
        return MPVMedia(url: streamURL)
    }
    #endif

    func getFileHashWithProgress(_ progress: FileProgressAction?,
                                 completion: @escaping ((Result<String, Error>) -> Void)) {
        let length = parseFileLength
        self.getDataWithRange(0...length, progress: progress, completion: { result in
            switch result {
            case .success(let data):
                let hash = (data as NSData).md5String()
                completion(.success(hash))
            case .failure(let error):
                completion(.failure(error))
            }
        })
    }

    // MARK: - Subtitle File

    class EmbySubtitleFile: File {

        var url: URL
        var fileSize: Int = 0
        var type: FileType = .file
        var fileName: String
        var subtitle: String = ""
        var parentFile: File?
        var isCanDelete: Bool { false }
        var coverImageURL: URL? { nil }
        var sourceFileName: String? {
            streamPath.flatMap { ($0 as NSString).lastPathComponent }
        }

        static var fileManager: FileManagerProtocol { EmbyFileManager.shared }
        static var rootFile: File {
            EmbyFile(rootFileURL: URL(fileURLWithPath: "/"))
        }

        var fileId: String {
            return "emby_sub_\(itemId)_\(String(mediaSourceId.prefix(8)))_\(streamIndex)"
        }

        let streamIndex: Int
        let itemId: String
        let mediaSourceId: String
        let deliveryUrl: String?
        let codec: String
        let streamPath: String?

        init(itemId: String, mediaSourceId: String, stream: EmbyMediaStream) {
            self.itemId = itemId
            self.mediaSourceId = mediaSourceId
            self.streamIndex = stream.index
            self.deliveryUrl = stream.deliveryUrl
            self.codec = stream.codec ?? ""
            self.streamPath = stream.path

            let ext = stream.fileExtension
            let safeName = stream.displayTitle ?? stream.path ?? "track_\(stream.index)"
            let urlStr = "emby-sub://\(itemId)/\(mediaSourceId)/\(stream.index)/\(safeName).\(ext)"
            self.url = URL(string: urlStr) ?? URL(fileURLWithPath: "/")

            self.fileName = stream.displayTitle
                ?? (stream.path.flatMap { ($0 as NSString).lastPathComponent })
                ?? "\(stream.codec ?? "")_\(stream.index)"
        }

        func getDataWithRange(_ range: ClosedRange<Int>, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
            EmbyFileManager.shared.getSubtitleData(self, completion: completion)
        }

        func getFileHashWithProgress(_ progress: FileProgressAction?, completion: @escaping ((Result<String, Error>) -> Void)) {
            EmbyFileManager.shared.getSubtitleData(self) { result in
                switch result {
                case .success(let data):
                    let hash = (data as NSData).md5String()
                    completion(.success(hash))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        }

        func createVLCMedia(delegate: FileDelegate) -> VLCMedia? { nil }

        #if os(iOS) || os(tvOS)
        func createMPVMedia() -> MPVMedia? { nil }
        #endif
    }

}

#endif
