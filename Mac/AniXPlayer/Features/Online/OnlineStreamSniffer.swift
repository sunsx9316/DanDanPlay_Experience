//
//  OnlineStreamSniffer.swift
//  AniXPlayer
//
//  macOS：用离屏 WKWebView + JS hook 嗅探动态播放页中的视频地址。
//
//  WKWebView 没有 WebView2 的 WebResourceRequested 全量拦截能力，
//  因此这里组合：
//  - fetch / XMLHttpRequest / setAttribute hook；
//  - video/source/iframe 的 DOM 扫描 + MutationObserver；
//  - performance.getEntriesByType('resource')；
//  - 页面内联脚本中的 .m3u8/.mp4 正则。
//
//  只用于在线观看的自动解析兜底；静态页面优先走 OnlineMediaResolver。
//

import AppKit
import Foundation
import WebKit

/// 自动嗅探与独立「媒体嗅探」窗口共用的判定逻辑。
enum OnlineStreamSnifferSupport {

    static let messageHandlerName = "anixMedia"

    /// 把 JS 报告的地址转成绝对的 http/https URL。
    static func normalize(_ raw: String, relativeTo baseURL: URL) -> URL? {
        var value = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")
        if value.hasPrefix("//") {
            value = "\(baseURL.scheme ?? "https"):" + value
        }
        guard let url = URL(string: value, relativeTo: baseURL)?.absoluteURL else {
            return nil
        }
        guard let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return nil
        }
        return url
    }

    static func isVideoURL(_ url: URL) -> Bool {
        let path = url.path.lowercased()
        if path.hasSuffix(".m3u8") || path.hasSuffix(".mp4")
            || path.hasSuffix(".flv") || path.hasSuffix(".mkv") {
            return true
        }
        let full = url.absoluteString.lowercased()
        return full.contains(".m3u8?")
            || full.contains(".mp4?")
            || full.contains(".flv?")
            || full.contains(".mkv?")
    }

    /// 候选分数：m3u8 优先，广告/占位视频降权，跨域 CDN 略加分。
    static func score(url: URL, pageURL: URL) -> Int {
        let path = url.path.lowercased()
        let full = url.absoluteString.lowercased()
        var score = 0
        if path.hasSuffix(".m3u8") || full.contains(".m3u8?") {
            score += 100
        } else if path.hasSuffix(".mp4") || full.contains(".mp4?") {
            score += 60
        } else if path.hasSuffix(".flv") || full.contains(".flv?") {
            score += 40
        } else if path.hasSuffix(".mkv") || full.contains(".mkv?") {
            score += 30
        }

        let negative = [
            "ad/", "ads/", "ads", "advert", "banner", "logo", "cover",
            "preview", "trailer", "sample", "doubleclick", "googlesyndication",
            "amazon-adsystem", "huawei", "tvc-"
        ]
        if negative.contains(where: { full.contains($0) }) {
            score -= 80
        }
        let positive = ["play", "video", "stream", "index", "hls", "media"]
        if positive.contains(where: { full.contains($0) }) {
            score += 20
        }
        if let pageHost = pageURL.host, let host = url.host, host != pageHost {
            score += 10
        }
        return score
    }

    /// 部分站点把真正的播放页放在 `player_aaaa.url` 里，并用 JS 解码/跳转。
    /// 这里还原出脚本里的原始值（base64 + 多次 percent 解码）。
    static func decodedEmbeddedPlayerValue(_ raw: String) -> String {
        var value = raw
            .replacingOccurrences(of: "\\/", with: "/")
            .replacingOccurrences(of: "&amp;", with: "&")

        if !value.contains("%"), !value.lowercased().hasPrefix("http"),
           let data = Data(base64Encoded: value, options: .ignoreUnknownCharacters),
           let decoded = String(data: data, encoding: .utf8) {
            value = decoded
        }
        for _ in 0..<3 {
            guard let decoded = value.removingPercentEncoding, decoded != value else { break }
            value = decoded
        }
        return value
    }
}

@MainActor
final class OnlineStreamSniffer {

    static let shared = OnlineStreamSniffer()

    private var activeSession: OnlineStreamSnifferSession?

    private init() {}

    /// 独立「媒体嗅探」窗口复用同一套 JS hook。
    static var mediaHookScript: String {
        return OnlineStreamSnifferSession.hookScript
    }

