//
//  DownloadSheets.swift
//  AniXPlayer
//
//  macOS：下载中心的添加任务 / 设置 sheet。
//

import Cocoa
import SnapKit
import UniformTypeIdentifiers

// MARK: - Add sheet

final class DownloadAddSheetViewController: ViewController {

    /// (source, savePath, bookmark, completion)
    var onSubmit: ((String, String, Data?, @escaping (Result<Void, Error>) -> Void) -> Void)?

    private let sourceField = NSTextField()
    private let savePathLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let addButton = NSButton(title: "", target: nil, action: nil)
    private var savePath: String
    private var saveBookmark: Data?
    private var isSubmitting = false

    init(defaultSavePath: String, defaultBookmark: Data?) {
        self.savePath = defaultSavePath
        self.saveBookmark = defaultBookmark
        super.init()
        preferredContentSize = NSSize(width: 580, height: 310)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 310))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Download.addSheet)
        setupLayout()
        updateSavePathLabel()
    }

    private func setupLayout() {
        let title = Self.makeLabel(
            NSLocalizedString("添加下载任务", comment: ""),
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )
        let hint = Self.makeLabel(
            NSLocalizedString("支持磁力链接、.torrent 种子文件、HTTP/HTTPS 直链。BT 任务需要本机 transmission-daemon。", comment: ""),
            font: .systemFont(ofSize: 11),
            color: .secondaryLabelColor
        )
        hint.lineBreakMode = .byWordWrapping
        hint.maximumNumberOfLines = 2

        sourceField.placeholderString = NSLocalizedString("magnet:?xt=... 或 https://example.com/file.mp4", comment: "")
        sourceField.font = .systemFont(ofSize: 12.5)
        sourceField.setAccessibilityIdentifier(AccessibilityID.Download.addSheetSource)

        let chooseTorrentButton = NSButton(
            title: NSLocalizedString("选择种子…", comment: ""),
            target: self,
            action: #selector(chooseTorrentTapped)
        )
        chooseTorrentButton.bezelStyle = .rounded
        chooseTorrentButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetChooseTorrent)

        let saveTitle = Self.makeLabel(
            NSLocalizedString("保存到", comment: ""),
            font: .systemFont(ofSize: 12, weight: .medium),
            color: .secondaryLabelColor
        )
        savePathLabel.font = .systemFont(ofSize: 11.5)
        savePathLabel.textColor = .labelColor
        savePathLabel.lineBreakMode = .byTruncatingMiddle
        savePathLabel.setAccessibilityIdentifier(AccessibilityID.Download.addSheetSavePath)

        let chooseFolderButton = NSButton(
            title: NSLocalizedString("选择目录…", comment: ""),
            target: self,
            action: #selector(chooseFolderTapped)
        )
        chooseFolderButton.bezelStyle = .rounded
        chooseFolderButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetChooseFolder)

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .systemRed
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Download.addSheetStatus)

        let cancelButton = NSButton(
            title: NSLocalizedString("取消", comment: ""),
            target: self,
            action: #selector(cancelTapped)
        )
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetCancel)

        addButton.title = NSLocalizedString("添加", comment: "")
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        addButton.target = self
        addButton.action = #selector(addTapped)
        addButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetSubmit)

        [title, hint, sourceField, chooseTorrentButton, saveTitle, savePathLabel,
         chooseFolderButton, statusLabel, cancelButton, addButton].forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        hint.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(title.snp.bottom).offset(6)
        }
        sourceField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(hint.snp.bottom).offset(16)
            make.height.equalTo(26)
        }
        chooseTorrentButton.snp.makeConstraints { make in
            make.leading.equalTo(sourceField.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(sourceField)
        }
        sourceField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        chooseTorrentButton.setContentCompressionResistancePriority(.required, for: .horizontal)

        saveTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(sourceField.snp.bottom).offset(20)
        }
        chooseFolderButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(saveTitle.snp.bottom).offset(4)
        }
        savePathLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalTo(chooseFolderButton.snp.leading).offset(-12)
            make.centerY.equalTo(chooseFolderButton)
        }
        savePathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(savePathLabel.snp.bottom).offset(16)
        }
        addButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.width.greaterThanOrEqualTo(80)
        }
        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(addButton.snp.leading).offset(-10)
            make.centerY.equalTo(addButton)
            make.width.greaterThanOrEqualTo(80)
        }
    }

    // MARK: Actions

    @objc private func chooseTorrentTapped() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择种子文件", comment: "")
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [UTType(filenameExtension: "torrent") ?? .data]

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.sourceField.stringValue = url.path
            self.statusLabel.stringValue = ""
        }
        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    @objc private func chooseFolderTapped() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择下载保存目录", comment: "")
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.savePath = url.path
            self.saveBookmark = DownloadFileAccess.makeBookmark(for: url)
            self.updateSavePathLabel()
        }
        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    @objc private func cancelTapped() {
        dismiss(self)
    }

    @objc private func addTapped() {
        guard !isSubmitting else { return }
        let source = sourceField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty else {
            statusLabel.stringValue = DownloadSourceError.empty.localizedDescription
            sourceField.becomeFirstResponder()
            return
        }
        guard let onSubmit else { return }

        isSubmitting = true
        addButton.isEnabled = false
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("正在添加…", comment: "")

        onSubmit(source, savePath, saveBookmark) { [weak self] result in
            guard let self else { return }
            self.isSubmitting = false
            self.addButton.isEnabled = true
            switch result {
            case .success:
                self.dismiss(self)
            case .failure(let error):
                self.statusLabel.textColor = .systemRed
                self.statusLabel.stringValue = error.localizedDescription
            }
        }
    }

    private func updateSavePathLabel() {
        savePathLabel.stringValue = savePath
        savePathLabel.toolTip = savePath
    }

    private static func makeLabel(
        _ text: String,
        font: NSFont,
        color: NSColor
    ) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.font = font
        label.textColor = color
        return label
    }
}

