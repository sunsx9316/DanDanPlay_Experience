//
//  OAuthLoginWindowController.swift
//  AniXPlayer
//
//  macOS only：内嵌 WKWebView 的 OAuth 登录窗口。
//
//  服务端只接受已登记的同源 HTTPS 哨兵回调，因此不能用 ASWebAuthenticationSession。
//  WKWebView 对 302 是否触发 decidePolicyFor 并不稳定，所以同时监听
//  decidePolicyFor / didReceiveServerRedirect / didStartProvisional / didFinish，
//  并用一个轻量轮询兜底读取 webView.url。
//

import Cocoa
import WebKit

enum OAuthLoginError: LocalizedError {
    case cancelled

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return nil
        }
    }
}

@MainActor
final class OAuthLoginWindowController: NSWindowController {
    private let service: OAuthService
    private let transaction: OAuthTransaction
    private let webView: WKWebView
    private var completion: ((Result<Void, Error>) -> Void)?
    private var finished = false
    private var didHandleCallback = false
    private var pollTimer: Timer?

    init(
        service: OAuthService = OAuthService(),
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        self.service = service
        self.completion = completion

        let authorize = service.makeAuthorizeRequest()
        self.transaction = authorize.transaction

        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        self.webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 480, height: 720), configuration: configuration)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("登录弹弹play", comment: "")
        window.minSize = NSSize(width: 400, height: 560)
        window.isReleasedWhenClosed = false
        window.contentView = webView

        super.init(window: window)

        window.delegate = self
        window.center()

        webView.customUserAgent = service.environment.userAgent
        webView.navigationDelegate = self
        webView.uiDelegate = self
        webView.load(URLRequest(url: authorize.url))

        startPolling()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        pollTimer?.invalidate()
    }

    // MARK: - Callback

    private func startPolling() {
        let timer = Timer(timeInterval: 0.25, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.inspectCurrentURL()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        pollTimer = timer
    }

    private func inspectCurrentURL() {
        guard !finished, !didHandleCallback, let url = webView.url else { return }
        inspect(url)
    }

    private func inspect(_ url: URL) {
        guard !finished, !didHandleCallback else { return }
        guard OAuthCallback.matches(url, redirectURI: transaction.redirectURI) else { return }

        didHandleCallback = true
        webView.stopLoading()

        do {
            let code = try OAuthCallback.parse(url, expected: transaction)
            Task { @MainActor in
                do {
                    try await SessionStore.shared.signIn(code: code, transaction: self.transaction)
                    self.finish(.success(()))
                } catch {
                    self.finish(.failure(error))
                }
            }
        } catch {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard !finished else { return }
        finished = true
        pollTimer?.invalidate()
        pollTimer = nil
        webView.stopLoading()
        webView.navigationDelegate = nil
        window?.delegate = nil
        window?.close()

        let callback = completion
        completion = nil
        callback?(result)
    }
}

extension OAuthLoginWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        guard !finished else { return }
        finish(.failure(OAuthLoginError.cancelled))
    }
}

extension OAuthLoginWindowController: WKNavigationDelegate {
    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }

        if OAuthCallback.matches(url, redirectURI: transaction.redirectURI) {
            decisionHandler(.cancel)
            inspect(url)
            return
        }

        if let scheme = url.scheme?.lowercased(),
           ["file", "javascript", "data"].contains(scheme) {
            decisionHandler(.cancel)
            return
        }

        decisionHandler(.allow)
    }

    func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
        inspectCurrentURL()
    }

    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        inspectCurrentURL()
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        inspectCurrentURL()
    }
}

extension OAuthLoginWindowController: WKUIDelegate {
    /// 第三方登录/注册链接常用 target=_blank；没有这个实现时 WKWebView 会静默丢弃新窗口。
    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url else {
            return nil
        }

        if OAuthCallback.matches(url, redirectURI: transaction.redirectURI) {
            inspect(url)
        } else {
            webView.load(URLRequest(url: url))
        }
        return nil
    }
}
