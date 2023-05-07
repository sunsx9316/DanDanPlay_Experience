//
//  PCFile.swift
//  AniXPlayer
//
//  Created by jimhuang on 2023/5/1.
//

import MobileVLCKit
import YYCategories

class PCFile: File {
    
    var url: URL
    
    var fileSize: Int
    
    var type: FileType
    
    var fileName: String
    
    static var fileManager: FileManagerProtocol = PCFileManager.shared
    
    static var rootFile: File = PCFile(rootFileURL: URL(fileURLWithPath: "/"))
    
    var parentFile: File?
    
    var animeId: Int
    
    var mediaId: String
    
    var subtitle: String = ""
    
    private var libraryModel: PCLibraryModel?
    
    private(set) var downloadURL: URL
    
    var isCanDelete: Bool {
        return false
    }
    
    private init(rootFileURL: URL) {
        self.url = rootFileURL
        self.fileSize = 0
        self.type = .folder
        self.fileName = ""
        self.downloadURL = URL(fileURLWithPath: "/")
        self.animeId = 0
        self.mediaId = ""
    }
    
    init(subtitleModel: PCSubtitleModel, media: PCFile) {
        
        self.mediaId = media.libraryModel?.id ?? ""
        self.animeId = media.libraryModel?.animeId ?? 0
        
        var url = PCFileManager.shared.loginInfo?.url
        url = url?.appendingPathComponent("/api/v1/subtitle/file/\(self.mediaId)")
        
        var playURLComponents = URLComponents(string: url?.absoluteString ?? "")
        playURLComponents?.queryItems = [.init(name: "fileName", value: subtitleModel.fileName)]
        
        self.url = playURLComponents?.url ?? URL(fileURLWithPath: "")
        self.fileSize = subtitleModel.fileSize
        self.type = .file
        self.fileName = subtitleModel.fileName
        self.downloadURL = self.url
    }
    
    init(animeId: Int, animeName: String) {
        self.url = URL(string: "anixpc://\(animeId)") ?? URL(fileURLWithPath: "/")
        self.type = .folder
        self.fileName = animeName
        self.downloadURL = self.url
        self.fileSize = 0
        self.animeId = animeId
        self.mediaId = ""
    }
    
    init(libraryModel: PCLibraryModel) {

        let path = PCFileManager.shared.loginInfo?.url.appendingPathComponent("/api/v1/stream/id/\(libraryModel.id)").absoluteString ?? ""
        
        var playURLComponents = URLComponents(string: path)
        var queryItems = [URLQueryItem]()
        if let token = PCFileManager.shared.loginInfo?.auth?.password, !token.isEmpty {
            queryItems.append(.init(name: "token", value: token))
        }
        playURLComponents?.queryItems = queryItems
        
        self.downloadURL = playURLComponents?.url ?? URL(fileURLWithPath: "/")
        
        let itemURLComponents = URLComponents(string: "anxpc://\(libraryModel.id)/\(libraryModel.name)")
        self.url = itemURLComponents?.url ?? URL(fileURLWithPath: "/")
        
        self.fileSize = libraryModel.size
        self.type = .file
        self.libraryModel = libraryModel
        self.fileName = self.libraryModel?.name ?? ""
        self.subtitle = self.libraryModel?.episodeTitle ?? ""
        
        self.mediaId = libraryModel.id
        self.animeId = libraryModel.animeId
    }
    
    
    func createMedia(delegate: FileDelegate) -> VLCMedia? {
        return .init(url: self.downloadURL)
    }

    func getFileHashWithProgress(_ progress: FileProgressAction?,
                                 completion: @escaping((Result<String, Error>) -> Void)) {
        
        let length = parseFileLength
        self.getDataWithRange(0...length, progress: progress) { result in
            switch result {
            case .success(let data):
                let hash = (data as NSData).md5String()
                completion(.success(hash))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
}