// MARK: - Settings sheet

struct DownloadSettingsDraft {
    var enableBT: Bool
    var host: String
    var port: Int
    var useHTTPS: Bool
    var username: String
    var password: String?
    var sequentialDownload: Bool
    var savePath: String
    var saveBookmark: Data?
    var maxConcurrentDownloads: Int
}

final class DownloadSettingsSheetViewController: ViewController {

    var onSave: ((DownloadSettingsDraft) throws -> Void)?

    private let preferences: DownloadPreferences
    private let enableBTCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let hostField = NSTextField()
    private let portField = NSTextField()
    private let usernameField = NSTextField()
    private let passwordField = NSSecureTextField()
    private let clearPasswordButton = NSButton(title: "", target: nil, action: nil)
    private let httpsCheckbox = NSButton(checkboxWithTitle: "HTTPS", target: nil, action: nil)
    private let sequentialCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let savePathLabel = NSTextField(labelWithString: "")
    private let concurrentPopup = NSPopUpButton()
    private let statusLabel = NSTextField(labelWithString: "")
    private var savePath: String
    private var saveBookmark: Data?
    private var clearPassword = false
    private var isSaving = false

    init(preferences: DownloadPreferences = .shared) {
        self.preferences = preferences
        self.savePath = preferences.defaultSavePath
        self.saveBookmark = preferences.defaultSaveBookmark
        super.init()
        preferredContentSize = NSSize(width: 580, height: 470)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 470))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Download.settingsSheet)
        setupLayout()
        populate()
    }

    private func setupLayout() {
        let title = Self.makeLabel(
            NSLocalizedString("下载设置", comment: ""),
            font: .systemFont(ofSize: 17, weight: .semibold),
            color: .labelColor
        )

        enableBTCheckbox.title = NSLocalizedString("启用 BT（磁力 / 种子，需要本机 transmission-daemon）", comment: "")
        enableBTCheckbox.setAccessibilityIdentifier(AccessibilityID.Download.settingsEnableBT)

        let rpcTitle = Self.sectionLabel(NSLocalizedString("Transmission RPC", comment: ""))
        hostField.placeholderString = "127.0.0.1"
        hostField.setAccessibilityIdentifier(AccessibilityID.Download.settingsHost)
        portField.placeholderString = "9091"
        portField.setAccessibilityIdentifier(AccessibilityID.Download.settingsPort)
        usernameField.placeholderString = NSLocalizedString("用户名（可选）", comment: "")
        usernameField.setAccessibilityIdentifier(AccessibilityID.Download.settingsUsername)
        passwordField.placeholderString = NSLocalizedString("密码（留空保持不变）", comment: "")
        passwordField.setAccessibilityIdentifier(AccessibilityID.Download.settingsPassword)

        let hostLabel = Self.makeLabel("RPC", font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)
        let portLabel = Self.makeLabel(NSLocalizedString("端口", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)
        let userLabel = Self.makeLabel(NSLocalizedString("用户名", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)
        let passwordLabel = Self.makeLabel(NSLocalizedString("密码", comment: ""), font: .systemFont(ofSize: 11.5), color: .secondaryLabelColor)

        clearPasswordButton.title = NSLocalizedString("清除已保存密码", comment: "")
        clearPasswordButton.bezelStyle = .inline
        clearPasswordButton.isBordered = false
        clearPasswordButton.contentTintColor = .systemRed
        clearPasswordButton.target = self
        clearPasswordButton.action = #selector(clearPasswordTapped)
        clearPasswordButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsClearPassword)

        httpsCheckbox.setAccessibilityIdentifier(AccessibilityID.Download.settingsHTTPS)
        sequentialCheckbox.title = NSLocalizedString("按顺序下载（便于边下边播）", comment: "")
        sequentialCheckbox.setAccessibilityIdentifier(AccessibilityID.Download.settingsSequential)

        let saveTitle = Self.sectionLabel(NSLocalizedString("默认保存目录", comment: ""))
        savePathLabel.font = .systemFont(ofSize: 11.5)
        savePathLabel.lineBreakMode = .byTruncatingMiddle
        savePathLabel.setAccessibilityIdentifier(AccessibilityID.Download.settingsSavePath)

        let chooseFolderButton = NSButton(
            title: NSLocalizedString("选择目录…", comment: ""),
            target: self,
            action: #selector(chooseFolderTapped)
        )
        chooseFolderButton.bezelStyle = .rounded
        chooseFolderButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsChooseFolder)

        let concurrentLabel = Self.makeLabel(
            NSLocalizedString("最大同时下载数", comment: ""),
            font: .systemFont(ofSize: 11.5),
            color: .secondaryLabelColor
        )
        concurrentPopup.addItems(withTitles: (1...8).map { "\($0)" })
        concurrentPopup.setAccessibilityIdentifier(AccessibilityID.Download.settingsMaxConcurrent)

        statusLabel.font = .systemFont(ofSize: 11.5)
        statusLabel.textColor = .systemRed
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.maximumNumberOfLines = 2
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Download.settingsStatus)

        let cancelButton = NSButton(
            title: NSLocalizedString("取消", comment: ""),
            target: self,
            action: #selector(cancelTapped)
        )
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsCancel)

        let saveButton = NSButton(
            title: NSLocalizedString("保存", comment: ""),
            target: self,
            action: #selector(saveTapped)
        )
        saveButton.bezelStyle = .rounded
        saveButton.keyEquivalent = "\r"
        saveButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsSave)

        let views: [NSView] = [
            title, enableBTCheckbox, rpcTitle,
            hostLabel, hostField, portLabel, portField,
            userLabel, usernameField, passwordLabel, passwordField,
            clearPasswordButton, httpsCheckbox, sequentialCheckbox,
            saveTitle, savePathLabel, chooseFolderButton,
            concurrentLabel, concurrentPopup, statusLabel,
            cancelButton, saveButton,
        ]
        views.forEach(view.addSubview)

        title.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        enableBTCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(title.snp.bottom).offset(12)
        }

        rpcTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(enableBTCheckbox.snp.bottom).offset(14)
        }
        hostLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(hostField)
            make.width.equalTo(48)
        }
        hostField.snp.makeConstraints { make in
            make.leading.equalTo(hostLabel.snp.trailing).offset(8)
            make.top.equalTo(rpcTitle.snp.bottom).offset(8)
            make.height.equalTo(24)
        }
        portLabel.snp.makeConstraints { make in
            make.leading.equalTo(hostField.snp.trailing).offset(12)
            make.centerY.equalTo(hostField)
        }
        portField.snp.makeConstraints { make in
            make.leading.equalTo(portLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(hostField)
            make.width.equalTo(80)
            make.height.equalTo(24)
        }
        hostField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        userLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(usernameField)
            make.width.equalTo(48)
        }
        usernameField.snp.makeConstraints { make in
            make.leading.equalTo(userLabel.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(hostField.snp.bottom).offset(8)
            make.height.equalTo(24)
        }
        passwordLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(passwordField)
            make.width.equalTo(48)
        }
        passwordField.snp.makeConstraints { make in
            make.leading.equalTo(passwordLabel.snp.trailing).offset(8)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(usernameField.snp.bottom).offset(8)
            make.height.equalTo(24)
        }
        clearPasswordButton.snp.makeConstraints { make in
            make.leading.equalTo(passwordField)
            make.top.equalTo(passwordField.snp.bottom).offset(4)
        }
        httpsCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(clearPasswordButton.snp.bottom).offset(8)
        }
        sequentialCheckbox.snp.makeConstraints { make in
            make.leading.equalTo(httpsCheckbox.snp.trailing).offset(16)
            make.centerY.equalTo(httpsCheckbox)
        }

        saveTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(httpsCheckbox.snp.bottom).offset(14)
        }
        savePathLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalTo(chooseFolderButton.snp.leading).offset(-12)
            make.centerY.equalTo(chooseFolderButton)
        }
        chooseFolderButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(saveTitle.snp.bottom).offset(6)
        }
        savePathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        concurrentLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(concurrentPopup)
        }
        concurrentPopup.snp.makeConstraints { make in
            make.leading.equalTo(concurrentLabel.snp.trailing).offset(12)
            make.top.equalTo(chooseFolderButton.snp.bottom).offset(12)
            make.width.equalTo(80)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(concurrentPopup.snp.bottom).offset(12)
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
    }

    private func populate() {
        enableBTCheckbox.state = preferences.enableBT ? .on : .off
        hostField.stringValue = preferences.rpcHost
        portField.stringValue = "\(preferences.rpcPort)"
        usernameField.stringValue = preferences.rpcUsername
        passwordField.stringValue = ""
        httpsCheckbox.state = preferences.rpcUseHTTPS ? .on : .off
        sequentialCheckbox.state = preferences.sequentialDownload ? .on : .off
        concurrentPopup.selectItem(at: max(0, preferences.maxConcurrentDownloads - 1))
        updateSavePathLabel()
    }

    @objc private func clearPasswordTapped() {
        clearPassword = true
        passwordField.stringValue = ""
        passwordField.placeholderString = NSLocalizedString("保存时将清除已保存密码", comment: "")
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("已标记清除密码；点击保存后生效。", comment: "")
    }

    @objc private func chooseFolderTapped() {
        let panel = NSOpenPanel()
        panel.title = NSLocalizedString("选择默认下载保存目录", comment: "")
        panel.prompt = NSLocalizedString("选择", comment: "")
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.canCreateDirectories = true
        panel.allowsMultipleSelection = false

        let handle: (NSApplication.ModalResponse) -> Void = { [weak self] response in
            guard response == .OK, let url = panel.url, let self else { return }
            self.savePath = url.path
            self.saveBookmark = DownloadFileAccess.makeBookmark(for: url)
            self.updateSavePathLabel()
        }
        if let window = view.window {
            panel.beginSheetModal(for: window, completionHandler: handle)
        } else {
            handle(panel.runModal())
        }
    }

    @objc private func cancelTapped() {
        dismiss(self)
    }

    @objc private func saveTapped() {
        guard !isSaving else { return }
        guard let port = Int(portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(port) else {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = NSLocalizedString("端口必须是 1–65535 之间的整数", comment: "")
            portField.becomeFirstResponder()
            return
        }

        let password: String?
        if clearPassword {
            password = ""
        } else if passwordField.stringValue.isEmpty {
            password = nil
        } else {
            password = passwordField.stringValue
        }

        let draft = DownloadSettingsDraft(
            enableBT: enableBTCheckbox.state == .on,
            host: hostField.stringValue,
            port: port,
            useHTTPS: httpsCheckbox.state == .on,
            username: usernameField.stringValue,
            password: password,
            sequentialDownload: sequentialCheckbox.state == .on,
            savePath: savePath,
            saveBookmark: saveBookmark,
            maxConcurrentDownloads: max(1, concurrentPopup.indexOfSelectedItem + 1)
        )

        guard let onSave else { return }
        isSaving = true
        do {
            try onSave(draft)
            dismiss(self)
        } catch {
            isSaving = false
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }

    private func updateSavePathLabel() {
        savePathLabel.stringValue = savePath
        savePathLabel.toolTip = savePath
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
        return label
    }
}
