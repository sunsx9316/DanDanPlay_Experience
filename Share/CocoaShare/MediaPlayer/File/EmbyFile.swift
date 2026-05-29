//
//  EmbyFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

#if os(iOS) || os(tvOS)

import Foundation
import MPVFramework
#if os(iOS)
import MobileVLCKit
#elseif os(tvOS)
import TVVLCKit
#endif

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
        guard let type = embyItem?.type else { return "" }
        switch type {
        case "Movie": return "电影"
        case "Episode": return "剧集"
        case "Series": return "系列"
        case "Season": return "季"
        case "Video": return "视频"
        case "Audio": return "音频"
        default: return String(type.prefix(4)).uppercased()
        }
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
}

#endif
