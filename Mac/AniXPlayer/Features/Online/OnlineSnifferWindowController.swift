//
//  OnlineSnifferWindowController.swift
//  AniXPlayer
//
//  macOS：独立的「媒体嗅探」窗口。
//
//  与自动嗅探复用 OnlineStreamSniffer 的 JS hook，但把候选地址暴露到 UI：
//  用户可以浏览/登录网页、查看候选、复制地址、在浏览器打开或直接播放。
//  播放前仍做 Range 验证；401/403 不进入播放器，候选保持可见。
//

import Cocoa
import SnapKit
import WebKit

// MARK: - Candidate

struct OnlineSnifferCandidate: Equatable {
    let url: URL
    let pageURL: URL
    let kind: String
    let score: Int
}

// MARK: - Window controller

@MainActor
final class OnlineSnifferWindowController: NSWindowController, NSWindowDelegate {

    private let snifferViewController: OnlineSnifferViewController
    private let accessCheck: (NSWindow?) async -> Bool
    private var isPresenting = false
    private var pendingInitialURL: URL?

    var onPlay: ((OnlineEpisodeFile) -> Void)? {
        get { snifferViewController.onPlay }
        set { snifferViewController.onPlay = newValue }
    }

    init(accessCheck: @escaping (NSWindow?) async -> Bool = { _ in true }) {
        let viewController = OnlineSnifferViewController()
        self.snifferViewController = viewController
        self.accessCheck = accessCheck

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 1000, height: 700),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("媒体嗅探", comment: "")
        window.minSize = NSSize(width: 860, height: 560)
        window.isReleasedWhenClosed = false
        window.contentViewController = viewController
        window.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.window)
        window.setAccessibilityLabel(NSLocalizedString("媒体嗅探窗口", comment: ""))

        super.init(window: window)

        window.delegate = self
        window.center()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 单例窗口入口。第一次使用需要会员门禁；已打开的窗口直接前置。
    func present(initialURL: URL? = nil) {
        if let initialURL {
            pendingInitialURL = initialURL
        }
        if let window, window.isVisible {
            if let pendingInitialURL {
                snifferViewController.load(pendingInitialURL)
                self.pendingInitialURL = nil
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        guard !isPresenting else { return }
        isPresenting = true

        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.isPresenting = false }
            guard await self.accessCheck(self.window) else {
                self.pendingInitialURL = nil
                return
            }
            self.showWindow(nil)
            if let pendingInitialURL = self.pendingInitialURL {
                self.snifferViewController.load(pendingInitialURL)
                self.pendingInitialURL = nil
            }
            self.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    func windowWillClose(_ notification: Notification) {
        snifferViewController.stopLoading()
        snifferViewController.suspendWebMedia()
    }
}

// MARK: - View controller

@MainActor
final class OnlineSnifferViewController: ViewController, WKNavigationDelegate,
    WKScriptMessageHandler, NSTableViewDataSource, NSTableViewDelegate {

    var onPlay: ((OnlineEpisodeFile) -> Void)?

    private let webView: WKWebView
    private let urlField = NSTextField()
    private let statusLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .secondaryLabelColor
    )
    private let progressIndicator = NSProgressIndicator()
    private let candidateTable = NSTableView()
    private let candidateScroll = NSScrollView()
    private let candidateCountLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11, weight: .semibold),
        color: .labelColor
    )

    private let backButton: NSButton
    private let forwardButton: NSButton
    private let reloadButton: NSButton
    private let stopButton: NSButton
    private let goButton: NSButton
    private let openPageButton: NSButton
    private let copyButton: WelcomeShellClosureButton
    private let playButton: WelcomeShellClosureButton
    private let openCandidateButton: WelcomeShellClosureButton

    private var candidates: [OnlineSnifferCandidate] = []
    private var followedPlayerURLs = Set<String>()
    private var currentPageURL: URL?
    private var pendingInitialURL: URL?

    private static let fallbackBaseURL = URL(string: "https://invalid.local/")!

    // MARK: Init

    override init() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: OnlineStreamSniffer.mediaHookScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        configuration.userContentController = controller

        self.webView = WKWebView(frame: .zero, configuration: configuration)
        self.backButton = Self.makeToolButton(
            symbol: "chevron.left",
            tooltip: NSLocalizedString("后退", comment: ""),
            accessibilityID: AccessibilityID.OnlineSniffer.back
        )
        self.forwardButton = Self.makeToolButton(
            symbol: "chevron.right",
            tooltip: NSLocalizedString("前进", comment: ""),
            accessibilityID: AccessibilityID.OnlineSniffer.forward
        )
        self.reloadButton = Self.makeToolButton(
            symbol: "arrow.clockwise",
            tooltip: NSLocalizedString("重新加载", comment: ""),
            accessibilityID: AccessibilityID.OnlineSniffer.reload
        )
        self.stopButton = Self.makeToolButton(
            symbol: "xmark",
            tooltip: NSLocalizedString("停止加载", comment: ""),
            accessibilityID: AccessibilityID.OnlineSniffer.stop
        )
        self.goButton = Self.makeToolButton(
            symbol: "arrow.right.circle",
            tooltip: NSLocalizedString("打开地址", comment: ""),
            accessibilityID: AccessibilityID.OnlineSniffer.go
        )
        self.openPageButton = Self.makeToolButton(
            symbol: "safari",
            tooltip: NSLocalizedString("在浏览器打开当前页面", comment: ""),
            accessibilityID: AccessibilityID.OnlineSniffer.openInBrowser
        )
        self.copyButton = WelcomeShellClosureButton(title: NSLocalizedString("复制地址", comment: ""))
        self.playButton = WelcomeShellClosureButton(title: NSLocalizedString("播放所选", comment: ""))
        self.openCandidateButton = WelcomeShellClosureButton(
            title: NSLocalizedString("浏览器打开", comment: "")
        )

        super.init()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: Lifecycle

    override func loadView() {
        self.view = NSView(frame: NSRect(x: 0, y: 0, width: 1000, height: 700))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.window)
        setupWebView()
        setupLayout()
        updateNavigationButtons()
        updateSelectionButtons()
        if let pendingInitialURL {
            self.pendingInitialURL = nil
            loadPage(pendingInitialURL)
        }
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        layoutCandidateTable()
    }

    func stopLoading() {
        webView.stopLoading()
        setLoading(false)
    }

    /// 关闭窗口或把候选交给外部播放器时，暂停网页内的媒体，避免双份声音。
    func suspendWebMedia() {
        webView.evaluateJavaScript(
            """
            try {
              document.querySelectorAll('video, audio').forEach(function (element) {
                try { element.pause(); } catch (e) {}
              });
            } catch (e) {}
            """,
            completionHandler: nil
        )
    }

    // MARK: Public

    func load(_ url: URL) {
        guard let normalized = Self.normalizedPageURL(url) else {
            statusLabel.text = NSLocalizedString("只支持 http/https 地址。", comment: "")
            return
        }
        guard isViewLoaded else {
            pendingInitialURL = normalized
            return
        }
        loadPage(normalized)
    }

    // MARK: Setup

    private static func makeToolButton(
        symbol: String,
        tooltip: String,
        accessibilityID: String
    ) -> NSButton {
        let button = NSButton()
        button.bezelStyle = .rounded
        button.controlSize = .small
        button.image = NSImage(systemSymbolName: symbol, accessibilityDescription: tooltip)
        button.imagePosition = .imageOnly
        button.toolTip = tooltip
        button.setAccessibilityLabel(tooltip)
        button.setAccessibilityIdentifier(accessibilityID)
        return button
    }

    private func setupWebView() {
        webView.navigationDelegate = self
        webView.customUserAgent = OnlineHTTPClient.defaultUserAgent
        webView.configuration.userContentController.add(
            self,
            name: OnlineStreamSnifferSupport.messageHandlerName
        )
        if #available(macOS 13.3, *) {
            webView.isInspectable = false
        }
        webView.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.window)
    }

    private func setupLayout() {
        backButton.target = self
        backButton.action = #selector(goBack)
        forwardButton.target = self
        forwardButton.action = #selector(goForward)
        reloadButton.target = self
        reloadButton.action = #selector(reloadPage)
        stopButton.target = self
        stopButton.action = #selector(stopPage)
        goButton.target = self
        goButton.action = #selector(goFromField)
        openPageButton.target = self
        openPageButton.action = #selector(openCurrentPageInBrowser)

        urlField.placeholderString = "https://example.com/video"
        urlField.font = .monospacedSystemFont(ofSize: 11, weight: .regular)
        urlField.controlSize = .small
        urlField.target = self
        urlField.action = #selector(goFromField)
        urlField.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.urlField)
        urlField.setContentHuggingPriority(.defaultLow, for: .horizontal)
        urlField.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        statusLabel.text = NSLocalizedString(
            "输入网页地址，或从在线观看打开播放页；网页里发现的视频会列在右侧。",
            comment: ""
        )
        statusLabel.lineBreakMode = .byTruncatingMiddle
        statusLabel.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.status)

        progressIndicator.style = .bar
        progressIndicator.isIndeterminate = true
        progressIndicator.controlSize = .small
        progressIndicator.isHidden = true

        let toolbar = NSStackView(views: [
            backButton,
            forwardButton,
            reloadButton,
            stopButton,
            urlField,
            goButton,
            openPageButton
        ])
        toolbar.orientation = .horizontal
        toolbar.alignment = .centerY
        toolbar.spacing = 6

        let sidePanel = NSView()
        candidateCountLabel.text = NSLocalizedString("候选视频", comment: "")
        candidateCountLabel.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.candidateList)

        candidateTable.headerView = nil
        candidateTable.rowHeight = 56
        candidateTable.allowsMultipleSelection = false
        candidateTable.allowsEmptySelection = true
        candidateTable.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        candidateTable.usesAlternatingRowBackgroundColors = true
        candidateTable.delegate = self
        candidateTable.dataSource = self
        candidateTable.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.candidateList)
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("candidate"))
        column.resizingMask = .autoresizingMask
        candidateTable.addTableColumn(column)

        candidateScroll.documentView = candidateTable
        candidateScroll.hasVerticalScroller = true
        candidateScroll.autohidesScrollers = true
        candidateScroll.drawsBackground = false
        candidateScroll.borderType = .bezelBorder

        copyButton.bezelStyle = .rounded
        copyButton.controlSize = .small
        copyButton.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.copySelected)
        copyButton.onClick = { [weak self] in
            self?.copySelectedCandidate()
        }

        playButton.bezelStyle = .rounded
        playButton.controlSize = .small
        playButton.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.playSelected)
        playButton.onClick = { [weak self] in
            self?.playSelectedCandidate()
        }

        openCandidateButton.bezelStyle = .rounded
        openCandidateButton.controlSize = .small
        openCandidateButton.setAccessibilityIdentifier(AccessibilityID.OnlineSniffer.openSelectedInBrowser)
        openCandidateButton.onClick = { [weak self] in
            self?.openSelectedCandidateInBrowser()
        }

        let candidateButtons = NSStackView(views: [
            copyButton,
            openCandidateButton,
            NSView(),
            playButton
        ])
        candidateButtons.orientation = .horizontal
        candidateButtons.alignment = .centerY
        candidateButtons.spacing = 6

        sidePanel.addSubview(candidateCountLabel)
        sidePanel.addSubview(candidateScroll)
        sidePanel.addSubview(candidateButtons)

        view.addSubview(toolbar)
        view.addSubview(statusLabel)
        view.addSubview(progressIndicator)
        view.addSubview(webView)
        view.addSubview(sidePanel)

        toolbar.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.trailing.equalToSuperview().inset(10)
        }
        urlField.snp.makeConstraints { make in
            make.height.equalTo(22)
        }
        statusLabel.snp.makeConstraints { make in
            make.top.equalTo(toolbar.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview().inset(12)
        }
        progressIndicator.snp.makeConstraints { make in
            make.top.equalTo(statusLabel.snp.bottom).offset(4)
            make.leading.trailing.equalToSuperview().inset(12)
            make.height.equalTo(4).priority(.medium)
        }
        webView.snp.makeConstraints { make in
            make.top.equalTo(progressIndicator.snp.bottom).offset(6)
            make.leading.bottom.equalToSuperview().inset(10)
            make.trailing.equalTo(sidePanel.snp.leading).offset(-8)
        }
        sidePanel.snp.makeConstraints { make in
            make.top.equalTo(webView)
            make.trailing.equalToSuperview().offset(-10)
            make.bottom.equalToSuperview().offset(-10)
            make.width.equalTo(360)
        }
        candidateCountLabel.snp.makeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
        }
        candidateScroll.snp.makeConstraints { make in
            make.top.equalTo(candidateCountLabel.snp.bottom).offset(6)
            make.leading.trailing.equalToSuperview()
        }
        candidateButtons.snp.makeConstraints { make in
            make.top.equalTo(candidateScroll.snp.bottom).offset(8)
            make.leading.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    // MARK: Navigation

    @objc private func goFromField() {
        let raw = urlField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let value = raw.contains("://") ? raw : "https://\(raw)"
        guard let url = URL(string: value), let normalized = Self.normalizedPageURL(url) else {
            statusLabel.text = NSLocalizedString("地址无效，只支持 http/https。", comment: "")
            return
        }
        loadPage(normalized)
    }

    @objc private func goBack() {
        followedPlayerURLs.removeAll()
        webView.goBack()
        updateNavigationButtons()
    }

    @objc private func goForward() {
        followedPlayerURLs.removeAll()
        webView.goForward()
        updateNavigationButtons()
    }

    @objc private func reloadPage() {
        followedPlayerURLs.removeAll()
        if webView.url != nil {
            webView.reload()
        } else if let currentPageURL {
            loadPage(currentPageURL)
        }
    }

    @objc private func stopPage() {
        stopLoading()
        updateNavigationButtons()
    }

    @objc private func openCurrentPageInBrowser() {
        let url = webView.url ?? currentPageURL
        guard let url else { return }
        NSWorkspace.shared.open(url)
    }

    private func loadPage(_ url: URL) {
        currentPageURL = url
        urlField.stringValue = url.absoluteString
        followedPlayerURLs.removeAll()
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(OnlineHTTPClient.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        webView.load(request)
    }

    private func loadEmbeddedPlayer(_ url: URL) {
        var request = URLRequest(url: url)
        request.timeoutInterval = 30
        request.setValue(OnlineHTTPClient.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        if let pageURL = currentPageURL,
           let scheme = pageURL.scheme,
           let host = pageURL.host {
            request.setValue("\(scheme)://\(host)/", forHTTPHeaderField: "Referer")
        }
        webView.load(request)
    }

    private func updateNavigationButtons() {
        backButton.isEnabled = webView.canGoBack
        forwardButton.isEnabled = webView.canGoForward
    }

    private func setLoading(_ loading: Bool) {
        progressIndicator.isHidden = !loading
        if loading {
            progressIndicator.startAnimation(nil)
        } else {
            progressIndicator.stopAnimation(nil)
        }
        reloadButton.isEnabled = !loading
        stopButton.isEnabled = loading
    }

    // MARK: Candidates

    private func addCandidate(raw: String, kind: String, pageURL: URL?) {
        let baseURL = pageURL ?? currentPageURL ?? webView.url ?? Self.fallbackBaseURL
        guard let url = OnlineStreamSnifferSupport.normalize(raw, relativeTo: baseURL),
              OnlineStreamSnifferSupport.isVideoURL(url) else {
            return
        }
        guard candidates.count < 200 else { return }
        guard !candidates.contains(where: { $0.url == url }) else { return }

        let previousSelection = selectedCandidate?.url
        let score = OnlineStreamSnifferSupport.score(url: url, pageURL: baseURL)
        candidates.append(OnlineSnifferCandidate(
            url: url,
            pageURL: baseURL,
            kind: kind,
            score: score
        ))
        candidates.sort { lhs, rhs in
            if lhs.score != rhs.score {
                return lhs.score > rhs.score
            }
            return lhs.url.absoluteString < rhs.url.absoluteString
        }
        candidateTable.reloadData()
        layoutCandidateTable()
        if let previousSelection,
           let index = candidates.firstIndex(where: { $0.url == previousSelection }) {
            candidateTable.selectRowIndexes(IndexSet(integer: index), byExtendingSelection: false)
        } else if candidateTable.selectedRow < 0, !candidates.isEmpty {
            candidateTable.selectRowIndexes(IndexSet(integer: 0), byExtendingSelection: false)
        }
        updateSelectionButtons()
        candidateCountLabel.text = String(
            format: NSLocalizedString("候选视频（%d）", comment: ""),
            candidates.count
        )
        statusLabel.text = String(
            format: NSLocalizedString("发现 %d 个视频地址，选中后可复制或播放。", comment: ""),
            candidates.count
        )
        NSLog("[OnlineSnifferWindow] candidate %@ score=%d kind=%@", url.absoluteString, score, kind)
    }

    private var selectedCandidate: OnlineSnifferCandidate? {
        let row = candidateTable.selectedRow
        guard row >= 0, row < candidates.count else { return nil }
        return candidates[row]
    }

    private func layoutCandidateTable() {
        let clip = candidateScroll.contentView.bounds
        let width = max(clip.width, 300)
        let height = max(CGFloat(candidates.count) * candidateTable.rowHeight, clip.height)
        if abs(candidateTable.frame.width - width) > 0.5
            || abs(candidateTable.frame.height - height) > 0.5 {
            candidateTable.frame = NSRect(x: 0, y: 0, width: width, height: height)
            candidateTable.sizeLastColumnToFit()
        }
    }

    private func updateSelectionButtons() {
        let enabled = selectedCandidate != nil
        copyButton.isEnabled = enabled
        playButton.isEnabled = enabled
        openCandidateButton.isEnabled = enabled
    }

    private func copySelectedCandidate() {
        guard let candidate = selectedCandidate else { return }
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(candidate.url.absoluteString, forType: .string)
        statusLabel.text = NSLocalizedString("已复制视频地址。", comment: "")
    }

    private func openSelectedCandidateInBrowser() {
        guard let candidate = selectedCandidate else { return }
        NSWorkspace.shared.open(candidate.url)
    }

    private func playSelectedCandidate() {
        guard let candidate = selectedCandidate else { return }
        playButton.isEnabled = false
        statusLabel.text = NSLocalizedString("正在验证视频地址…", comment: "")

        let headers = OnlinePlaybackService.defaultStreamHeaders(pageURL: candidate.pageURL)
        Task { @MainActor [weak self] in
            guard let self else { return }
            defer { self.updateSelectionButtons() }

            do {
                try await OnlinePlaybackService.shared.validateStream(
                    url: candidate.url,
                    headers: headers
                )
            } catch {
                self.statusLabel.text = String(
                    format: NSLocalizedString("视频源不可用：%@", comment: ""),
                    error.localizedDescription
                )
                self.presentPlaybackError(error, candidate: candidate)
                return
            }

            let displayName = Self.displayName(for: candidate)
            let file = OnlineEpisodeFile(
                streamURL: candidate.url,
                displayName: displayName,
                headers: headers,
                pageURL: candidate.pageURL,
                sourceName: NSLocalizedString("媒体嗅探", comment: "")
            )
            guard let onPlay = self.onPlay else {
                self.statusLabel.text = NSLocalizedString(
                    "没有可用的播放器入口，请从「功能 → 媒体嗅探…」打开。",
                    comment: ""
                )
                return
            }
            self.statusLabel.text = String(
                format: NSLocalizedString("已发送到播放器：%@", comment: ""),
                displayName
            )
            self.suspendWebMedia()
            onPlay(file)
        }
    }

    private func presentPlaybackError(_ error: Error, candidate: OnlineSnifferCandidate) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("视频源不可用", comment: "")
        alert.informativeText = error.localizedDescription + "\n" + candidate.url.absoluteString
        alert.addButton(withTitle: NSLocalizedString("好", comment: ""))
        if let window = view.window {
            alert.beginSheetModal(for: window, completionHandler: nil)
        } else {
            alert.runModal()
        }
    }

    private static func displayName(for candidate: OnlineSnifferCandidate) -> String {
        let host = candidate.pageURL.host ?? NSLocalizedString("网页", comment: "")
        let lastPath = candidate.url.lastPathComponent
            .removingPercentEncoding?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if lastPath.isEmpty || lastPath == "/" {
            return "\(host) 视频"
        }
        return "\(host) \(lastPath)"
    }

    private static func normalizedPageURL(_ url: URL) -> URL? {
        guard let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              url.host != nil else {
            return nil
        }
        return url
    }

    // MARK: Scanning

    private func scanPage() {
        let script = """
        try {
          if (window.__anixScan) { window.__anixScan(); }
        } catch (e) {}
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        setLoading(true)
        statusLabel.text = NSLocalizedString("正在加载页面…", comment: "")
        updateNavigationButtons()
    }

    func webView(_ webView: WKWebView, didCommit navigation: WKNavigation!) {
        if let url = webView.url, Self.normalizedPageURL(url) != nil {
            currentPageURL = url
            urlField.stringValue = url.absoluteString
        }
        updateNavigationButtons()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        setLoading(false)
        if let url = webView.url, Self.normalizedPageURL(url) != nil {
            currentPageURL = url
            urlField.stringValue = url.absoluteString
        }
        statusLabel.text = NSLocalizedString("页面已加载，正在扫描网页中的视频…", comment: "")
        scanPage()
        for delay in [0.8, 2.0, 4.5] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.scanPage()
            }
        }
        updateNavigationButtons()
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        setLoading(false)
        statusLabel.text = String(
            format: NSLocalizedString("页面加载失败：%@", comment: ""),
            error.localizedDescription
        )
        updateNavigationButtons()
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        setLoading(false)
        statusLabel.text = String(
            format: NSLocalizedString("页面加载失败：%@", comment: ""),
            error.localizedDescription
        )
        updateNavigationButtons()
    }

    // MARK: WKScriptMessageHandler

    func userContentController(
        _ userContentController: WKUserContentController,
        didReceive message: WKScriptMessage
    ) {
        guard message.name == OnlineStreamSnifferSupport.messageHandlerName,
              let body = message.body as? [String: Any],
              let raw = body["url"] as? String else {
            return
        }
        let kind = body["kind"] as? String ?? ""
        let pageURL = currentPageURL ?? webView.url

        if kind == "player" {
            let value = OnlineStreamSnifferSupport.decodedEmbeddedPlayerValue(raw)
            let baseURL = pageURL ?? Self.fallbackBaseURL
            guard let url = OnlineStreamSnifferSupport.normalize(value, relativeTo: baseURL),
                  url.absoluteString != pageURL?.absoluteString else {
                return
            }
            if OnlineStreamSnifferSupport.isVideoURL(url) {
                addCandidate(raw: url.absoluteString, kind: kind, pageURL: pageURL)
            } else if followedPlayerURLs.insert(url.absoluteString).inserted {
                loadEmbeddedPlayer(url)
            }
            return
        }

        addCandidate(raw: raw, kind: kind, pageURL: pageURL)
    }

    // MARK: NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        return candidates.count
    }

    func tableView(
        _ tableView: NSTableView,
        viewFor tableColumn: NSTableColumn?,
        row: Int
    ) -> NSView? {
        guard row >= 0, row < candidates.count else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("OnlineSnifferCandidateCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self)
            as? OnlineSnifferCandidateCellView) ?? {
                let cell = OnlineSnifferCandidateCellView()
                cell.identifier = identifier
                return cell
            }()
        cell.configure(with: candidates[row], row: row)
        return cell
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        updateSelectionButtons()
    }
}

// MARK: - Candidate cell
private final class OnlineSnifferCandidateCellView: NSTableCellView {

    private let scoreLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11, weight: .bold),
        color: .secondaryLabelColor
    )
    private let urlLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10.5),
        color: .labelColor,
        lines: 2,
        lineBreakMode: .byTruncatingMiddle
    )
    private let detailLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 9.5),
        color: .tertiaryLabelColor
    )

    init() {
        super.init(frame: .zero)
        addSubview(scoreLabel)
        addSubview(urlLabel)
        addSubview(detailLabel)

        scoreLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
            make.width.equalTo(32)
        }
        urlLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(6)
            make.leading.equalTo(scoreLabel.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-4)
        }
        detailLabel.snp.makeConstraints { make in
            make.top.equalTo(urlLabel.snp.bottom).offset(2)
            make.leading.trailing.equalTo(urlLabel)
            make.bottom.lessThanOrEqualToSuperview().offset(-4)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(with candidate: OnlineSnifferCandidate, row: Int) {
        scoreLabel.text = "\(candidate.score)"
        scoreLabel.textColor = candidate.score >= 40 ? .systemGreen : .secondaryLabelColor
        urlLabel.text = candidate.url.absoluteString.removingPercentEncoding
            ?? candidate.url.absoluteString
        let kind = candidate.kind.isEmpty ? "media" : candidate.kind
        detailLabel.text = "\(kind) · \(candidate.pageURL.host ?? "")"
        setAccessibilityIdentifier("\(AccessibilityID.OnlineSniffer.candidateRowPrefix)\(row)")
        setAccessibilityLabel(candidate.url.absoluteString)
        toolTip = candidate.url.absoluteString
    }
}
