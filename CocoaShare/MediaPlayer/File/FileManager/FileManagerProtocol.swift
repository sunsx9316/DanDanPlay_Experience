//
//  FileManagerProtocol.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation

protocol FileManagerProtocol {
    
    var desc: String { get }
    
    var addressExampleDesc: String { get }
    
    func contentsOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void))
    
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void))
    
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void))
}

extension FileManagerProtocol {
    
    func subtitlesOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        self.contentsOfDirectory(at: directory) { result in
            switch result {
            case .success(let files):
                completion(.success(files.filter({ $0.url.isSubtitleFile })))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
    
    func danmakusOfDirectory(at directory: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        self.contentsOfDirectory(at: directory) { result in
            switch result {
            case .success(let files):
                completion(.success(files.filter({ $0.url.isDanmakuFile })))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }
}
