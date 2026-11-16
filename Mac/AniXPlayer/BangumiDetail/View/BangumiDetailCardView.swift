//
//  BangumiDetailCardView.swift
//  AniXPlayer
//
//  macOS：番剧详情页的卡片基类与整页状态。
//

import Cocoa
import SnapKit

/// 垂直 Stack：自动把每个 arrangedSubview 撑满宽度。
/// macOS 上仅靠 alignment = .width 在嵌套 Stack 里并不总是生效，
/// 这里用显式宽度约束保证标题/表单/行视图不会被挤到右侧。
final class BangumiDetailFullWidthStackView: NSStackView {

    override func addArrangedSubview(_ view: NSView) {
        super.addArrangedSubview(view)
        view.translatesAutoresizingMaskIntoConstraints = false
        view.widthAnchor.constraint(equalTo: widthAnchor).isActive = true
    }
}

/// 详情页每一块内容的外壳：统一圆角卡片、16pt 内边距和垂直 Stack。
class BangumiDetailCardView: NSView {

    let cardView = WelcomeShellCardView()
    let contentStack: BangumiDetailFullWidthStackView = {
        let stack = BangumiDetailFullWidthStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.distribution = .fill
        stack.spacing = 10
        stack.detachesHiddenViews = true
        stack.setHuggingPriority(.required, for: .vertical)
        return stack
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    /// 卡片内的标准标题行（不提供跳转时使用）。
    @discardableResult
    func addStaticHeader(title: String, symbolName: String) -> NSView {
        let icon = ImageView()
        icon.image = welcomeShellSymbol(symbolName, pointSize: 15, weight: .semibold)
        icon.contentTintColor = .mainColor
        icon.setScaling(.aspectFit)
        icon.snp.makeConstraints { make in
            make.width.height.equalTo(18)
        }

        let label = welcomeShellLabel(
            title,
            font: .systemFont(ofSize: 16, weight: .semibold),
            color: .labelColor
        )
        let row = NSStackView(views: [icon, label])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 7
        row.setContentHuggingPriority(.required, for: .vertical)
        contentStack.addArrangedSubview(row)
        return row
    }

    /// 卡片内的可点击标题行（用于「查看全部」）。
    @discardableResult
    func addHeader(
        title: String,
        hint: String? = nil,
        symbolName: String,
        identifier: String,
        onTap: @escaping () -> Void
    ) -> WelcomeShellCardHeaderView {
        let header = WelcomeShellCardHeaderView(
            title: title,
            hint: hint,
            symbolName: symbolName,
            identifier: identifier,
            onTap: onTap
        )
        contentStack.addArrangedSubview(header)
        return header
    }

    func makeViewAllButton(
        identifier: String,
        onTap: @escaping () -> Void
    ) -> WelcomeShellClosureButton {
        let button = WelcomeShellClosureButton(title: NSLocalizedString("查看全部", comment: ""))
        button.isBordered = false
        button.controlSize = .small
        button.contentTintColor = .mainColor
        button.font = .systemFont(ofSize: 12, weight: .medium)
        button.setAccessibilityIdentifier(identifier)
        button.onClick = onTap
        button.setContentHuggingPriority(.required, for: .horizontal)
        return button
    }

    private func setup() {
        addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        cardView.addSubview(contentStack)
        contentStack.snp.makeConstraints { make in
            make.top.leading.equalToSuperview().offset(16)
            make.trailing.equalToSuperview().offset(-16)
            make.bottom.equalToSuperview().offset(-16)
        }
    }
}

// MARK: - Whole page state

/// 加载 / 错误 / 未登录时的整页状态卡片。
final class BangumiDetailPageStateView: NSView {

    private let cardView = WelcomeShellCardView()
    private let spinner: NSProgressIndicator = {
        let indicator = NSProgressIndicator()
        indicator.style = .spinning
        indicator.controlSize = .small
        indicator.isDisplayedWhenStopped = false
        return indicator
    }()
    private let stateView = WelcomeShellStateView()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func showLoading() {
        cardView.isHidden = false
        spinner.isHidden = false
        spinner.startAnimation(nil)
        stateView.configure(title: NSLocalizedString("正在加载作品详情…", comment: ""))
    }

    func showError(_ message: String, onRetry: @escaping () -> Void) {
        stopLoading()
        cardView.isHidden = false
        stateView.configure(
            title: NSLocalizedString("加载失败", comment: ""),
            detail: message,
            actionTitle: NSLocalizedString("重试", comment: ""),
            onAction: onRetry
        )
        stateView.setActionAccessibilityIdentifier(AccessibilityID.BangumiDetail.stateAction)
    }

    func showLogin(onLogin: @escaping () -> Void) {
        stopLoading()
        cardView.isHidden = false
        stateView.configure(
            title: NSLocalizedString("需要登录", comment: ""),
            detail: NSLocalizedString("登录后查看作品详情", comment: ""),
            actionTitle: NSLocalizedString("登录", comment: ""),
            onAction: onLogin
        )
        stateView.setActionAccessibilityIdentifier(AccessibilityID.BangumiDetail.stateAction)
    }

    func hide() {
        stopLoading()
        cardView.isHidden = true
    }

    private func stopLoading() {
        spinner.stopAnimation(nil)
        spinner.isHidden = true
        stateView.reset()
    }

    private func setup() {
        setAccessibilityIdentifier(AccessibilityID.BangumiDetail.state)
        addSubview(cardView)
        cardView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        let stack = NSStackView(views: [spinner, stateView])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 10
        stack.detachesHiddenViews = true
        cardView.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.top.bottom.equalToSuperview().inset(18)
            make.leading.trailing.equalToSuperview().inset(18)
        }
    }
}
