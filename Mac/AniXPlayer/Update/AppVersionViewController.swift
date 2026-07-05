//
//  AppVersionViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/26.
//

import Cocoa
import SnapKit

class AppVersionViewController: ViewController {

    // MARK: - Properties

    private(set) var appVersion: UpdateInfo!
    private lazy var appVersionModel = AppVersionModel()

    var onClickCancelCallBack: ((AppVersionViewController) -> Void)?
    var onClickOKCallBack: ((AppVersionViewController) -> Void)?

    // MARK: - Download State

    private var downloadTask: URLSessionDownloadTask?
    private var downloadSession: URLSession?
    private var isDownloading = false
    private var isFallback = false
    private var fallbackDownloadURL: String?

    // MARK: - UI Elements

    private lazy var iconView: ImageView = {
        let iv = ImageView()
        iv.image = NSApp.applicationIconImage
        iv.setScaling(.aspectFit)
        return iv
    }()

    private lazy var titleLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .boldSystemFont(ofSize: 18)
        tf.textColor = .labelColor
        return tf
    }()

    private lazy var descLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 13)
        tf.textColor = .secondaryLabelColor
        tf.lineBreakMode = .byWordWrapping
        tf.maximumNumberOfLines = 0
        tf.preferredMaxLayoutWidth = 390
        return tf
    }()

    private lazy var separator: NSBox = {
        let box = NSBox()
        box.boxType = .separator
        return box
    }()

    private lazy var progressBar: NSProgressIndicator = {
        let pi = NSProgressIndicator()
        pi.style = .bar
        pi.isIndeterminate = false
        pi.minValue = 0
        pi.maxValue = 1
        pi.doubleValue = 0
        pi.isHidden = true
        return pi
    }()

    private lazy var progressLabel: Label = {
        let tf = Label(labelWithString: "")
        tf.font = .systemFont(ofSize: 12)
        tf.textColor = .secondaryLabelColor
        tf.alignment = .center
        tf.isHidden = true
        return tf
    }()

    private lazy var cancelDownloadBtn: Button = {
        let btn = Button(title: NSLocalizedString("取消下载", comment: ""), target: self, action: #selector(cancelDownloadAction))
        btn.bezelStyle = .rounded
        btn.isHidden = true
        return btn
    }()

    private lazy var autoUpdateBtn: Button = {
        let btn = Button(title: NSLocalizedString("自动更新", comment: ""), target: self, action: #selector(autoUpdateAction))
        btn.bezelStyle = .rounded
        btn.keyEquivalent = "\r"
        btn.font = .systemFont(ofSize: 14, weight: .medium)
        return btn
    }()

    private lazy var manualDownloadBtn: Button = {
        let btn = Button(title: NSLocalizedString("手动下载", comment: ""), target: self, action: #selector(manualDownloadAction))
        btn.bezelStyle = .rounded
        btn.font = .systemFont(ofSize: 14)
        return btn
    }()

    private lazy var skipBtn: Button = {
        let btn = Button(title: NSLocalizedString("暂不更新", comment: ""), target: self, action: #selector(skipAction))
        btn.bezelStyle = .rounded
        btn.font = .systemFont(ofSize: 14)
        return btn
    }()

    // MARK: - Init

    init(appVersiotn: UpdateInfo) {
        self.appVersion = appVersiotn
        super.init()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
    }

    // MARK: - Lifecycle

    override func loadView() {
        view = BaseView(frame: NSRect(x: 0, y: 0, width: 460, height: 340))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        populateContent()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        view.window?.defaultButtonCell = autoUpdateBtn.cell as? NSButtonCell
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        downloadTask?.cancel()
        downloadTask = nil
        finishSession(cancel: true)
    }

    // MARK: - Setup

    private func setupUI() {
        view.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

        let views: [NSView] = [
            iconView, titleLabel, descLabel, separator,
            progressBar, progressLabel, cancelDownloadBtn,
            autoUpdateBtn, manualDownloadBtn, skipBtn
        ]
        views.forEach { v in
            v.translatesAutoresizingMaskIntoConstraints = false
            view.addSubview(v)
        }

        iconView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(28)
            make.leading.equalToSuperview().offset(28)
            make.width.height.equalTo(56)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView).offset(2)
            make.leading.equalTo(iconView.snp.trailing).offset(16)
            make.trailing.equalToSuperview().offset(-28)
        }

        descLabel.snp.makeConstraints { make in
            make.top.equalTo(iconView.snp.bottom).offset(14)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
        }

        separator.snp.makeConstraints { make in
            make.top.equalTo(descLabel.snp.bottom).offset(20)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
        }

        progressBar.snp.makeConstraints { make in
            make.top.equalTo(separator.snp.bottom).offset(16)
            make.leading.equalToSuperview().offset(28)
            make.trailing.equalToSuperview().offset(-28)
        }

        progressLabel.snp.makeConstraints { make in
            make.top.equalTo(progressBar.snp.bottom).offset(6)
            make.centerX.equalToSuperview()
        }

        cancelDownloadBtn.snp.makeConstraints { make in
            make.top.equalTo(progressLabel.snp.bottom).offset(12)
            make.centerX.equalToSuperview()
        }

        skipBtn.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(28)
            make.bottom.equalToSuperview().offset(-24)
        }

        manualDownloadBtn.snp.makeConstraints { make in
            make.leading.equalTo(skipBtn.snp.trailing).offset(12)
            make.centerY.equalTo(skipBtn)
        }

        autoUpdateBtn.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-28)
            make.centerY.equalTo(skipBtn)
        }
    }

    private func populateContent() {
        if let version = appVersion?.shortVersion {
            titleLabel.stringValue = String(format: NSLocalizedString("发现新版本 %@", comment: ""), version)
        } else {
            titleLabel.stringValue = NSLocalizedString("发现新版本", comment: "")
        }

        if let desc = appVersion?.desc, !desc.isEmpty, desc != "Unknown" {
            descLabel.stringValue = desc
        } else {
            descLabel.stringValue = NSLocalizedString("新版本包含功能改进与问题修复。", comment: "")
        }
    }

    // MARK: - UI State Transitions

    private func transitionToDownloading() {
        isDownloading = true
        autoUpdateBtn.isHidden = true
        manualDownloadBtn.isHidden = true
        skipBtn.isHidden = true

        progressBar.isHidden = false
        progressBar.doubleValue = 0
        progressLabel.isHidden = false
        progressLabel.stringValue = NSLocalizedString("正在下载...", comment: "")
        cancelDownloadBtn.isHidden = false
    }

    private func transitionToNormal() {
        isDownloading = false
        isFallback = false
        fallbackDownloadURL = nil

        progressBar.isHidden = true
        progressLabel.isHidden = true
        cancelDownloadBtn.isHidden = true

        autoUpdateBtn.isHidden = false
        manualDownloadBtn.isHidden = false
        skipBtn.isHidden = false
        skipBtn.title = NSLocalizedString("暂不更新", comment: "")
    }

    private func transitionToError(_ message: String) {
        isDownloading = false
        fallbackDownloadURL = nil
        finishSession(cancel: true)

        progressBar.isHidden = true
        cancelDownloadBtn.isHidden = true

        progressLabel.isHidden = false
        progressLabel.stringValue = message
        progressLabel.textColor = .systemRed

        autoUpdateBtn.isHidden = false
        autoUpdateBtn.title = NSLocalizedString("重试", comment: "")

        manualDownloadBtn.isHidden = false
        skipBtn.isHidden = false
        skipBtn.title = NSLocalizedString("取消", comment: "")
    }

    // MARK: - Actions

    @objc private func autoUpdateAction() {
        guard !isDownloading else { return }
        progressLabel.textColor = .secondaryLabelColor
        startAutoDownload()
    }

    @objc private func manualDownloadAction() {
        let hasGitee = validGiteeURL != nil

        if hasGitee {
            let popover = NSPopover()
            popover.behavior = .transient
            let vc = ManualDownloadPopoverViewController()
            vc.primaryURL = validGiteeURL ?? appVersion.url
            vc.fallbackURL = appVersion.url
            popover.contentViewController = vc
            popover.show(relativeTo: manualDownloadBtn.bounds, of: manualDownloadBtn, preferredEdge: .maxY)
        } else {
            guard let url = URL(string: appVersion.url) else { return }
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func skipAction() {
        if isDownloading {
            cancelDownload()
        } else {
            appVersionModel.updateIgnoreVersion(updateInfo: appVersion)
            onClickCancelCallBack?(self)
        }
    }

    @objc private func cancelDownloadAction() {
        cancelDownload()
    }

    // MARK: - Download Logic

    private var validGiteeURL: String? {
        let url = appVersion.giteeUrl
        guard !url.isEmpty, url != "Unknown", url != appVersion.url else {
            return nil
        }
        return url
    }

    private func startAutoDownload() {
        // 优先 Gitee（国内快），fallback 到 GitHub
        if let gitee = validGiteeURL {
            startDownload(from: gitee, fallbackURL: appVersion.url)
        } else {
            startDownload(from: appVersion.url, fallbackURL: nil)
        }
    }

    private func startDownload(from urlString: String, fallbackURL: String?) {
        guard let url = URL(string: urlString) else {
            transitionToError(NSLocalizedString("无效的下载地址", comment: ""))
            return
        }

        fallbackDownloadURL = fallbackURL
        isFallback = false
        transitionToDownloading()

        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        downloadSession = session
        downloadTask = session.downloadTask(with: url)
        downloadTask?.resume()
    }

    private func finishSession(cancel: Bool = false) {
        if cancel {
            downloadSession?.invalidateAndCancel()
        } else {
            downloadSession?.finishTasksAndInvalidate()
        }
        downloadSession = nil
    }

    private func cancelDownload() {
        downloadTask?.cancel()
        downloadTask = nil
        finishSession(cancel: true)
        transitionToNormal()
    }

    private func tryFallback() {
        downloadTask = nil
        finishSession(cancel: true)

        guard let fallback = fallbackDownloadURL, !fallback.isEmpty else {
            transitionToError(NSLocalizedString("下载失败，请尝试手动下载", comment: ""))
            return
        }

        fallbackDownloadURL = nil
        isFallback = true
        progressBar.doubleValue = 0
        progressLabel.stringValue = NSLocalizedString("主链接无法访问，正在切换备用链接...", comment: "")
        startDownload(from: fallback, fallbackURL: nil)
    }

    private func downloadCompleted(at location: URL) {
        downloadTask = nil
        finishSession()
        transitionToNormal()

        let dmgName = "AniXPlayer-\(appVersion.shortVersion).dmg"
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        let destURL = downloadsURL.appendingPathComponent(dmgName)

        try? FileManager.default.removeItem(at: destURL)

        do {
            try FileManager.default.moveItem(at: location, to: destURL)
        } catch {
            transitionToError(NSLocalizedString("保存文件失败", comment: ""))
            return
        }

        progressLabel.isHidden = false
        progressLabel.textColor = .secondaryLabelColor
        progressLabel.stringValue = NSLocalizedString("下载完成，正在安装...", comment: "")

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            guard let self = self else { return }

            let task = Process()
            task.launchPath = "/usr/bin/hdiutil"
            task.arguments = ["attach", destURL.path]
            task.launch()

            self.appVersionModel.updateIgnoreVersion(updateInfo: self.appVersion)
            self.onClickOKCallBack?(self)
        }
    }
}

