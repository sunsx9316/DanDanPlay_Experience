//
//  GIFExportFlowController.swift
//  AniXPlayer
//
//  macOS：动图导出流程（选项 → 进度/取消 → 预览/另存为）。
//

import Cocoa
import ANXLog

@MainActor
final class GIFExportFlowController {

    /// 流程结束（成功关闭预览、取消或失败）时回调；宿主用它恢复菜单状态。
    var onFinish: (() -> Void)?

    private weak var host: PlayerViewController?
    private let file: File
    private let startTime: TimeInterval
    private let mediaDuration: TimeInterval

    private var session: GIFExportSession?
    private var optionsViewController: GIFExportOptionsViewController?
    private var progressViewController: GIFExportProgressViewController?
    private var previewViewController: GIFExportPreviewViewController?
    private var cancelFallbackWorkItem: DispatchWorkItem?
    private var isFinished = false

    init(host: PlayerViewController, file: File, startTime: TimeInterval, mediaDuration: TimeInterval) {
        self.host = host
        self.file = file
        self.startTime = startTime
        self.mediaDuration = mediaDuration
    }

    func start() {
        let options = GIFExportOptionsViewController(
            startTime: startTime,
            mediaDuration: mediaDuration,
            formats: GIFExportFormat.supportedFormats
        )
        options.onCancel = { [weak self] in
            self?.finish(message: nil)
        }
        options.onExport = { [weak self] start, configuration in
            self?.beginExport(startTime: start, configuration: configuration)
        }
        optionsViewController = options

        guard let host = host else {
            finish(message: nil)
            return
        }
        host.presentAsSheet(options)
    }

    /// 立即取消并关闭所有 sheet（切换媒体、关闭播放器时用）。
    func cancelAndDismiss() {
        guard !isFinished else { return }
        session?.cancel()
        finish(message: nil)
    }

    // MARK: - Export

    private func beginExport(startTime: TimeInterval, configuration: GIFExportConfiguration) {
        guard !isFinished else { return }

        optionsViewController?.dismiss(nil)
        optionsViewController = nil

        let progress = GIFExportProgressViewController()
        progress.onCancel = { [weak self] in
            self?.requestCancel()
        }
        progressViewController = progress

        // 等选项 sheet 收完再展示进度 sheet，避免 AppKit 同时关闭/展示动画冲突。
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
            guard let self = self, !self.isFinished else { return }
            self.host?.presentAsSheet(progress)
            self.startExport(startTime: startTime, configuration: configuration)
        }
    }

    private func startExport(startTime: TimeInterval, configuration: GIFExportConfiguration) {
        let service = GIFExportService()
        let session = service.export(
            file: file,
            startTime: startTime,
            mediaDuration: mediaDuration,
            configuration: configuration,
            progress: { [weak self] value in
                self?.progressViewController?.update(progress: value)
            },
            completion: { [weak self] result in
                self?.handle(result)
            }
        )
        self.session = session
    }

    private func requestCancel() {
        guard !isFinished else { return }
        session?.cancel()

        // 个别解码器可能卡在单帧读取里；给 UI 一个兜底，避免进度 sheet 永远停住。
        cancelFallbackWorkItem?.cancel()
        let item = DispatchWorkItem { [weak self] in
            self?.finish(message: NSLocalizedString("已取消动图导出。", comment: ""))
        }
        cancelFallbackWorkItem = item
        DispatchQueue.main.asyncAfter(deadline: .now() + 2, execute: item)
    }

    private func handle(_ result: Result<GIFExportOutput, Error>) {
        guard !isFinished else { return }
        cancelFallbackWorkItem?.cancel()
        cancelFallbackWorkItem = nil

        let wasCancelled = session?.isCancelled == true
        session = nil

        switch result {
        case .success(let output):
            // 用户在编码收尾阶段点了取消：不要弹出预览。
            if wasCancelled {
                try? FileManager.default.removeItem(at: output.url)
                finish(message: NSLocalizedString("已取消动图导出。", comment: ""))
                return
            }

            progressViewController?.dismiss(nil)
            progressViewController = nil
            ANX.logInfo(.player, "[GIF] 动图已保存: \(output.url.path)")

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) { [weak self] in
                guard let self = self, !self.isFinished else { return }
                let preview = GIFExportPreviewViewController(output: output)
                preview.onDone = { [weak self] in
                    self?.finish(message: nil)
                }
                self.previewViewController = preview
                self.host?.presentAsSheet(preview)
            }

        case .failure(let error):
            if Self.isCancellation(error) {
                finish(message: NSLocalizedString("已取消动图导出。", comment: ""))
            } else {
                ANX.logError(.player, "[GIF] 导出失败: \(error)")
                finish(error: error)
            }
        }
    }

    private static func isCancellation(_ error: Error) -> Bool {
        if let exportError = error as? GIFExportError, case .cancelled = exportError {
            return true
        }
        if let captureError = error as? GIFMPVFrameCapture.CaptureError, case .cancelled = captureError {
            return true
        }
        return false
    }

    // MARK: - Finish

    private func finish(message: String? = nil, error: Error? = nil) {
        guard !isFinished else { return }
        isFinished = true
        cancelFallbackWorkItem?.cancel()
        cancelFallbackWorkItem = nil
        session = nil

        previewViewController?.dismiss(nil)
        progressViewController?.dismiss(nil)
        optionsViewController?.dismiss(nil)
        previewViewController = nil
        progressViewController = nil
        optionsViewController = nil

        if let error = error {
            host?.view.show(error: error)
        } else if let message = message {
            host?.view.show(text: message)
        }

        onFinish?()
    }
}
