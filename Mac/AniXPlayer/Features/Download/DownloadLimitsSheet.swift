//
//  DownloadLimitsSheet.swift
//  AniXPlayer
//
//  macOS：Transmission 全局限速/做种分享率，以及远程→本地路径映射。
//

import Cocoa
import SnapKit

final class DownloadLimitsSheetViewController: ViewController {

    var onSaved: (() -> Void)?

    private let manager: DownloadManager
    private let downloadField = NSTextField()
    private let uploadField = NSTextField()
    private let seedRatioField = NSTextField()
    private let remotePrefixField = NSTextField()
    private let localPrefixField = NSTextField()
    private let applyButton = NSButton(title: "", target: nil, action: nil)
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private var isApplying = false

    init(manager: DownloadManager) {
        self.manager = manager
        super.init()
        preferredContentSize = NSSize(width: 600, height: 440)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 440))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Download.limitsSheet)
        setupLayout()
        populate()
        updateApplyAvailability()
        if manager.preferences.enableBT {
            statusLabel.stringValue = NSLocalizedString(
                "修改后点击“应用到 Transmission”立即生效；保存只记住设置。",
                comment: ""
            )
        }
    }

    private func setupLayout() {
        let title = Self.makeLabel(
            NSLocalizedString("限速与远程路径", comment: ""),
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )
        let limitsTitle = Self.sectionLabel(NSLocalizedString("Transmission 全局限速", comment: ""))
        let limitsHint = Self.makeLabel(
            NSLocalizedString("单位 KB/s；0 表示不限制。分享率为上传/下载比值，0 表示不启用。", comment: ""),
            font: .systemFont(ofSize: 10.5),
            color: .secondaryLabelColor
        )
        limitsHint.lineBreakMode = .byWordWrapping
        limitsHint.maximumNumberOfLines = 2

        let downloadLabel = Self.makeLabel(NSLocalizedString("下载限速", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)
        let uploadLabel = Self.makeLabel(NSLocalizedString("上传限速", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)
        let seedLabel = Self.makeLabel(NSLocalizedString("做种分享率", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)

        for field in [downloadField, uploadField, seedRatioField] {
            field.alignment = .right
            field.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        }
        downloadField.setAccessibilityIdentifier(AccessibilityID.Download.limitsDownload)
        uploadField.setAccessibilityIdentifier(AccessibilityID.Download.limitsUpload)
        seedRatioField.setAccessibilityIdentifier(AccessibilityID.Download.limitsSeedRatio)

        applyButton.title = NSLocalizedString("应用到 Transmission", comment: "")
        applyButton.bezelStyle = .rounded
        applyButton.controlSize = .small
        applyButton.target = self
        applyButton.action = #selector(applyTapped)
        applyButton.setAccessibilityIdentifier(AccessibilityID.Download.limitsApply)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Download.limitsStatus)

        let mappingTitle = Self.sectionLabel(NSLocalizedString("远程 Transmission 路径映射", comment: ""))
        let mappingHint = Self.makeLabel(
            NSLocalizedString(
                "用于远程 daemon 下载完成后“播放/在 Finder 中显示”。留空表示不映射，本机 Transmission 无需设置。例如 /downloads → /Users/me/Downloads。",
                comment: ""
            ),
            font: .systemFont(ofSize: 10.5),
            color: .secondaryLabelColor
        )
        mappingHint.lineBreakMode = .byWordWrapping
        mappingHint.maximumNumberOfLines = 3

        let remoteLabel = Self.makeLabel(NSLocalizedString("远程前缀", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)
        let localLabel = Self.makeLabel(NSLocalizedString("本地前缀", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)

        remotePrefixField.placeholderString = "/downloads"
        localPrefixField.placeholderString = "/Users/me/Downloads"
        remotePrefixField.setAccessibilityIdentifier(AccessibilityID.Download.limitsRemotePrefix)
        localPrefixField.setAccessibilityIdentifier(AccessibilityID.Download.limitsLocalPrefix)

        cancelButton.title = NSLocalizedString("取消", comment: "")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Download.limitsCancel)

        saveButton.title = NSLocalizedString("保存", comment: "")
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.setAccessibilityIdentifier(AccessibilityID.Download.limitsSave)

        let views: [NSView] = [
            title, limitsTitle, limitsHint,
            downloadLabel, downloadField, uploadLabel, uploadField,
            seedLabel, seedRatioField, applyButton, statusLabel,
            mappingTitle, mappingHint, remoteLabel, remotePrefixField,
            localLabel, localPrefixField, cancelButton, saveButton,
        ]
        views.forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        limitsTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(title.snp.bottom).offset(14)
        }
        limitsHint.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(limitsTitle.snp.bottom).offset(4)
        }
        downloadLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(limitsHint.snp.bottom).offset(10)
            make.width.equalTo(86)
        }
        downloadField.snp.makeConstraints { make in
            make.leading.equalTo(downloadLabel.snp.trailing).offset(10)
            make.centerY.equalTo(downloadLabel)
            make.width.equalTo(110)
            make.height.equalTo(24)
        }
        uploadLabel.snp.makeConstraints { make in
            make.leading.equalTo(downloadField.snp.trailing).offset(28)
            make.centerY.equalTo(downloadLabel)
            make.width.equalTo(72)
        }
        uploadField.snp.makeConstraints { make in
            make.leading.equalTo(uploadLabel.snp.trailing).offset(10)
            make.centerY.equalTo(uploadLabel)
            make.width.equalTo(110)
            make.height.equalTo(24)
        }
        seedLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(downloadField.snp.bottom).offset(10)
            make.width.equalTo(86)
        }
        seedRatioField.snp.makeConstraints { make in
            make.leading.equalTo(seedLabel.snp.trailing).offset(10)
            make.centerY.equalTo(seedLabel)
            make.width.equalTo(110)
            make.height.equalTo(24)
        }
        applyButton.snp.makeConstraints { make in
            make.leading.equalTo(seedRatioField.snp.trailing).offset(20)
            make.centerY.equalTo(seedLabel)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(applyButton.snp.trailing).offset(12)
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(applyButton)
        }

        mappingTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(seedLabel.snp.bottom).offset(18)
        }
        mappingHint.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(mappingTitle.snp.bottom).offset(4)
        }
        remoteLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(mappingHint.snp.bottom).offset(12)
            make.width.equalTo(72)
        }
        remotePrefixField.snp.makeConstraints { make in
            make.leading.equalTo(remoteLabel.snp.trailing).offset(10)
            make.centerY.equalTo(remoteLabel)
            make.width.equalTo(210)
            make.height.equalTo(24)
        }
        localLabel.snp.makeConstraints { make in
            make.leading.equalTo(remotePrefixField.snp.trailing).offset(20)
            make.centerY.equalTo(remoteLabel)
        }
        localPrefixField.snp.makeConstraints { make in
            make.leading.equalTo(localLabel.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(localLabel)
            make.height.equalTo(24)
        }

        saveButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.width.greaterThanOrEqualTo(80)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(saveButton.snp.leading).offset(-10)
            make.centerY.equalTo(saveButton)
            make.width.greaterThanOrEqualTo(80)
        }
        cancelButton.setContentHuggingPriority(.required, for: .horizontal)
    }

    private func populate() {
        let preferences = manager.preferences
        downloadField.stringValue = "\(preferences.downloadSpeedLimitKBps)"
        uploadField.stringValue = "\(preferences.uploadSpeedLimitKBps)"
        seedRatioField.stringValue = Self.ratioText(preferences.seedRatioLimit)
        remotePrefixField.stringValue = preferences.remotePathPrefix
        localPrefixField.stringValue = preferences.localPathPrefix
    }

    private func updateApplyAvailability() {
        let enabled = manager.preferences.enableBT
        applyButton.isEnabled = enabled && !isApplying
        if !enabled {
            statusLabel.textColor = .secondaryLabelColor
            statusLabel.stringValue = NSLocalizedString(
                "BT 集成已关闭；启用并保存后才能应用限速。",
                comment: ""
            )
        }
    }

    private func parseLimits() -> TransmissionTransferLimits? {
        guard let download = Int(downloadField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              download >= 0,
              let upload = Int(uploadField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              upload >= 0 else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = NSLocalizedString("限速必须是不小于 0 的整数（KB/s）。", comment: "")
            return nil
        }
        let ratioText = seedRatioField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        let ratio = ratioText.isEmpty ? 0 : Double(ratioText)
        guard let ratio, ratio >= 0 else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = NSLocalizedString("分享率必须是不小于 0 的数字。", comment: "")
            return nil
        }
        return TransmissionTransferLimits(
            downloadKBps: download,
            uploadKBps: upload,
            seedRatio: ratio
        )
    }

    @objc private func applyTapped() {
        guard !isApplying else { return }
        guard manager.preferences.enableBT else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = NSLocalizedString(
                "BT 集成已关闭，无法连接 Transmission。",
                comment: ""
            )
            return
        }
        guard let limits = parseLimits() else { return }

        isApplying = true
        applyButton.isEnabled = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("正在应用…", comment: "")

        let client = TransmissionRPCClient(configuration: manager.preferences.rpcConfiguration)
        Task { [weak self] in
            do {
                try await client.sessionSet(limits: limits)
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isApplying = false
                    self.updateApplyAvailability()
                    self.manager.preferences.setTransferLimits(
                        downloadKBps: limits.downloadKBps,
                        uploadKBps: limits.uploadKBps,
                        seedRatio: limits.seedRatio
                    )
                    self.statusLabel.textColor = .systemGreen
                    self.statusLabel.stringValue = String(
                        format: NSLocalizedString("已应用：下载 %@ · 上传 %@ · 分享率 %@", comment: ""),
                        Self.limitText(limits.downloadKBps),
                        Self.limitText(limits.uploadKBps),
                        limits.seedRatio > 0 ? Self.ratioText(limits.seedRatio) : NSLocalizedString("不限", comment: "")
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isApplying = false
                    self.updateApplyAvailability()
                    self.statusLabel.textColor = .systemRed
                    self.statusLabel.stringValue = String(
                        format: NSLocalizedString("应用失败：%@", comment: ""),
                        error.localizedDescription
                    )
                }
            }
        }
    }

    @objc private func saveTapped() {
        guard let limits = parseLimits() else { return }
        manager.preferences.setTransferLimits(
            downloadKBps: limits.downloadKBps,
            uploadKBps: limits.uploadKBps,
            seedRatio: limits.seedRatio
        )
        manager.preferences.setRemotePathMapping(
            remotePrefix: remotePrefixField.stringValue,
            localPrefix: localPrefixField.stringValue
        )
        onSaved?()
        dismiss(self)
    }

    @objc private func cancelTapped() {
        dismiss(self)
    }

    private static func ratioText(_ value: Double) -> String {
        if value <= 0 { return "0" }
        return String(format: "%.2f", value)
    }

    private static func limitText(_ value: Int) -> String {
        value > 0
            ? String(format: NSLocalizedString("%d KB/s", comment: ""), value)
            : NSLocalizedString("不限", comment: "")
    }

    private static func sectionLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12, weight: .semibold)
        label.textColor = .labelColor
        return label
    }

    private static func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        label.lineBreakMode = .byTruncatingTail
        return label
    }
}
