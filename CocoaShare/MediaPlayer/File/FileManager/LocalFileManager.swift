//
//  LocalFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation

class LocalFileManager: FileManagerProtocol {
    
    var addressExampleDesc: String {
        return ""
    }
    
    var desc: String {
        return NSLocalizedString("本地文件", comment: "")
    }
    
    func contentsOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
            
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
    
}
