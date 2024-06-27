//
//  LocalFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

#if os(iOS)
import UIKit
#else
import Cocoa
#endif

class LocalFileManager: FileManagerProtocol {
    
    static let shared = LocalFileManager()
    
    private init() {}
    
    private enum LocalError: LocalizedError {
        case fileTypeError
        
        case pickFileTypeError
        
        var errorDescription: String? {
            switch self {
            case .fileTypeError:
                return "文件类型错误"
            case .pickFileTypeError:
                return "选择文件失败"
            }
        }
    }
    
    var addressExampleDesc: String {
        return ""
    }
    
    var desc: String {
        return NSLocalizedString("本地文件", comment: "")
    }
    
    func contentsOfDirectory(at directory: File, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
        do {
            
            let url = directory.url
            let urls = try FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil, options: .skipsHiddenFiles)
            
            var storePath: String? = nil
            
            if let path = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true).first {
                storePath = path + "/mmkv/"
            }
            
            let files = urls.compactMap { (aURL) -> LocalFile? in
                if let storePath = storePath, aURL.absoluteString.hasSuffix(storePath) {
                    return nil
                }
                
                let file = LocalFile(with: aURL)
                if let filterType = filterType, file.type == .file {
                    return file.url.isThisType(filterType) ? file : nil
                }
                return file
            }
            completion(.success(files))
        } catch let error {
            debugPrint("读取文件出错: \(error)")
            completion(.failure(error))
        }
    }
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void)) {
        
        do {
            let url = file.url
            
            let fileHandle = try FileHandle(forReadingFrom: url)
            if let range = range {
                let length = range.upperBound - range.lowerBound
                fileHandle.seek(toFileOffset: UInt64(range.lowerBound))
                let allData = fileHandle.readData(ofLength: length)
                
                progress?(1)
                completion(.success(allData))
            } else {
                let allData = fileHandle.readDataToEndOfFile()
                
                progress?(1)
                completion(.success(allData))
            }
        } catch let error {
            progress?(1)
            completion(.failure(error))
        }
    }
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping ((Error?) -> Void)) {
        completionHandler(nil)
    }
    
    func deleteFile(_ file: File, completionHandler: @escaping ((Error?) -> Void)) {
        
        guard file.isCanDelete else {
            assert(false, "文件类型错误: \(file)")
            completionHandler(LocalError.fileTypeError)
            return
        }
        
        var error: Error?
        do {
            try FileManager.default.removeItem(at: file.url)
        } catch let err {
            error = err
        }
        
        completionHandler(error)
    }
    
    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void)) {
#if os(iOS)
        
#else
        guard let window = viewController.view.window else { return }
        
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.directoryURL = directory?.url
        panel.beginSheetModal(for: window) { [weak self] res in
            guard let self = self else { return }
            
            if res != .OK {
                completion(.failure(LocalError.pickFileTypeError))
                return
            }
            
            var files = [File]()
            var directorys = [File]()
            for file in panel.urls.compactMap({ LocalFile(with: $0) }) {
                if file.type == .folder {
                    directorys.append(file)
                } else {
                    files.append(file)
                }
            }
            
            let group = DispatchGroup()
            for file in directorys {
                group.enter()
                self.contentsOfDirectory(at: file, filterType: filterType) { result in
                    switch result {
                    case .success(let f1):
                        files.append(contentsOf: f1)
                    case .failure(_):
                        break
                    }
                    
                    group.leave()
                }
            }
            
            _ = group.wait(timeout: .distantFuture)
            
            let results: [File]
            if let filterType = filterType {
                results = files.filter({ $0.url.isThisType(filterType) }).sorted { (f1, f2) -> Bool in
                    return f1.url.path.compare(f2.url.path) == .orderedAscending
                }
            } else {
                results = files.sorted { (f1, f2) -> Bool in
                    return f1.url.path.compare(f2.url.path) == .orderedAscending
                }
            }
            
            completion(.success(results))
        }
        
#endif
    }
    
}
