//
//  FileManagerProtocol.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation

protocol FileManagerProtocol {
    var desc: String { get }
    func contentsOfDirectory(at url: URL, completion: @escaping (([File]) -> Void))
}

//public extension FileManagerProtocol {
//    func subtitlesOfDirectory(at url: URL, completion: @escaping (([File]) -> Void)) {
//        contentsOfDirectory(at: url, filter: { (aURL) -> Bool in
//            return aURL.isSubtitleFile
//        }, completion: completion)
//    }
//
//    func danmakusOfDirectory(at url: URL, completion: @escaping (([File]) -> Void)) {
//        contentsOfDirectory(at: url, filter: { (aURL) -> Bool in
//            return aURL.isDanmakuFile
//        }, completion: completion)
//    }
//
//    func contentsOfDirectory(at url: URL, completion: @escaping (([File]) -> Void)) {
//        contentsOfDirectory(at: url, filter: { (aURL) -> Bool in
//            return true
//        }, completion: completion)
//    }
//}
