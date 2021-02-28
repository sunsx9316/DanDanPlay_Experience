//
//  WebDavFileManager.swift
//  DDPMediaPlayer
//
//  Created by jimhuang on 2021/2/17.
//

import Foundation
//import GCDWebServer

//extension WebDavFileManager: URLSessionDataDelegate {
//
//    public func urlSession(_ session: URLSession, task: URLSessionTask, didReceive challenge: URLAuthenticationChallenge, completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
//
//        if challenge.previousFailureCount > 0 {
//            completionHandler(.cancelAuthenticationChallenge, nil)
//        } else {
//            if let name = self.user, let password = self.password {
//                let credential = URLCredential(user: name, password: password, persistence: .forSession)
//                completionHandler(.useCredential, credential)
//            } else {
//                completionHandler(.performDefaultHandling, nil)
//            }
//        }
//    }
//    
//}
//
//class WebDavFileManager: NSObject, FileManagerProtocol {
//    
//    public enum KeyName: String {
//        case url
//        case user = "web_dav_user"
//        case password = "web_dav_password"
//    }
//    
//    static let shared = LocalFileManager()
//    
//    var serverURL: URL? {
//        return self.webServer.serverURL
//    }
//    
//    func contentsOfDirectory(at url: URL, completion: @escaping (([File]) -> Void)) {
//        
//    }
//    
//    private lazy var session: URLSession = {
//        let session = URLSession(configuration: .default, delegate: self, delegateQueue: nil)
//        return session
//    }()
//    
//    private var progressObservation: Any?
//    
//    private lazy var webServer: GCDWebServer = {
//        let svr = GCDWebServer()
//        svr.addDefaultHandler(forMethod: "GET", request: GCDWebServerRequest.self) { (request, completion) in
//            if let encodeStr = request.query?[KeyName.url.rawValue],
//               let data = Data(base64Encoded: encodeStr) {
//                let urlString = String(data: data, encoding: .utf8)
//                
//                if let urlString = urlString, let url = URL(string: urlString) {
//                    var req = URLRequest(url: url)
//                    req.httpMethod = request.method
//                    for (key, value) in request.headers {
//                        req.addValue(value, forHTTPHeaderField: key)
//                    }
//                    
//                    let task = self.session.dataTask(with: req) { (data, res, err) in
//                        if let data = data, let res = res as? HTTPURLResponse {
//                            let response = GCDWebServerDataResponse(data: data, contentType: res.mimeType ?? "")
//                            completion(response)
//                        } else if let err = err as NSError? {
//                            let response = GCDWebServerDataResponse(statusCode: err.code)
//                            completion(response)
//                        } else {
//                            let response = GCDWebServerDataResponse(statusCode: -999)
//                            completion(response)
//                        }
//                    }
//                    
//                    if #available(iOS 11.0, OSX 10.13, *) {
//                        self.progressObservation = task.progress.observe(\.fractionCompleted) { [weak self] (progress, _) in
//                            guard let self = self else { return }
//                            
//                            self.progressHandle?(progress.fractionCompleted)
//                        }
//                    }
//                    
//                    task.resume()
//                }
//            }
//        }
//        
//        do {
//            var options = [String : Any]()
//            options[GCDWebServerOption_ConnectedStateCoalescingInterval] = NSNumber(value: true)
//            #if os(iOS)
//                options[GCDWebServerOption_AutomaticallySuspendInBackground] = NSNumber(value: false)
//            #endif
//            try svr.start(options: options)
//        } catch let error {
//            print("web svr开启失败 \(error)")
//        }
//        return svr
//    }()
//    
//    func getDataWithURL(_ url: URL,
//                        range: ClosedRange<Int>? = nil,
//                        progress: @escaping (FileProgressAction),
//                        completion: @escaping ((Result<Data, Error>) -> Void)) {
//        
//        var req = URLRequest(url: url)
//        req.httpMethod = "GET"
//        if let range = range {
//            req.addValue("bytes=\(range.lowerBound)-\(range.upperBound)", forHTTPHeaderField: "Range")
//        }
//        
//        let davTask = WebDavTask()
//        davTask.progressCallBack = progress
//        
//        
//        let task = self.session.dataTask(with: req) { (data, res, err) in
//            
//            progress(1)
//            
//            if let data = data {
//                completion(.success(data))
//            } else if let err = err as NSError? {
//                completion(.failure(err))
//            } else {
//                completion(.failure(WebDavError.unknowError))
//            }
//            
//            self.progressHandle = nil
//            self.progressObservation = nil
//        }
//        
//        task.resume()
//    }
//}
