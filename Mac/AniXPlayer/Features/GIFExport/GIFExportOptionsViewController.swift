//
//  GIFExportOptionsViewController.swift
//  AniXPlayer
//
//  macOS：动图导出选项 sheet。
//

import Cocoa
import SnapKit

final class GIFExportOptionsViewController: ViewController, NSTextFieldDelegate {

    var onCancel: (() -> Void)?
    var onExport: ((TimeInterval, GIFExportConfiguration) -> Void)?

    private let initialStartTime: TimeInterval
    private let mediaDuration: TimeInterval
    private let formats: [GIFExportFormat]

    private let startTimeField = NSTextField()
    private let durationControl = NSSegmentedControl()
    private let frameRateControl = NSSegmentedControl()
    private let widthControl = NSSegmentedControl()
    private let formatPopUp = NSPopUpButton()
    private let estimateLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let exportButton = NSButton()

    private var selectedFormat: GIFExportFormat {
        let index = formatPopUp.indexOfSelectedItem
        guard formats.indices.contains(index) else { return .gif }
        return formats[index]
    }

    init(startTime: TimeInterval, mediaDuration: TimeInterval, formats: [GIFExportFormat]) {
        self.initialStartTime = startTime
        self.mediaDuration = max(mediaDuration, 0)
        self.formats = formats.isEmpty ? [.gif] : formats
        super.init()
        preferredContentSize = NSSize(width: 520, height: 410)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 520, height: 410))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Player.gifExportOptionsWindow)
        setupUI()
        updateEstimate()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(startTimeField)
    }

    // MARK: - UI

    private func setupUI() {
        let title = NSTextField(labelWithString: NSLocalizedString("导出动图", comment: ""))
        title.font = .systemFont(ofSize: 17, weight: .semibold)

        let subtitle = NSTextField(labelWithString: NSLocalizedString(
            "选择片段参数。弹幕和字幕不会烧录到动图中；导出过程中可随时取消。",
            comment: ""
        ))
        subtitle.font = .systemFont(ofSize: 11.5)
        subtitle.textColor = .secondaryLabelColor
        subtitle.maximumNumberOfLines = 2
        subtitle.lineBreakMode = .byWordWrapping

        startTimeField.stringValue = String(format: "%.2f", initialStartTime)
        startTimeField.alignment = .right
        startTimeField.font = .monospacedDigitSystemFont(ofSize: 12.5, weight: .regular)
        startTimeField.delegate = self
        startTimeField.setAccessibilityIdentifier(AccessibilityID.Player.gifExportStartTimeField)

        let startTimeRow = NSStackView(views: [
            startTimeField,
            NSTextField(labelWithString: NSLocalizedString("秒（当前播放位置）", comment: ""))
        ])
        startTimeRow.orientation = .horizontal
        startTimeRow.spacing = 6
        startTimeField.snp.makeConstraints { make in
            make.width.equalTo(80)
        }

        durationControl.segmentStyle = .rounded
        durationControl.trackingMode = .selectOne
        durationControl.segmentCount = GIFExportConfiguration.allowedDurations.count
        for (index, value) in GIFExportConfiguration.allowedDurations.enumerated() {
            durationControl.setLabel(String(format: NSLocalizedString("%d 秒", comment: ""), Int(value)), forSegment: index)
        }
        durationControl.selectedSegment = GIFExportConfiguration.allowedDurations.firstIndex(of: 3)
            ?? (durationControl.segmentCount - 1)
        durationControl.target = self
        durationControl.action = #selector(controlChanged)
        durationControl.setAccessibilityIdentifier(AccessibilityID.Player.gifExportDurationControl)

        frameRateControl.segmentStyle = .rounded
        frameRateControl.trackingMode = .selectOne
        frameRateControl.segmentCount = GIFExportConfiguration.allowedFrameRates.count
        for (index, value) in GIFExportConfiguration.allowedFrameRates.enumerated() {
            frameRateControl.setLabel(String(format: NSLocalizedString("%d fps", comment: ""), value), forSegment: index)
        }
        frameRateControl.selectedSegment = GIFExportConfiguration.allowedFrameRates.firstIndex(of: 10)
            ?? (frameRateControl.segmentCount - 1)
        frameRateControl.target = self
        frameRateControl.action = #selector(controlChanged)
        frameRateControl.setAccessibilityIdentifier(AccessibilityID.Player.gifExportFPSControl)

        widthControl.segmentStyle = .rounded
        widthControl.trackingMode = .selectOne
        widthControl.segmentCount = GIFExportConfiguration.allowedWidths.count
        for (index, value) in GIFExportConfiguration.allowedWidths.enumerated() {
            widthControl.setLabel(
                String(format: NSLocalizedString("%d px", comment: ""), Int(value)),
                forSegment: index
            )
        }
        widthControl.selectedSegment = 0
        widthControl.target = self
        widthControl.action = #selector(controlChanged)
        widthControl.setAccessibilityIdentifier(AccessibilityID.Player.gifExportWidthControl)

        formatPopUp.removeAllItems()
        formatPopUp.addItems(withTitles: formats.map(\.displayName))
        formatPopUp.isEnabled = formats.count > 1
        formatPopUp.target = self
        formatPopUp.action = #selector(controlChanged)
        formatPopUp.setAccessibilityIdentifier(AccessibilityID.Player.gifExportFormatPopup)

        estimateLabel.font = .systemFont(ofSize: 11.5)
        estimateLabel.textColor = .secondaryLabelColor
        estimateLabel.setAccessibilityIdentifier(AccessibilityID.Player.gifExportEstimateLabel)

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .systemRed
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping

        let rows: [[NSView]] = [
            [makeLabel(NSLocalizedString("开始时间", comment: "")), startTimeRow],
            [makeLabel(NSLocalizedString("时长", comment: "")), durationControl],
            [makeLabel(NSLocalizedString("帧率", comment: "")), frameRateControl],
            [makeLabel(NSLocalizedString("最大宽度", comment: "")), widthControl],
            [makeLabel(NSLocalizedString("格式", comment: "")), formatPopUp]
        ]
        let grid = NSGridView(views: rows)
        grid.rowSpacing = 12
        grid.columnSpacing = 18
        grid.column(at: 0).xPlacement = .trailing
        grid.column(at: 0).width = 78

        let cancelButton = NSButton(
            title: NSLocalizedString("取消", comment: ""),
            target: self,
            action: #selector(cancelTapped)
        )
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Player.gifExportCancelButton)

        exportButton.title = NSLocalizedString("开始导出", comment: "")
        exportButton.bezelStyle = .rounded
        exportButton.keyEquivalent = "\r"
        exportButton.target = self
        exportButton.action = #selector(exportTapped)
        exportButton.setAccessibilityIdentifier(AccessibilityID.Player.gifExportConfirmButton)

        [title, subtitle, grid, estimateLabel, statusLabel, cancelButton, exportButton].forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        subtitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(title.snp.bottom).offset(6)
        }
        grid.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.lessThanOrEqualToSuperview().offset(-24)
            make.top.equalTo(subtitle.snp.bottom).offset(18)
        }
        estimateLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(grid.snp.bottom).offset(18)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(estimateLabel.snp.bottom).offset(6)
        }
        exportButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.width.greaterThanOrEqualTo(96)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(exportButton.snp.leading).offset(-10)
            make.centerY.equalTo(exportButton)
            make.width.greaterThanOrEqualTo(80)
        }
    }

    private func makeLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        return label
    }

    // MARK: - Actions

    @objc private func controlChanged() {
        updateEstimate()
    }

    func controlTextDidChange(_ obj: Notification) {
        updateEstimate()
    }

    private func updateEstimate() {
        guard let start = normalizedStartTime() else {
            estimateLabel.stringValue = ""
            statusLabel.stringValue = NSLocalizedString("开始时间无效。", comment: "")
            exportButton.isEnabled = false
            return
        }

        let remaining = max(mediaDuration - start, 0)
        let configuration = currentConfiguration
        let clipDuration = min(configuration.duration, remaining)
        let frameCount = configuration.estimatedFrameCount(for: clipDuration)

        if remaining < GIFExportConfiguration.minimumClipDuration || frameCount < 2 {
            estimateLabel.stringValue = ""
            statusLabel.stringValue = NSLocalizedString("当前位置之后不足 1 秒，请从更早的位置开始。", comment: "")
            exportButton.isEnabled = false
            return
        }

        estimateLabel.stringValue = String(
            format: NSLocalizedString("预计 %d 帧，片段 %.1f 秒，保存到截图目录。", comment: ""),
            frameCount,
            clipDuration
        )
        statusLabel.stringValue = ""
        exportButton.isEnabled = true
    }

    private var currentConfiguration: GIFExportConfiguration {
        var configuration = GIFExportConfiguration.default
        if durationControl.selectedSegment >= 0,
           durationControl.selectedSegment < GIFExportConfiguration.allowedDurations.count {
            configuration.duration = GIFExportConfiguration.allowedDurations[durationControl.selectedSegment]
        }
        if frameRateControl.selectedSegment >= 0,
           frameRateControl.selectedSegment < GIFExportConfiguration.allowedFrameRates.count {
            configuration.framesPerSecond = GIFExportConfiguration.allowedFrameRates[frameRateControl.selectedSegment]
        }
        if widthControl.selectedSegment >= 0,
           widthControl.selectedSegment < GIFExportConfiguration.allowedWidths.count {
            configuration.maximumPixelWidth = GIFExportConfiguration.allowedWidths[widthControl.selectedSegment]
        }
        configuration.format = selectedFormat
        return configuration.normalized
    }

    private func normalizedStartTime() -> TimeInterval? {
        let trimmed = startTimeField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let value = Double(trimmed), value.isFinite, value >= 0 else { return nil }
        guard mediaDuration > 0, value < mediaDuration else { return nil }
        return value
    }

    @objc private func cancelTapped() {
        onCancel?()
    }

    @objc private func exportTapped() {
        guard exportButton.isEnabled, let start = normalizedStartTime() else { return }
        onExport?(start, currentConfiguration)
    }
}
