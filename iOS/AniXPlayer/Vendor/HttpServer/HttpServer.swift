//
//  HttpServer.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/9.
//

import Foundation
import GCDWebServer
import ANXLog

protocol HttpServerDelegate: AnyObject {
    func httpServer(_ httpServer: HttpServer, didReceiveFileAtPath path: String, folderName: String?, totalFiles: Int?)
    func httpServerDidStart(_ httpServer: HttpServer)
}

class HttpServer {

    private var documentsDirectory: String {
        return UIApplication.shared.documentsPath
    }

    private lazy var svr: GCDWebServer = {
        let svr = GCDWebServer()

        // 首页
        svr.addHandler(forMethod: "GET", path: "/", request: GCDWebServerRequest.self, asyncProcessBlock: { _, completion in
            completion(Self.webPageResponse())
        })

        // upload.js
        svr.addHandler(forMethod: "GET", path: "/upload.js", request: GCDWebServerRequest.self, asyncProcessBlock: { _, completion in
            completion(Self.jsResponse())
        })

        // fileManager.js
        svr.addHandler(forMethod: "GET", path: "/fileManager.js", request: GCDWebServerRequest.self, asyncProcessBlock: { _, completion in
            completion(Self.fileManagerJsResponse())
        })

        // 文件上传
        svr.addHandler(forMethod: "POST", path: "/upload", request: GCDWebServerMultiPartFormRequest.self, asyncProcessBlock: { [weak self] request, completion in
            guard let self = self else {
                completion(GCDWebServerDataResponse(statusCode: 500))
                return
            }

            guard let multipartRequest = request as? GCDWebServerMultiPartFormRequest else {
                ANX.logInfo(.HTTP, "上传请求无法解析为 multipart: contentType=\(request.contentType ?? "nil")")
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            ANX.logInfo(.HTTP, "收到上传请求, files: \(multipartRequest.files.count), contentType: \(request.contentType ?? "nil")")

            if multipartRequest.files.count == 0 {
                ANX.logInfo(.HTTP, "上传请求中没有文件")
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            let fileManager = FileManager.default
            let destDir = self.documentsDirectory

            var savedFiles: [[String: Any]] = []

            // 获取相对路径（上传文件夹时保留目录结构）
            let relativePath = multipartRequest.firstArgument(forControlName: "path")?.string ?? ""

            // 从路径中提取根文件夹名
            let folderName: String? = {
                let trimmed = relativePath.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
                guard !trimmed.isEmpty else { return nil }
                let components = trimmed.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: true)
                return components.first.map(String.init)
            }()

            // 文件夹总文件数（用于进度展示）
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

                // 从 relativePath 提取目录部分（去掉末尾的文件名）
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

                ANX.logInfo(.HTTP, "上传文件: fileName=\(fileName), relativePath=\(relativePath), subDir=\(subDir)")

                // 如有子目录则创建
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

                // 处理同名文件
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

        // 文件列表
        svr.addHandler(forMethod: "GET", path: "/api/files", request: GCDWebServerRequest.self, asyncProcessBlock: { [weak self] request, completion in
            guard let self = self else {
                completion(GCDWebServerDataResponse(statusCode: 500))
                return
            }

            let rawPath = request.query?["path"] ?? "/"
            let safePath = self.sanitizePath(rawPath)

            guard let listing = self.listDirectory(at: safePath) else {
                let resp: [String: Any] = ["success": false, "error": "无法访问目录"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
                return
            }

            let resp: [String: Any] = [
                "success": true,
                "path": rawPath.hasPrefix("/") ? rawPath : "/" + rawPath,
                "files": listing
            ]
            let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
            completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
        })

        // 新建文件夹
        svr.addHandler(forMethod: "POST", path: "/api/mkdir", request: GCDWebServerDataRequest.self, asyncProcessBlock: { [weak self] request, completion in
            guard let self = self,
                  let dataRequest = request as? GCDWebServerDataRequest,
                  let body = try? JSONSerialization.jsonObject(with: dataRequest.data, options: []) as? [String: String] else {
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            let parentPath = self.sanitizePath(body["path"] ?? "/")
            guard let name = body["name"]?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
                let resp: [String: Any] = ["success": false, "error": "文件夹名称为空"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
                return
            }

            let newDir = (parentPath as NSString).appendingPathComponent(name)

            do {
                try FileManager.default.createDirectory(atPath: newDir, withIntermediateDirectories: false, attributes: nil)
                let resp: [String: Any] = ["success": true]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
            } catch {
                let resp: [String: Any] = ["success": false, "error": "创建失败: \(error.localizedDescription)"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
            }
        })

        // 重命名
        svr.addHandler(forMethod: "POST", path: "/api/rename", request: GCDWebServerDataRequest.self, asyncProcessBlock: { [weak self] request, completion in
            guard let self = self,
                  let dataRequest = request as? GCDWebServerDataRequest,
                  let body = try? JSONSerialization.jsonObject(with: dataRequest.data, options: []) as? [String: String] else {
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            let oldPath = self.sanitizePath(body["path"] ?? "")
            guard let newName = body["newName"]?.trimmingCharacters(in: .whitespacesAndNewlines), !newName.isEmpty else {
                let resp: [String: Any] = ["success": false, "error": "名称为空"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
                return
            }

            let dir = (oldPath as NSString).deletingLastPathComponent
            let newPath = (dir as NSString).appendingPathComponent(newName)

            guard oldPath != self.documentsDirectory else {
                let resp: [String: Any] = ["success": false, "error": "不能重命名根目录"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
                return
            }

            do {
                try FileManager.default.moveItem(atPath: oldPath, toPath: newPath)
                let resp: [String: Any] = ["success": true]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
            } catch {
                let resp: [String: Any] = ["success": false, "error": "重命名失败: \(error.localizedDescription)"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
            }
        })

        // 删除
        svr.addHandler(forMethod: "POST", path: "/api/delete", request: GCDWebServerDataRequest.self, asyncProcessBlock: { [weak self] request, completion in
            guard let self = self,
                  let dataRequest = request as? GCDWebServerDataRequest,
                  let body = try? JSONSerialization.jsonObject(with: dataRequest.data, options: []) as? [String: String] else {
                completion(GCDWebServerDataResponse(statusCode: 400))
                return
            }

            let targetPath = self.sanitizePath(body["path"] ?? "")

            guard targetPath != self.documentsDirectory else {
                let resp: [String: Any] = ["success": false, "error": "不能删除根目录"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
                return
            }

            do {
                try FileManager.default.removeItem(atPath: targetPath)
                let resp: [String: Any] = ["success": true]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
            } catch {
                let resp: [String: Any] = ["success": false, "error": "删除失败: \(error.localizedDescription)"]
                let data = try? JSONSerialization.data(withJSONObject: resp, options: [])
                completion(GCDWebServerDataResponse(data: data ?? Data(), contentType: "application/json"))
            }
        })

        return svr
    }()

    var serverURL: URL? {
        return self.svr.serverURL
    }

    weak var delegate: HttpServerDelegate?

    func start() {
        self.svr.start(withPort: 2333, bonjourName: nil)
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.delegate?.httpServerDidStart(self)
        }
    }

    func stop() {
        self.svr.stop()
    }

    deinit {
        self.stop()
    }

    // MARK: - Path & File Helpers

    /// 将相对路径转为 Documents 下的绝对路径，防止目录穿越
    private func sanitizePath(_ path: String) -> String {
        let base = (documentsDirectory as NSString).standardizingPath
        var normalized = path

        // 统一用 / 作为分隔符
        if !normalized.hasPrefix("/") {
            normalized = "/" + normalized
        }

        let full = (base + normalized)
        let standardized = (full as NSString).standardizingPath

        // 禁止访问 Documents 之外的路径
        guard standardized.hasPrefix(base) else {
            return base
        }

        return standardized
    }

    /// 列出目录内容，返回 JSON 友好的文件列表；失败返回 nil
    /// 需要隐藏的目录名（如日志目录）
    private var hiddenDirectoryNames: Set<String> {
        let logName = (ANXLogHelper.logPath() as NSString).lastPathComponent
        return [logName]
    }

    private func listDirectory(at path: String) -> [[String: Any]]? {
        let fm = FileManager.default
        var isDir: ObjCBool = false
        guard fm.fileExists(atPath: path, isDirectory: &isDir), isDir.boolValue else {
            return nil
        }

        guard let contents = try? fm.contentsOfDirectory(atPath: path) else {
            return nil
        }

        var items: [[String: Any]] = []

        for name in contents {
            if hiddenDirectoryNames.contains(name) {
                continue
            }

            let full = (path as NSString).appendingPathComponent(name)
            guard let attrs = try? fm.attributesOfItem(atPath: full) else { continue }

            let fileType = attrs[.type] as? String
            let isDir = (fileType == FileAttributeType.typeDirectory.rawValue)
            let size = (attrs[.size] as? UInt64) ?? 0
            let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0

            items.append([
                "name": name,
                "size": size,
                "isDirectory": isDir,
                "modified": modified
            ])
        }

        // 目录在前，文件在后，各自按名称排序
        items.sort { a, b in
            let aIsDir = (a["isDirectory"] as? Bool) ?? false
            let bIsDir = (b["isDirectory"] as? Bool) ?? false
            if aIsDir != bIsDir { return aIsDir }
            let aName = (a["name"] as? String) ?? ""
            let bName = (b["name"] as? String) ?? ""
            return aName.localizedCaseInsensitiveCompare(bName) == .orderedAscending
        }

        return items
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
        let themeHex = String(format: "#%06X", UIColor.mainColor.anxRgbValue)
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
                complete: "\(NSLocalizedString("完成", comment: ""))",
                files: "\(NSLocalizedString("个文件", comment: ""))",
                serverError: "\(NSLocalizedString("服务器错误", comment: ""))",
                networkError: "\(NSLocalizedString("网络错误", comment: ""))",
                newFolder: "\(NSLocalizedString("新建文件夹", comment: ""))",
                folderName: "\(NSLocalizedString("文件夹名称", comment: ""))",
                create: "\(NSLocalizedString("创建", comment: ""))",
                rename: "\(NSLocalizedString("重命名", comment: ""))",
                delete: "\(NSLocalizedString("删除", comment: ""))",
                confirm: "\(NSLocalizedString("确认", comment: ""))",
                cancel: "\(NSLocalizedString("取消", comment: ""))",
                folder: "\(NSLocalizedString("文件夹", comment: ""))",
                emptyDir: "\(NSLocalizedString("此目录为空", comment: ""))",
                deleteConfirm: "\(NSLocalizedString("确定要删除", comment: ""))",
                loadError: "\(NSLocalizedString("加载失败", comment: ""))",
                mkdirError: "\(NSLocalizedString("创建文件夹失败", comment: ""))",
                renameError: "\(NSLocalizedString("重命名失败", comment: ""))",
                deleteError: "\(NSLocalizedString("删除失败", comment: ""))",
                upload: "\(NSLocalizedString("上传", comment: ""))",
                uploadFile: "\(NSLocalizedString("选择文件", comment: ""))",
                uploadFolder: "\(NSLocalizedString("选择文件夹", comment: ""))",
                loading: "\(NSLocalizedString("加载中...", comment: ""))"
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

    private static func fileManagerJsResponse() -> GCDWebServerResponse? {
        guard let url = Bundle.main.url(forResource: "fileManager", withExtension: "js"),
              let js = try? String(contentsOf: url, encoding: .utf8) else {
            return GCDWebServerDataResponse(statusCode: 404)
        }
        return GCDWebServerDataResponse(data: (js.data(using: .utf8) ?? Data()), contentType: "application/javascript")
    }
}
