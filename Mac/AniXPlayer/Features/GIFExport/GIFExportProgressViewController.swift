//
//  GIFExportProgressViewController.swift
//  AniXPlayer
//
//  macOS：动图导出进度 sheet（进度 + 取消）。
//

import Cocoa
import SnapKit

final class GIFExportProgressViewController: ViewController {

    var onCancel: (() -> Void)?

    private let progressIndicator = NSProgressIndicator()
    private let statusLabel = NSTextField(labelWithString: "")
    private let percentLabel = NSTextField(labelWithString: "0%")
    private let cancelButton = NSButton()
    private var didRequestCancel = false

    override init() {
        super.init()
        preferredContentSize = NSSize(width: 420, height: 190)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: 190))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Player.gifExportProgressWindow)

        let title = NSTextField(labelWithString: NSLocalizedString("正在导出动图", comment: ""))
        title.font = .systemFont(ofSize: 16, weight: .semibold)

        statusLabel.stringValue = NSLocalizedString("正在准备…", comment: "")
        statusLabel.font = .systemFont(ofSize: 12)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.lineBreakMode = .byTruncatingTail
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Player.gifExportProgressLabel)

        progressIndicator.isIndeterminate = false
        progressIndicator.minValue = 0
        progressIndicator.maxValue = 1
        progressIndicator.doubleValue = 0
        progressIndicator.controlSize = .regular
        progressIndicator.setAccessibilityIdentifier(AccessibilityID.Player.gifExportProgressIndicator)

        percentLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        percentLabel.textColor = .secondaryLabelColor
        percentLabel.alignment = .right
        percentLabel.snp.makeConstraints { make in
            make.width.equalTo(44)
        }

        let progressRow = NSStackView(views: [progressIndicator, percentLabel])
        progressRow.orientation = .horizontal
        progressRow.spacing = 10
        progressRow.alignment = .centerY
        progressIndicator.setContentHuggingPriority(.defaultLow, for: .horizontal)

        cancelButton.title = NSLocalizedString("取消", comment: "")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Player.gifExportProgressCancelButton)

        [title, statusLabel, progressRow, cancelButton].forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(22)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(title.snp.bottom).offset(10)
        }
        progressRow.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(statusLabel.snp.bottom).offset(14)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-20)
            make.width.greaterThanOrEqualTo(80)
        }
    }

    func update(progress: Double) {
        let clamped = min(max(progress, 0), 1)
        progressIndicator.doubleValue = clamped
        percentLabel.stringValue = "\(Int((clamped * 100).rounded()))%"

        guard !didRequestCancel else { return }
        if clamped < 0.88 {
            statusLabel.stringValue = NSLocalizedString("正在截取画面…", comment: "")
        } else if clamped < 1 {
            statusLabel.stringValue = NSLocalizedString("正在编码动图…", comment: "")
        } else {
            statusLabel.stringValue = NSLocalizedString("即将完成…", comment: "")
        }
    }

    @objc private func cancelTapped() {
        guard !didRequestCancel else { return }
        didRequestCancel = true
        cancelButton.isEnabled = false
        statusLabel.stringValue = NSLocalizedString("正在取消…", comment: "")
        onCancel?()
    }
}
