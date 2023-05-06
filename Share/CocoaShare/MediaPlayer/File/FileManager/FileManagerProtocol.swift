//
//  FileManagerProtocol.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation

protocol FileManagerProtocol {
    
    /// 标题
    var desc: String { get }
    
    /// 地址栏描述
    var addressExampleDesc: String { get }
    
    /// 密码描述
    var passwordDesc: String { get }
    
    /// 是否需要输入用户名
    var isRequiredUserName: Bool { get }
    
    /// 获取目录
    func contentsOfDirectory(at directory: File, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void))
    
    /// 获取文件数据
    func getDataWithFile(_ file: File, range: ClosedRange<Int>?, progress: FileProgressAction?, completion: @escaping ((Result<Data, Error>) -> Void))
    
    /// 尝试连接
    func connectWithLoginInfo(_ loginInfo: LoginInfo, completionHandler: @escaping((Error?) -> Void))
    
    /// 删除文件
    func deleteFile(_ file: File, completionHandler: @escaping((Error?) -> Void))
    
    /// 打开文件管理器
    func pickFiles(_ directory: File?, from viewController: ANXViewController, filterType: URLFilterType?, completion: @escaping ((Result<[File], Error>) -> Void))
    
    /// 获取某个视频关联的字幕
    func subtitlesOfMedia(_ file: File, completion: @escaping ((Result<[File], Error>) -> Void))
    
    /// 获取某个视频关联的弹幕
    func danmakusOfMedia(_ file: File, completion: @escaping ((Result<[File], Error>) -> Void))
}

extension FileManagerProtocol {
    
    var isRequiredUserName: Bool {
        return true
    }
    
    var passwordDesc: String {
        return NSLocalizedString("登录密码", comment: "")
    }
    
    func subtitlesOfMedia(_ file: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        if let directory = file.parentFile {
            self.contentsOfDirectory(at: directory, filterType: .subtitle) { result in
                switch result {
                case .success(let files):
                    let name = file.url.deletingPathExtension().lastPathComponent
                    let subtitleFiles = files.filter({ $0.url.lastPathComponent.contains(name) && ($0.type == .folder || $0.url.isSubtitleFile) })
                    completion(.success(subtitleFiles))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success([]))
        }
    }

    func danmakusOfMedia(_ file: File, completion: @escaping ((Result<[File], Error>) -> Void)) {
        if let directory = file.parentFile {
            self.contentsOfDirectory(at: directory, filterType: .danmaku) { result in
                switch result {
                case .success(let files):
                    let name = file.url.deletingPathExtension().lastPathComponent
                    let danmakuFiles = files.filter({ $0.url.lastPathComponent.contains(name) && ($0.type == .folder || $0.url.isDanmakuFile) })
                    completion(.success(danmakuFiles))
                case .failure(let error):
                    completion(.failure(error))
                }
            }
        } else {
            completion(.success([]))
        }
    }

}