    func sniff(
        pageURL: URL,
        source: OnlineMediaSource,
        timeout: TimeInterval = 12
    ) async -> OnlineMediaMatch? {
        activeSession?.cancel()
        return await withCheckedContinuation { continuation in
            let session = OnlineStreamSnifferSession(
                pageURL: pageURL,
                source: source,
                timeout: timeout
            ) { [weak self] match in
                self?.activeSession = nil
                continuation.resume(returning: match)
            }
            activeSession = session
            session.start()
        }
    }
}

// MARK: - Session

@MainActor
private final class OnlineStreamSnifferSession: NSObject, WKScriptMessageHandler, WKNavigationDelegate {

    private let pageURL: URL
    private let source: OnlineMediaSource
    private let timeout: TimeInterval
    private let completion: (OnlineMediaMatch?) -> Void

    private var webView: WKWebView?
    private var window: NSWindow?
    private var timeoutWorkItem: DispatchWorkItem?
    private var settleWorkItem: DispatchWorkItem?
    private var isFinished = false
    private var firstCandidateAt: Date?
    private var bestURL: URL?
    private var bestScore = Int.min
    private var followedPlayerURLs = Set<String>()
    private var seenCandidates = Set<String>()

    init(
        pageURL: URL,
        source: OnlineMediaSource,
        timeout: TimeInterval,
        completion: @escaping (OnlineMediaMatch?) -> Void
    ) {
        self.pageURL = pageURL
        self.source = source
        self.timeout = timeout
        self.completion = completion
        super.init()
    }

