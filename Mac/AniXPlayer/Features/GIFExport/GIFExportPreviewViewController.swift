//
//  GIFExportPreviewViewController.swift
//  AniXPlayer
//
//  macOS：动图导出成功后的预览 sheet（播放/定位/另存为）。
//

import Cocoa
import SnapKit

final class GIFExportPreviewViewController: ViewController {

    var onDone: (() -> Void)?

    private let output: GIFExportOutput
    private let imageView = NSImageView()
    private let infoLabel = NSTextField(labelWithString: "")
    private let pathLabel = NSTextField(labelWithString: "")

    init(output: GIFExportOutput) {
        self.output = output
        super.init()
        preferredContentSize = NSSize(width: 640, height: 500)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: 500))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Player.gifExportPreviewWindow)

        let title = NSTextField(labelWithString: NSLocalizedString("动图已生成", comment: ""))
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.animates = true
        imageView.imageFrameStyle = .photo
        imageView.setAccessibilityIdentifier(AccessibilityID.Player.gifExportPreviewImageView)
        imageView.setAccessibilityLabel(NSLocalizedString("动图预览", comment: ""))
        loadPreviewImage()

        infoLabel.font = .systemFont(ofSize: 12)
        infoLabel.textColor = .secondaryLabelColor
        infoLabel.stringValue = String(
            format: NSLocalizedString("%@ · %d 帧 · %d fps", comment: ""),
            output.format.displayName,
            output.frameCount,
            output.frameRate
        )

        pathLabel.font = .systemFont(ofSize: 11)
        pathLabel.textColor = .tertiaryLabelColor
        pathLabel.lineBreakMode = .byTruncatingMiddle
        pathLabel.stringValue = (output.url.path as NSString).abbreviatingWithTildeInPath

        let revealButton = NSButton(
            title: NSLocalizedString("在 Finder 中显示", comment: ""),
            target: self,
            action: #selector(revealTapped)
        )
        revealButton.bezelStyle = .rounded
        revealButton.setAccessibilityIdentifier(AccessibilityID.Player.gifExportRevealButton)

        let saveAsButton = NSButton(
            title: NSLocalizedString("另存为…", comment: ""),
            target: self,
            action: #selector(saveAsTapped)
        )
        saveAsButton.bezelStyle = .rounded
        saveAsButton.setAccessibilityIdentifier(AccessibilityID.Player.gifExportSaveAsButton)

        let doneButton = NSButton(
            title: NSLocalizedString("完成", comment: ""),
            target: self,
            action: #selector(doneTapped)
        )
        doneButton.bezelStyle = .rounded
        doneButton.keyEquivalent = "\r"
        doneButton.setAccessibilityIdentifier(AccessibilityID.Player.gifExportDoneButton)

        [title, imageView, infoLabel, pathLabel, revealButton, saveAsButton, doneButton].forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        imageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(title.snp.bottom).offset(12)
            make.height.equalTo(320)
        }
        infoLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(imageView.snp.bottom).offset(10)
        }
        pathLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(infoLabel.snp.bottom).offset(4)
        }
        doneButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.width.greaterThanOrEqualTo(80)
        }
        saveAsButton.snp.makeConstraints { make in
            make.trailing.equalTo(doneButton.snp.leading).offset(-10)
            make.centerY.equalTo(doneButton)
            make.width.greaterThanOrEqualTo(96)
        }
        revealButton.snp.makeConstraints { make in
            make.trailing.equalTo(saveAsButton.snp.leading).offset(-10)
            make.centerY.equalTo(doneButton)
            make.width.greaterThanOrEqualTo(120)
        }
    }

    // MARK: - Actions

    @objc private func revealTapped() {
        NSWorkspace.shared.activateFileViewerSelecting([output.url])
    }

    @objc private func saveAsTapped() {
        let panel = NSSavePanel()
        panel.title = NSLocalizedString("另存动图", comment: "")
        panel.prompt = NSLocalizedString("保存", comment: "")
        panel.allowedContentTypes = [output.format.utType]
        panel.canCreateDirectories = true
        panel.nameFieldStringValue = output.url.lastPathComponent

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard let self = self, response == .OK, let destination = panel.url else { return }
            self.copyOutput(to: destination)
        }

        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    @objc private func doneTapped() {
        onDone?()
    }

    // MARK: - Private

    private func loadPreviewImage() {
        // 自定义截图目录使用 security-scoped bookmark，读取时也要临时开权限。
        let resolved = try? SnapshotLocation.resolveAccessibleDirectory()
        defer {
            if let resolved = resolved, resolved.needsStopAccess {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }
        imageView.image = NSImage(contentsOf: output.url)
    }

    private func copyOutput(to destination: URL) {
        let resolved = try? SnapshotLocation.resolveAccessibleDirectory()
        defer {
            if let resolved = resolved, resolved.needsStopAccess {
                resolved.url.stopAccessingSecurityScopedResource()
            }
        }

        do {
            if FileManager.default.fileExists(atPath: destination.path) {
                try FileManager.default.removeItem(at: destination)
            }
            try FileManager.default.copyItem(at: output.url, to: destination)
            pathLabel.stringValue = (destination.path as NSString).abbreviatingWithTildeInPath
            infoLabel.stringValue = NSLocalizedString("已另存为新的动图文件。", comment: "")
        } catch {
            let alert = NSAlert()
            alert.messageText = NSLocalizedString("另存为失败", comment: "")
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .warning
            alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
            if let window = view.window {
                alert.beginSheetModal(for: window, completionHandler: nil)
            } else {
                alert.runModal()
            }
        }
    }
}