// MARK: - URLSessionDownloadDelegate

extension AppVersionViewController: URLSessionDownloadDelegate {
    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didWriteData bytesWritten: Int64, totalBytesWritten: Int64, totalBytesExpectedToWrite: Int64) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let fraction = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
        progressBar.doubleValue = fraction
        let pct = Int(fraction * 100)
        let sizeMB = Double(totalBytesExpectedToWrite) / 1_048_576
        let downloadedMB = Double(totalBytesWritten) / 1_048_576
        progressLabel.stringValue = String(format: NSLocalizedString("正在下载... %d%% (%.1f / %.1f MB)", comment: ""), pct, downloadedMB, sizeMB)
    }

    func urlSession(_ session: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
        downloadCompleted(at: location)
    }

    func urlSession(_ session: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
        guard let error = error else { return }
        let nsError = error as NSError
        if nsError.domain == NSURLErrorDomain && nsError.code == NSURLErrorCancelled {
            return
        }
        if isFallback || fallbackDownloadURL == nil {
            transitionToError(NSLocalizedString("下载失败，请尝试手动下载", comment: ""))
        } else {
            tryFallback()
        }
    }
}

// MARK: - ManualDownloadPopoverViewController

private class ManualDownloadPopoverViewController: ViewController {

    var primaryURL: String = ""
    var fallbackURL: String = ""

    override func loadView() {
        view = BaseView(frame: NSRect(x: 0, y: 0, width: 160, height: 82))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let primaryBtn = Button(title: NSLocalizedString("主节点", comment: ""), target: self, action: #selector(openPrimary))
        primaryBtn.bezelStyle = .rounded
        view.addSubview(primaryBtn)
        primaryBtn.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.centerX.equalToSuperview()
            make.width.equalTo(120)
        }

        let fallbackBtn = Button(title: NSLocalizedString("备用节点", comment: ""), target: self, action: #selector(openFallback))
        fallbackBtn.bezelStyle = .rounded
        view.addSubview(fallbackBtn)
        fallbackBtn.snp.makeConstraints { make in
            make.top.equalTo(primaryBtn.snp.bottom).offset(8)
            make.centerX.equalToSuperview()
            make.width.equalTo(120)
        }
    }

    @objc private func openPrimary() {
        if let url = URL(string: primaryURL) {
            NSWorkspace.shared.open(url)
        }
        dismiss(nil)
    }

    @objc private func openFallback() {
        if let url = URL(string: fallbackURL) {
            NSWorkspace.shared.open(url)
        }
        dismiss(nil)
    }
}