    func start() {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .nonPersistent()
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.defaultWebpagePreferences.allowsContentJavaScript = true

        let controller = WKUserContentController()
        controller.addUserScript(WKUserScript(
            source: Self.hookScript,
            injectionTime: .atDocumentStart,
            forMainFrameOnly: false
        ))
        controller.add(self, name: OnlineStreamSnifferSupport.messageHandlerName)
        configuration.userContentController = controller

        let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 2, height: 2), configuration: configuration)
        webView.navigationDelegate = self
        webView.customUserAgent = source.userAgent.isEmpty ? OnlineHTTPClient.defaultUserAgent : source.userAgent
        if #available(macOS 13.3, *) {
            webView.isInspectable = false
        }
        self.webView = webView

        // 离屏窗口：WebKit 在完全不可见的视图里可能降频，这里用屏幕外 2x2 窗口。
        let window = NSWindow(
            contentRect: NSRect(x: -20000, y: -20000, width: 2, height: 2),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isReleasedWhenClosed = false
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .stationary]
        window.contentView = webView
        window.orderFrontRegardless()
        self.window = window

        installCookies {
            var request = URLRequest(url: self.pageURL)
            request.timeoutInterval = self.timeout
            request.setValue(webView.customUserAgent, forHTTPHeaderField: "User-Agent")
            if let referer = self.source.referer, !referer.isEmpty {
                request.setValue(referer, forHTTPHeaderField: "Referer")
            }
            webView.load(request)
        }

        let workItem = DispatchWorkItem { [weak self] in
            self?.finish(force: true)
        }
        timeoutWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + timeout, execute: workItem)
    }

    func cancel() {
        finish(force: true)
    }

    private func installCookies(_ completion: @escaping () -> Void) {
        guard !source.cookies.isEmpty else {
            completion()
            return
        }
        let store = webView?.configuration.websiteDataStore.httpCookieStore
        let pairs = source.cookies.split(separator: ";")
        let group = DispatchGroup()
        for pair in pairs {
            let parts = pair.split(separator: "=", maxSplits: 1).map(String.init)
            guard parts.count == 2 else { continue }
            let properties: [HTTPCookiePropertyKey: Any] = [
                .name: parts[0].trimmingCharacters(in: .whitespaces),
                .value: parts[1].trimmingCharacters(in: .whitespaces),
                .domain: pageURL.host ?? "",
                .path: "/"
            ]
            guard let cookie = HTTPCookie(properties: properties) else { continue }
            group.enter()
            store?.setCookie(cookie) {
                group.leave()
            }
        }
        group.notify(queue: .main) {
            completion()
        }
    }

    // MARK: WKNavigationDelegate

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        scanPage(in: webView)
        // 动态播放器常常在 DOMContentLoaded 之后才挂载；再扫几次。
        for delay in [0.8, 2.0, 4.0] {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self, weak webView] in
                guard let self = self, let webView = webView, !self.isFinished else { return }
                self.scanPage(in: webView)
            }
        }
    }

    func webView(
        _ webView: WKWebView,
        didFail navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(force: true)
    }

    func webView(
        _ webView: WKWebView,
        didFailProvisionalNavigation navigation: WKNavigation!,
        withError error: Error
    ) {
        finish(force: true)
    }

    private func scanPage(in webView: WKWebView) {
        let script = """
        try {
          if (window.__anixScan) { window.__anixScan(); }
          document.querySelectorAll('video').forEach(function(v) {
            try { v.muted = true; v.play().catch(function(){}); } catch (e) {}
          });
          // 部分站点需要点击播放按钮才会创建真正的播放器/iframe。
          setTimeout(function () {
            var nodes = document.querySelectorAll('.play, .player-play, .video-play, [class*="play-btn"], [class*="playBtn"], [class*="player"] [class*="play"]');
            for (var i = 0; i < nodes.length; i++) {
              var el = nodes[i];
              if (!el || el.__anixClicked) { continue; }
              el.__anixClicked = true;
              try { el.click(); } catch (e) {}
            }
          }, 900);
        } catch (e) {}
        """
        webView.evaluateJavaScript(script, completionHandler: nil)
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
        if kind == "player" {
            followEmbeddedPlayer(raw)
            return
        }
        consider(raw: raw)
    }

    private func consider(raw: String) {
        guard !isFinished else { return }
        guard let url = OnlineStreamSnifferSupport.normalize(raw, relativeTo: pageURL),
              OnlineStreamSnifferSupport.isVideoURL(url) else { return }
        guard seenCandidates.insert(url.absoluteString).inserted else { return }

        let score = OnlineStreamSnifferSupport.score(url: url, pageURL: pageURL)
        NSLog("[OnlineSniffer] candidate %@ score=%d", url.absoluteString, score)
        // 分数过低的多半是页面广告/占位视频；宁可失败也不要播放广告。
        guard score >= 40 else { return }
        if score > bestScore {
            bestScore = score
            bestURL = url
        }
        if firstCandidateAt == nil {
            firstCandidateAt = Date()
            // 给后续候选（尤其是 m3u8）一点时间超过广告片段。
            scheduleSettle(after: 4.0)
        }
    }

    private func scheduleSettle(after seconds: TimeInterval) {
        settleWorkItem?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.finish()
        }
        settleWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + seconds, execute: workItem)
    }

    private func finish(force: Bool = false) {
        guard !isFinished else { return }
        if !force, bestURL == nil, firstCandidateAt == nil {
            // 还没命中，继续等总超时。
            return
        }
        isFinished = true

        timeoutWorkItem?.cancel()
        settleWorkItem?.cancel()
        timeoutWorkItem = nil
        settleWorkItem = nil

        NSLog("[OnlineSniffer] finish best=%@", bestURL?.absoluteString ?? "nil")
        let match = bestURL.map {
            OnlineMediaMatch(
                url: $0,
                headers: source.videoHeaders(pageURL: pageURL),
                pageURL: pageURL
            )
        }
        cleanup()
        completion(match)
    }

    private func cleanup() {
        if let webView = webView {
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.configuration.userContentController.removeScriptMessageHandler(
                forName: OnlineStreamSnifferSupport.messageHandlerName
            )
        }
        window?.orderOut(nil)
        window?.contentView = nil
        window?.close()
        window = nil
        webView = nil
    }

    /// 部分站点把真正的播放页放在 `player_aaaa.url` 里，并用 JS 解码/跳转。
    /// 这里主动解码并跟随一次，避免离屏 WebView 因脚本/点击逻辑没有触发。
    private func followEmbeddedPlayer(_ raw: String) {
        let value = OnlineStreamSnifferSupport.decodedEmbeddedPlayerValue(raw)
        guard let url = OnlineStreamSnifferSupport.normalize(value, relativeTo: pageURL),
              url.absoluteString != pageURL.absoluteString else { return }
        guard followedPlayerURLs.insert(url.absoluteString).inserted else { return }
        if OnlineStreamSnifferSupport.isVideoURL(url) {
            consider(raw: url.absoluteString)
            return
        }
        NSLog("[OnlineSniffer] follow player page %@", url.absoluteString)
        var request = URLRequest(url: url)
        request.timeoutInterval = timeout
        request.setValue(webView?.customUserAgent ?? OnlineHTTPClient.defaultUserAgent, forHTTPHeaderField: "User-Agent")
        webView?.load(request)
    }

    // MARK: JS hook

    static let hookScript = #"""
    (function () {
      if (window.__anixMediaHooked) { return; }
      window.__anixMediaHooked = true;

      function report(url, kind) {
        try {
          if (!url) { return; }
          window.webkit.messageHandlers.anixMedia.postMessage({ url: String(url), kind: String(kind || "") });
        } catch (e) {}
      }

      function isMedia(url) {
        if (!url || typeof url !== 'string') { return false; }
        var value = url.toLowerCase();
        return value.indexOf('.m3u8') >= 0 || value.indexOf('.mp4') >= 0
          || value.indexOf('.flv') >= 0 || value.indexOf('.mkv') >= 0;
      }

      try {
        var originalFetch = window.fetch;
        if (originalFetch) {
          window.fetch = function () {
            try {
              var input = arguments[0];
              var url = typeof input === 'string' ? input : (input && input.url);
              if (isMedia(url)) { report(url, 'fetch'); }
            } catch (e) {}
            return originalFetch.apply(this, arguments);
          };
        }
      } catch (e) {}

      try {
        var originalOpen = XMLHttpRequest.prototype.open;
        XMLHttpRequest.prototype.open = function (method, url) {
          try { if (isMedia(url)) { report(url, 'xhr'); } } catch (e) {}
          return originalOpen.apply(this, arguments);
        };
      } catch (e) {}

      try {
        var originalSetAttribute = Element.prototype.setAttribute;
        Element.prototype.setAttribute = function (name, value) {
          try {
            if ((name === 'src' || name === 'href' || name === 'data-src') && isMedia(value)) {
              report(value, 'attr');
            }
          } catch (e) {}
          return originalSetAttribute.apply(this, arguments);
        };
      } catch (e) {}

      try {
        document.addEventListener('loadedmetadata', function (event) {
          var target = event.target;
          if (!target) { return; }
          if (target.src) { report(target.src, 'video'); }
          if (target.currentSrc) { report(target.currentSrc, 'video'); }
          target.querySelectorAll && target.querySelectorAll('source').forEach(function (source) {
            if (source.src) { report(source.src, 'source'); }
          });
        }, true);
        document.addEventListener('play', function (event) {
          var target = event.target;
          if (target && target.currentSrc) { report(target.currentSrc, 'play'); }
        }, true);
      } catch (e) {}

      function scan() {
        try {
          document.querySelectorAll('video, source, iframe').forEach(function (element) {
            var value = element.currentSrc || element.src;
            if (value) { report(value, element.tagName.toLowerCase()); }
          });
        } catch (e) {}

        try {
          performance.getEntriesByType('resource').forEach(function (entry) {
            if (entry && entry.name) { report(entry.name, 'performance'); }
          });
        } catch (e) {}

        try {
          var html = document.documentElement ? document.documentElement.innerHTML : '';
          var pattern = /https?:\\?\/\\?\/[^\s"'<>]+?\.(m3u8|mp4|flv|mkv)(\?[^\s"'<>]*)?/ig;
          var match;
          while ((match = pattern.exec(html)) !== null) {
            report(match[0].replace(/\\\//g, '/'), 'script');
          }
        } catch (e) {}

        try {
          var scripts = document.querySelectorAll('script');
          for (var i = 0; i < scripts.length; i++) {
            var text = scripts[i].textContent || '';
            if (text.indexOf('player_aaaa') < 0) { continue; }
            var playerMatch = text.match(/"url"\s*:\s*"([^"]+)"/);
            if (playerMatch && playerMatch[1]) { report(playerMatch[1], 'player'); }
          }
        } catch (e) {}
      }

      window.__anixScan = scan;

      try {
        var observer = new MutationObserver(function () { scan(); });
        if (document.documentElement) {
          observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src', 'href'] });
        } else {
          document.addEventListener('DOMContentLoaded', function () {
            observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['src', 'href'] });
            scan();
          }, true);
        }
      } catch (e) {}

      document.addEventListener('DOMContentLoaded', scan, true);
      window.addEventListener('load', scan, true);
      setTimeout(scan, 800);
      setTimeout(scan, 2000);
      setTimeout(scan, 4500);
    })();
    """#
}
