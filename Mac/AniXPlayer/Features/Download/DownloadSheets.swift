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
    /// 添加失败且原因是 BT 未配置时，引导用户去设置。
    var onOpenBTSettings: (() -> Void)?
    var onCancel: (() -> Void)?
    var onDismiss: (() -> Void)?

    private let sourceField = NSTextField()
    private let savePathLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let btSetupButton = NSButton(title: "", target: nil, action: nil)
    private let addButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private var savePath: String
    private var saveBookmark: Data?
    private var isSubmitting = false

    init(defaultSavePath: String, defaultBookmark: Data?, prefillSource: String = "") {
        self.savePath = defaultSavePath
        self.saveBookmark = defaultBookmark
        self.sourceField.stringValue = prefillSource
        super.init()
        preferredContentSize = NSSize(width: 580, height: 350)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 580, height: 350))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Download.addSheet)
        setupLayout()
        updateSavePathLabel()
        sourceField.becomeFirstResponder()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        sourceField.becomeFirstResponder()
    }

    func replacePrefillSource(_ source: String) {
        sourceField.stringValue = source
        statusLabel.stringValue = ""
        btSetupButton.isHidden = true
        sourceField.becomeFirstResponder()
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        onDismiss?()
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
        statusLabel.maximumNumberOfLines = 3
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Download.addSheetStatus)

        btSetupButton.title = NSLocalizedString("打开 BT 设置…", comment: "")
        btSetupButton.bezelStyle = .rounded
        btSetupButton.controlSize = .small
        btSetupButton.target = self
        btSetupButton.action = #selector(btSetupTapped)
        btSetupButton.isHidden = true
        btSetupButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetBTSetup)

        cancelButton.title = NSLocalizedString("取消", comment: "")
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetCancel)

        addButton.title = NSLocalizedString("添加", comment: "")
        addButton.bezelStyle = .rounded
        addButton.keyEquivalent = "\r"
        addButton.target = self
        addButton.action = #selector(addTapped)
        addButton.setAccessibilityIdentifier(AccessibilityID.Download.addSheetSubmit)

        [title, hint, sourceField, chooseTorrentButton, saveTitle, savePathLabel,
         chooseFolderButton, statusLabel, btSetupButton, cancelButton, addButton].forEach(view.addSubview)

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
        btSetupButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(statusLabel.snp.bottom).offset(8)
            make.bottom.lessThanOrEqualTo(addButton.snp.top).offset(-8)
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
            do {
                self.sourceField.stringValue = try DownloadTorrentImporter.importTorrent(at: url)
                self.statusLabel.stringValue = ""
                self.btSetupButton.isHidden = true
            } catch {
                self.statusLabel.textColor = .systemRed
                self.statusLabel.stringValue = error.localizedDescription
            }
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
        guard !isSubmitting else { return }
        onCancel?()
        dismiss(self)
    }

    @objc private func btSetupTapped() {
        let handler = onOpenBTSettings
        onCancel?()
        dismiss(self)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
            handler?()
        }
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
        cancelButton.isEnabled = false
        btSetupButton.isHidden = true
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("正在添加…", comment: "")

        onSubmit(source, savePath, saveBookmark) { [weak self] result in
            guard let self else { return }
            self.isSubmitting = false
            self.addButton.isEnabled = true
            self.cancelButton.isEnabled = true
            switch result {
            case .success:
                self.dismiss(self)
            case .failure(let error):
                self.statusLabel.textColor = .systemRed
                self.statusLabel.stringValue = error.localizedDescription
                if let engineError = error as? DownloadEngineError, engineError.requiresBTSetup {
                    self.btSetupButton.isHidden = false
                }
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
    var notificationsEnabled: Bool
    var resetBTOnboarding: Bool
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
    private let testConnectionButton = NSButton(title: "", target: nil, action: nil)
    private let connectionLabel = NSTextField(labelWithString: "")
    private let resetOnboardingButton = NSButton(title: "", target: nil, action: nil)
    private let savePathLabel = NSTextField(labelWithString: "")
    private let concurrentPopup = NSPopUpButton()
    private let notificationsCheckbox = NSButton(checkboxWithTitle: "", target: nil, action: nil)
    private let notificationHintLabel = NSTextField(labelWithString: "")
    private let notificationSettingsButton = NSButton(title: "", target: nil, action: nil)
    private let statusLabel = NSTextField(labelWithString: "")
    private var savePath: String
    private var saveBookmark: Data?
    private var clearPassword = false
    private var isSaving = false
    private var isTesting = false
    private var resetBTOnboarding = false

    init(preferences: DownloadPreferences = .shared) {
        self.preferences = preferences
        self.savePath = preferences.defaultSavePath
        self.saveBookmark = preferences.defaultSaveBookmark
        super.init()
        preferredContentSize = NSSize(width: 600, height: 570)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 570))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.Download.settingsSheet)
        setupLayout()
        populate()
        refreshNotificationAuthorization()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        refreshNotificationAuthorization()
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

        testConnectionButton.title = NSLocalizedString("测试连接", comment: "")
        testConnectionButton.bezelStyle = .rounded
        testConnectionButton.controlSize = .small
        testConnectionButton.target = self
        testConnectionButton.action = #selector(testConnectionTapped)
        testConnectionButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsTestConnection)

        resetOnboardingButton.title = NSLocalizedString("重新显示 BT 引导", comment: "")
        resetOnboardingButton.bezelStyle = .inline
        resetOnboardingButton.isBordered = false
        resetOnboardingButton.controlSize = .small
        resetOnboardingButton.target = self
        resetOnboardingButton.action = #selector(resetOnboardingTapped)
        resetOnboardingButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsResetBTOnboarding)

        connectionLabel.font = .systemFont(ofSize: 11)
        connectionLabel.textColor = .secondaryLabelColor
        connectionLabel.lineBreakMode = .byTruncatingTail
        connectionLabel.setAccessibilityIdentifier(AccessibilityID.Download.settingsTestResult)

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
        chooseFolderButton.controlSize = .small
        chooseFolderButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsChooseFolder)

        let openFolderButton = NSButton(
            title: NSLocalizedString("打开下载文件夹", comment: ""),
            target: self,
            action: #selector(openFolderTapped)
        )
        openFolderButton.bezelStyle = .rounded
        openFolderButton.controlSize = .small
        openFolderButton.setAccessibilityIdentifier(AccessibilityID.Download.settingsOpenFolder)

        let concurrentLabel = Self.makeLabel(
            NSLocalizedString("最大同时下载数", comment: ""),
            font: .systemFont(ofSize: 11.5),
            color: .secondaryLabelColor
        )
        concurrentPopup.addItems(withTitles: (1...8).map { "\($0)" })
        concurrentPopup.setAccessibilityIdentifier(AccessibilityID.Download.settingsMaxConcurrent)

        notificationsCheckbox.title = NSLocalizedString("下载完成或失败时显示系统通知", comment: "")
        notificationsCheckbox.setAccessibilityIdentifier(AccessibilityID.Download.settingsNotifications)

        notificationHintLabel.font = .systemFont(ofSize: 10.5)
        notificationHintLabel.textColor = .secondaryLabelColor
        notificationHintLabel.lineBreakMode = .byTruncatingTail
        notificationHintLabel.setAccessibilityIdentifier(AccessibilityID.Download.settingsNotificationHint)

        notificationSettingsButton.title = NSLocalizedString("打开系统通知设置", comment: "")
        notificationSettingsButton.bezelStyle = .inline
        notificationSettingsButton.isBordered = false
        notificationSettingsButton.controlSize = .small
        notificationSettingsButton.target = self
        notificationSettingsButton.action = #selector(openNotificationSettingsTapped)
        notificationSettingsButton.isHidden = true
        notificationSettingsButton.setAccessibilityIdentifier(
            AccessibilityID.Download.settingsOpenNotificationSettings
        )

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
            testConnectionButton, connectionLabel, resetOnboardingButton,
            saveTitle, savePathLabel, chooseFolderButton, openFolderButton,
            concurrentLabel, concurrentPopup,
            notificationsCheckbox, notificationHintLabel, notificationSettingsButton,
            statusLabel, cancelButton, saveButton,
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

        testConnectionButton.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(httpsCheckbox.snp.bottom).offset(8)
        }
        resetOnboardingButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(testConnectionButton)
        }
        connectionLabel.snp.makeConstraints { make in
            make.leading.equalTo(testConnectionButton.snp.trailing).offset(10)
            make.trailing.equalTo(resetOnboardingButton.snp.leading).offset(-10)
            make.centerY.equalTo(testConnectionButton)
        }
        connectionLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        saveTitle.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(testConnectionButton.snp.bottom).offset(14)
        }
        chooseFolderButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(saveTitle.snp.bottom).offset(6)
        }
        openFolderButton.snp.makeConstraints { make in
            make.trailing.equalTo(chooseFolderButton.snp.leading).offset(-8)
            make.centerY.equalTo(chooseFolderButton)
        }
        savePathLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalTo(openFolderButton.snp.leading).offset(-12)
            make.centerY.equalTo(chooseFolderButton)
        }
        savePathLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        concurrentLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(concurrentPopup)
        }
        concurrentPopup.snp.makeConstraints { make in
            make.leading.equalTo(concurrentLabel.snp.trailing).offset(12)
            make.top.equalTo(openFolderButton.snp.bottom).offset(12)
            make.width.equalTo(80)
        }

        notificationsCheckbox.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalTo(concurrentPopup.snp.bottom).offset(14)
        }
        notificationSettingsButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(notificationsCheckbox)
        }
        notificationHintLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(notificationsCheckbox.snp.bottom).offset(2)
        }

        statusLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.trailing.equalToSuperview().offset(-24)
            make.top.equalTo(notificationHintLabel.snp.bottom).offset(10)
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
        notificationsCheckbox.state = preferences.notificationsEnabled ? .on : .off
        notificationsCheckbox.target = self
        notificationsCheckbox.action = #selector(notificationsToggled)
        updateSavePathLabel()
    }

    private func refreshNotificationAuthorization() {
        DownloadNotifier.shared.authorizationStatus { [weak self] status in
            DispatchQueue.main.async {
                guard let self else { return }
                let enabled = self.notificationsCheckbox.state == .on
                self.notificationSettingsButton.isHidden = true
                self.notificationHintLabel.textColor = .secondaryLabelColor

                guard enabled else {
                    self.notificationHintLabel.stringValue = NSLocalizedString("系统通知已关闭。", comment: "")
                    return
                }
                switch status {
                case .denied:
                    self.notificationHintLabel.textColor = .systemOrange
                    self.notificationHintLabel.stringValue = NSLocalizedString(
                        "系统通知权限被拒绝，请在系统设置中允许 AniXPlayer 通知。",
                        comment: ""
                    )
                    self.notificationSettingsButton.isHidden = false
                case .notDetermined:
                    self.notificationHintLabel.stringValue = NSLocalizedString(
                        "首次添加下载任务时会请求系统通知权限。",
                        comment: ""
                    )
                case .authorized, .provisional, .ephemeral:
                    self.notificationHintLabel.stringValue = NSLocalizedString(
                        "下载完成或失败时会显示通知，点击可定位任务。",
                        comment: ""
                    )
                @unknown default:
                    self.notificationHintLabel.stringValue = ""
                }
            }
        }
    }

    @objc private func notificationsToggled() {
        refreshNotificationAuthorization()
        if notificationsCheckbox.state == .on {
            DownloadNotifier.shared.requestAuthorizationIfNeeded(preferences: preferences)
        }
    }

    @objc private func testConnectionTapped() {
        guard !isTesting else { return }
        guard let port = Int(portField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)),
              (1...65535).contains(port) else {
            connectionLabel.textColor = .systemRed
            connectionLabel.stringValue = NSLocalizedString("端口必须是 1–65535 之间的整数", comment: "")
            portField.becomeFirstResponder()
            return
        }

        let password: String
        if clearPassword {
            password = passwordField.stringValue
        } else if !passwordField.stringValue.isEmpty {
            password = passwordField.stringValue
        } else {
            password = preferences.storedRPCPassword()
        }

        let configuration = TransmissionRPCConfiguration(
            host: hostField.stringValue,
            port: port,
            useHTTPS: httpsCheckbox.state == .on,
            username: usernameField.stringValue,
            password: password,
            sequentialDownload: sequentialCheckbox.state == .on
        )
        let client = TransmissionRPCClient(configuration: configuration)
        let endpoint = "\(configuration.rpcURL.host ?? hostField.stringValue):\(configuration.rpcURL.port ?? port)"

        isTesting = true
        testConnectionButton.isEnabled = false
        connectionLabel.textColor = .secondaryLabelColor
        connectionLabel.stringValue = NSLocalizedString("正在测试连接…", comment: "")

        Task { [weak self] in
            do {
                let info = try await client.sessionGet()
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isTesting = false
                    self.testConnectionButton.isEnabled = true
                    self.connectionLabel.textColor = .systemGreen
                    self.connectionLabel.stringValue = String(
                        format: NSLocalizedString("已连接 Transmission %@（RPC %d）", comment: ""),
                        info.version,
                        info.rpcVersion
                    )
                }
            } catch {
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.isTesting = false
                    self.testConnectionButton.isEnabled = true
                    self.connectionLabel.textColor = .systemRed
                    self.connectionLabel.stringValue = String(
                        format: NSLocalizedString("连接失败（%@）：%@", comment: ""),
                        endpoint,
                        error.localizedDescription
                    )
                }
            }
        }
    }

    @objc private func openFolderTapped() {
        let access = DownloadFileAccess.resolveDirectory(
            path: savePath,
            bookmark: saveBookmark
        )
        defer { access.securityScopedURL?.stopAccessingSecurityScopedResource() }
        do {
            try FileManager.default.createDirectory(
                at: access.url,
                withIntermediateDirectories: true
            )
            NSWorkspace.shared.open(access.url)
        } catch {
            statusLabel.textColor = .systemRed
            statusLabel.stringValue = error.localizedDescription
        }
    }

    @objc private func openNotificationSettingsTapped() {
        DownloadNotifier.shared.openNotificationSettings()
    }

    @objc private func resetOnboardingTapped() {
        resetBTOnboarding = true
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.stringValue = NSLocalizedString("保存后将重新显示 BT 未连接引导。", comment: "")
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
            password = passwordField.stringValue.isEmpty ? "" : passwordField.stringValue
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
            maxConcurrentDownloads: max(1, concurrentPopup.indexOfSelectedItem + 1),
            notificationsEnabled: notificationsCheckbox.state == .on,
            resetBTOnboarding: resetBTOnboarding
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
