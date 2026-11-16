//
//  PlaybackSmoke.swift
//  AniXPlayer
//
//  L2 播放冒烟入口：
//    AniXPlayer --open <video> --play-seconds 5 --dump-state [--state-file <path>] --exit
//
//  只在 Debug 构建生效，Release 中 start() 是空实现。
//  不依赖签名、不依赖截图，适合脚本/CI 做「打开 -> 播放 -> 进度前进 -> 退出」断言。
//

import Cocoa

struct PlaybackSnapshot: Codable {
    let title: String?
    let duration: Double
    let position: Double
    let isPlaying: Bool
    let danmakuCount: Int
    let playerReady: Bool
}

@MainActor
final class PlaybackSmokeRunner {
    static let shared = PlaybackSmokeRunner()

    private(set) var isActive = false

    /// 非隔离的快速判断：AppDelegate 在打开外部文档时用它过滤命令行参数。
    nonisolated static var isSmokeInvocation: Bool {
        CommandLine.arguments.contains { argument in
            ["--open", "--play-seconds", "--dump-state", "--exit"].contains(argument)
        }
    }

    private init() {}

    func start(mainViewController: MainViewController?) {
        #if DEBUG
        guard !isActive, let options = PlaybackSmokeOptions.parse() else { return }
        isActive = true

        // 等 App 完成启动、窗口可见后再打开文件，避免和启动流程抢主线程。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            self?.run(options: options, mainViewController: mainViewController)
        }
        #endif
    }

    #if DEBUG
    private func run(options: PlaybackSmokeOptions, mainViewController: MainViewController?) {
        guard let mainViewController else {
            finish(options: options, snapshot: nil, error: "mainViewController 不存在")
            return
        }

        if let fileURL = options.fileURL {
            guard FileManager.default.fileExists(atPath: fileURL.path) else {
                finish(options: options, snapshot: nil, error: "文件不存在: \(fileURL.path)")
                return
            }

            mainViewController.view.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            mainViewController.openLocalFiles([LocalFile(with: fileURL)], startWith: nil)
        }

        Task { @MainActor [weak self, weak mainViewController] in
            guard let self, let mainViewController else { return }

            let readyDeadline = Date().addingTimeInterval(options.readyTimeout)
            var snapshot = mainViewController.currentPlaybackSnapshot

            while Date() < readyDeadline {
                snapshot = mainViewController.currentPlaybackSnapshot
                if snapshot?.playerReady == true { break }
                try? await Task.sleep(nanoseconds: 200_000_000)
            }

            guard var snapshot else {
                self.finish(options: options, snapshot: nil, error: "播放器没有创建")
                return
            }

            if !snapshot.playerReady {
                self.finish(options: options, snapshot: snapshot, error: "播放器未就绪（超时 \(options.readyTimeout)s）")
                return
            }

            if options.playSeconds > 0 {
                try? await Task.sleep(nanoseconds: UInt64(options.playSeconds * 1_000_000_000))
            }

            snapshot = mainViewController.currentPlaybackSnapshot ?? snapshot

            // 暂停状态下不强制要求进度前进；正常冒烟应保持播放。
            let minimumPosition = options.playSeconds > 0 ? options.playSeconds * 0.5 : 0
            let error: String? = snapshot.position + 0.05 < minimumPosition
                ? "进度没有前进：position=\(snapshot.position), 期望至少 \(minimumPosition)"
                : nil

            self.finish(options: options, snapshot: snapshot, error: error)
        }
    }

    private func finish(options: PlaybackSmokeOptions, snapshot: PlaybackSnapshot?, error: String?) {
        let payload = PlaybackSmokePayload(
            success: error == nil,
            error: error,
            snapshot: snapshot,
            file: options.fileURL?.lastPathComponent,
            requestedPlaySeconds: options.playSeconds
        )

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(payload) {
            if let stateFile = options.stateFile {
                try? data.write(to: stateFile)
            }
            if let text = String(data: data, encoding: .utf8) {
                print(text)
                fflush(stdout)
            }
        }

        if options.exit {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                exit(error == nil ? 0 : 2)
            }
        }
    }
    #endif
}

#if DEBUG
private struct PlaybackSmokePayload: Codable {
    let success: Bool
    let error: String?
    let file: String?
    let requestedPlaySeconds: Double
    let title: String?
    let duration: Double?
    let position: Double?
    let isPlaying: Bool?
    let danmakuCount: Int?
    let playerReady: Bool?

    init(success: Bool, error: String?, snapshot: PlaybackSnapshot?, file: String?, requestedPlaySeconds: Double) {
        self.success = success
        self.error = error
        self.file = file
        self.requestedPlaySeconds = requestedPlaySeconds
        self.title = snapshot?.title
        self.duration = snapshot?.duration
        self.position = snapshot?.position
        self.isPlaying = snapshot?.isPlaying
        self.danmakuCount = snapshot?.danmakuCount
        self.playerReady = snapshot?.playerReady
    }
}

private struct PlaybackSmokeOptions {
    var fileURL: URL?
    var playSeconds: Double = 3
    var dumpState = false
    var exit = false
    var stateFile: URL?
    var readyTimeout: Double = 20

    static func parse(arguments: [String] = CommandLine.arguments) -> PlaybackSmokeOptions? {
        guard arguments.contains(where: {
            ["--open", "--play-seconds", "--dump-state", "--exit"].contains($0)
        }) else {
            return nil
        }

        var options = PlaybackSmokeOptions()
        var index = 1

        func value(for flag: String) -> String? {
            guard index + 1 < arguments.count else { return nil }
            let next = arguments[index + 1]
            guard !next.hasPrefix("--") else { return nil }
            index += 1
            return next
        }

        while index < arguments.count {
            switch arguments[index] {
            case "--open":
                if let path = value(for: "--open") {
                    options.fileURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                }
            case "--play-seconds":
                if let raw = value(for: "--play-seconds"), let seconds = Double(raw) {
                    options.playSeconds = max(0, seconds)
                }
            case "--ready-timeout":
                if let raw = value(for: "--ready-timeout"), let seconds = Double(raw) {
                    options.readyTimeout = max(1, seconds)
                }
            case "--state-file":
                if let path = value(for: "--state-file") {
                    options.stateFile = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
                }
            case "--dump-state":
                options.dumpState = true
            case "--exit":
                options.exit = true
            default:
                break
            }
            index += 1
        }

        // 只有 --dump-state 也允许：用于观察已经在播放的实例。
        return options
    }
}
#endif
