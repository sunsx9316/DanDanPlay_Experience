//
//  HttpServer.swift
//  AniXPlayer
//
//  tvOS WiFi 文件传输 HTTP 服务器
//

import Foundation
import GCDWebServer
import ANXLog

protocol HttpServerDelegate: AnyObject {
    func httpServer(_ httpServer: HttpServer, didReceiveFileAtPath path: String, folderName: String?, totalFiles: Int?)
    func httpServerDidStart(_ httpServer: HttpServer)
}

class HttpServer {

    private lazy var svr: GCDWebServer = {
        let svr = GCDWebServer()

        svr.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self, asyncProcessBlock: { _, completion in
            completion(Self.webPageResponse())
        })

        svr.addHandler(forMethod: "GET", path: "/upload.js", request: GCDWebServerRequest.self, asyncProcessBlock: { _, completion in
            completion(Self.jsResponse())
        })

        svr.addHandler(forMethod: "POST", path: "/upload", request: GCDWebServerMultiPartFormRequest.self, asyncProcessBlock: { [weak self] request, completion in
            guard let self = self else {
                completion(GCDWebServerDataResponse(statusCode: 500))
                return
            }

            guard let multipartRequest = request as? GCDWebServerMultiPartFormRequest else {
                ANX.logInfo(.HTTP, "上传请求无法解析为 multipart")
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            ANX.logInfo(.HTTP, "收到上传请求, files: \(multipartRequest.files.count)")

            if multipartRequest.files.count == 0 {
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            let fileManager = FileManager.default
            let destDir = PathUtils.documentsURL.path

            var savedFiles: [[String: Any]] = []

            let relativePath = multipartRequest.firstArgument(forControlName: "path")?.string ?? ""

            let folderName: String? = {
                let trimmed = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !trimmed.isEmpty else { return nil }
                let components = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
                return components.first.map(String.init)
            }()

            let totalFiles: Int? = {
                guard let str = multipartRequest.firstArgument(forControlName: "total")?.string,
                      let n = Int(str) else { return nil }
                return n
            }()

            for file in multipartRequest.files {
                let fileName = (file.fileName as NSString).lastPathComponent
                guard !fileName.isEmpty else { continue }

                let tempPath = file.temporaryPath
                guard fileManager.fileExists(atPath: tempPath) else { continue }

                let subDir: String
                let relPath = (relativePath as NSString)
                if relPath.length > 0 {
                    let dirPart = relPath.deletingLastPathComponent
                    if !dirPart.isEmpty && dirPart != "." {
                        subDir = dirPart
                    } else {
                        subDir = ""
                    }
                } else {
                    subDir = ""
                }

                var targetDir = destDir
                if !subDir.isEmpty {
                    targetDir = (destDir as NSString).appendingPathComponent(subDir)
                    do {
                        try fileManager.createDirectory(atPath: targetDir, withIntermediateDirectories: true, attributes: nil)
                    } catch {
                        ANX.logInfo(.HTTP, "创建目录失败: \(error)")
                        continue
                    }
                }

                let destPath = (targetDir as NSString).appendingPathComponent(fileName)

                var finalPath = destPath
                var counter = 1
                let baseName = (fileName as NSString).deletingPathExtension
                let ext = (fileName as NSString).pathExtension
                while fileManager.fileExists(atPath: finalPath) {
                    if ext.isEmpty {
                        finalPath = (targetDir as NSString).appendingPathComponent("\(baseName) (\(counter))")
                    } else {
                        finalPath = (targetDir as NSString).appendingPathComponent("\(baseName) (\(counter)).\(ext)")
                    }
                    counter += 1
                }

                do {
                    let tempData = try Data(contentsOf: URL(fileURLWithPath: tempPath))
                    try tempData.write(to: URL(fileURLWithPath: finalPath))
                    let fileSize = UInt64(tempData.count)

                    savedFiles.append([
                        "name": fileName,
                        "size": fileSize
                    ])

                    DispatchQueue.main.async {
                        self.delegate?.httpServer(self, didReceiveFileAtPath: finalPath, folderName: folderName, totalFiles: totalFiles)
                    }
                } catch {
                    ANX.logInfo(.HTTP, "保存文件失败: \(error)")
                }
            }

            let responseDict: [String: Any] = [
                "success": true,
                "files": savedFiles
            ]
            let responseData = try? JSONSerialization.data(withJSONObject: responseDict, options: [])
            completion(GCDWebServerDataResponse(data: responseData ?? Data(), contentType: "application/json"))
        })

        return svr
    }()

    var serverURL: URL? {
        return self.svr.serverURL
    }

    weak var delegate: HttpServerDelegate?

    private var isRunning = false

    func start() {
        guard !isRunning else { return }
        self.svr.start(withPort: 2333, bonjourName: nil)
        isRunning = true
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.httpServerDidStart(self)
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        self.svr.stop()
    }

    deinit {
        if isRunning {
            self.svr.stop()
        }
    }

    // MARK: - Web Resources

    private static func webPageResponse() -> GCDWebServerResponse? {
        guard let url = Bundle.main.url(forResource: "upload", withExtension: "html"),
              let html = try? String(contentsOf: url, encoding: .utf8) else {
            return GCDWebServerDataResponse(html: "<h1>页面加载失败</h1>")
        }

        let appName = Bundle.main.infoDictionary?["CFBundleDisplayName"] as? String
            ?? Bundle.main.infoDictionary?["CFBundleName"] as? String
            ?? "AniXPlayer"
        let themeHex = String(format: "#%06X", ANXColor.mainColor.anxRgbValue)
        let lang: String
        switch Preferences.shared.appLanguage {
        case .english:
            lang = "en"
        case .chinese:
            lang = "zh-Hans"
        }

        let configScript = """
        <script>
        window.__ANIX_CONFIG__ = {
            appName: "\(appName)",
            themeColor: "\(themeHex)",
            lang: "\(lang)",
            strings: {
                title: "\(NSLocalizedString("WiFi 文件传输", comment: ""))",
                dropTitle: "\(NSLocalizedString("拖拽文件或文件夹到此处上传", comment: ""))",
                dropSubtitle: "\(NSLocalizedString("支持所有文件类型，单个文件最大 2GB", comment: ""))",
                browseFile: "\(NSLocalizedString("选择文件", comment: ""))",
                browseFolder: "\(NSLocalizedString("选择文件夹", comment: ""))",
                complete: "\(NSLocalizedString("完成", comment: ""))",
                files: "\(NSLocalizedString("个文件", comment: ""))",
                serverError: "\(NSLocalizedString("服务器错误", comment: ""))",
                networkError: "\(NSLocalizedString("网络错误", comment: ""))"
            }
        };
        </script>
        """
        let result = html.replacingOccurrences(of: "<!-- CONFIG_PLACEHOLDER -->", with: configScript)
        return GCDWebServerDataResponse(html: result)
    }

    private static func jsResponse() -> GCDWebServerResponse? {
        guard let url = Bundle.main.url(forResource: "upload", withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else {
            return GCDWebServerDataResponse(statusCode: 404)
        }
        return GCDWebServerDataResponse(data: (js.data(using: .utf8) ?? Data()), contentType: "application/javascript")
    }
}
