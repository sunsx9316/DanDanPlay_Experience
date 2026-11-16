//
//  MembershipViewController.swift
//  AniXPlayer
//
//  macOS only：会员中心界面（参考 Windows MembershipWindow 重做）。
//
//  布局：900×680 固定窗口，左侧会员介绍，右侧用户卡 + 在线支付 / 礼品码。
//  支付记录与兑换记录使用独立 sheet，不在主窗口堆叠表格。
//

import AppKit
import Foundation
import SnapKit

private final class MembershipRootView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

/// 微信 / 支付宝支付渠道卡片。选中后使用主色边框与浅色背景。
private final class MembershipProviderCard: NSButton {
    let providerId: String
    private let providerName: String

    var isSelectedProvider: Bool = false {
        didSet { updateStyle() }
    }

    init(provider: MembershipPayConfig) {
        self.providerId = provider.providerId
        self.providerName = provider.providerName.isEmpty ? provider.providerId : provider.providerName
        super.init(frame: .zero)

        isBordered = false
        bezelStyle = .regularSquare
        setButtonType(.momentaryChange)
        imageScaling = .scaleProportionallyDown
        title = ""
        wantsLayer = true
        layer?.cornerRadius = 9
        layer?.borderWidth = 1

        switch providerId.lowercased() {
        case "wechat":
            image = Self.logo(named: "wechat")
            imagePosition = image == nil ? .noImage : .imageOnly
        case "alipay":
            image = Self.logo(named: "alipay")
            imagePosition = image == nil ? .noImage : .imageOnly
        default:
            imagePosition = .noImage
        }

        if image == nil {
            attributedTitle = NSAttributedString(
                string: providerName,
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
                    .foregroundColor: NSColor(white: 0.15, alpha: 1)
                ]
            )
        }

        toolTip = providerName
        setAccessibilityLabel(providerName)
        updateStyle()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        updateStyle()
    }

    func refreshAppearance() {
        updateStyle()
    }

    private func updateStyle() {
        layer?.borderWidth = isSelectedProvider ? 2 : 1
        layer?.borderColor = (isSelectedProvider
            ? NSColor.controlAccentColor
            : NSColor.separatorColor.withAlphaComponent(0.65)).cgColor
        // 微信/支付宝 logo 带深色文字，卡片固定用浅色底，避免深色模式下看不清。
        let selectedBackground = NSColor.controlAccentColor.blended(withFraction: 0.12, of: .white)
        layer?.backgroundColor = (isSelectedProvider
            ? (selectedBackground ?? .white)
            : NSColor.white).cgColor
    }

    private static func logo(named name: String) -> NSImage? {
        guard let image = NSImage(named: name)?.copy() as? NSImage else {
            return nil
        }
        let target = NSSize(width: 112, height: 34)
        let ratio = image.size.height > 0 ? image.size.width / image.size.height : 1
        if ratio >= target.width / target.height {
            image.size = NSSize(width: target.width, height: target.width / ratio)
        } else {
            image.size = NSSize(width: target.height * ratio, height: target.height)
        }
        image.isTemplate = false
        return image
    }
}

/// 时长列表的选中行使用系统主色，避免和 App 的其他绿色高亮混在一起。
private final class MembershipDurationRowView: NSTableRowView {
    override func drawSelection(in dirtyRect: NSRect) {
        guard selectionHighlightStyle != .none else { return }
        NSColor.controlAccentColor.withAlphaComponent(isEmphasized ? 0.24 : 0.14).setFill()
        NSBezierPath(roundedRect: bounds.insetBy(dx: 2, dy: 1), xRadius: 5, yRadius: 5).fill()
    }
}

/// 独立的购买记录 / 兑换记录 sheet。两种记录在同一张表里切换，避免主窗口拥挤。
final class MembershipHistorySheetViewController: NSViewController {
    enum Kind: Int {
        case orders = 0
        case redeems = 1

        var title: String {
            switch self {
            case .orders:
                return NSLocalizedString("会员购买记录", comment: "")
            case .redeems:
                return NSLocalizedString("会员兑换记录", comment: "")
            }
        }
    }

    private let viewModel: MembershipViewModel
    private var kind: Kind

    private let titleLabel = NSTextField(labelWithString: "")
    private let segmentedControl = NSSegmentedControl(
        labels: [
            NSLocalizedString("购买记录", comment: ""),
            NSLocalizedString("兑换记录", comment: "")
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let reloadButton = NSButton(title: NSLocalizedString("刷新", comment: ""), target: nil, action: nil)
    private let closeButton = NSButton(title: NSLocalizedString("关闭", comment: ""), target: nil, action: nil)
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()
    private let emptyLabel = NSTextField(labelWithString: "")
    private let statusLabel = NSTextField(labelWithString: "")
    private let spinner = NSProgressIndicator()

    private var isConfigured = false
    var onDismiss: (() -> Void)?

    init(viewModel: MembershipViewModel, kind: Kind) {
        self.viewModel = viewModel
        self.kind = kind
        super.init(nibName: nil, bundle: nil)
        preferredContentSize = NSSize(width: 800, height: 480)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 800, height: 480))
        view.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetWindow)
        buildUI()
        render()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        if viewModel.orderHistory.isEmpty && viewModel.redeemHistory.isEmpty && !viewModel.isLoadingHistory {
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.viewModel.loadHistory()
            }
        }
    }

    override func viewDidDisappear() {
        super.viewDidDisappear()
        onDismiss?()
    }

    func show(kind: Kind) {
        guard isViewLoaded else { return }
        self.kind = kind
        segmentedControl.selectedSegment = kind.rawValue
        configureColumns()
        render()
    }

    func reloadFromViewModel() {
        guard isViewLoaded else { return }
        render()
    }

    private func buildUI() {
        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        titleLabel.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetTitle)

        segmentedControl.selectedSegment = kind.rawValue
        segmentedControl.segmentStyle = .rounded
        segmentedControl.target = self
        segmentedControl.action = #selector(sectionChanged(_:))
        segmentedControl.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetControl)

        reloadButton.bezelStyle = .rounded
        reloadButton.target = self
        reloadButton.action = #selector(reloadTapped(_:))
        reloadButton.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetReloadButton)

        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.target = self
        closeButton.action = #selector(closeTapped(_:))
        closeButton.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetCloseButton)

        tableView.delegate = self
        tableView.dataSource = self
        tableView.rowHeight = 26
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.allowsMultipleSelection = false
        tableView.selectionHighlightStyle = .none
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetTable)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView

        emptyLabel.font = .systemFont(ofSize: 13)
        emptyLabel.textColor = .secondaryLabelColor
        emptyLabel.alignment = .center
        emptyLabel.maximumNumberOfLines = 2
        emptyLabel.lineBreakMode = .byWordWrapping
        emptyLabel.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetEmptyLabel)

        statusLabel.font = .systemFont(ofSize: 11)
        statusLabel.textColor = .secondaryLabelColor
        statusLabel.maximumNumberOfLines = 2
        statusLabel.lineBreakMode = .byWordWrapping
        statusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetStatusLabel)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false
        spinner.setAccessibilityIdentifier(AccessibilityID.Membership.historySheetSpinner)

        [titleLabel, segmentedControl, reloadButton, scrollView, emptyLabel, statusLabel, spinner, closeButton]
            .forEach(view.addSubview)

        titleLabel.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(20)
        }
        segmentedControl.snp.makeConstraints { make in
            make.leading.equalTo(titleLabel.snp.trailing).offset(20)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(220)
            make.height.equalTo(26)
        }
        reloadButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.centerY.equalTo(titleLabel)
            make.width.equalTo(70)
        }
        scrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(24)
            make.top.equalTo(titleLabel.snp.bottom).offset(16)
            make.bottom.equalTo(statusLabel.snp.top).offset(-8)
        }
        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(scrollView)
            make.leading.greaterThanOrEqualToSuperview().offset(48)
            make.trailing.lessThanOrEqualToSuperview().offset(-48)
        }
        spinner.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.centerY.equalTo(statusLabel)
            make.width.height.equalTo(14)
        }
        statusLabel.snp.makeConstraints { make in
            make.leading.equalTo(spinner.snp.trailing).offset(6)
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalTo(closeButton.snp.top).offset(-10)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-24)
            make.bottom.equalToSuperview().offset(-18)
            make.width.equalTo(86)
            make.height.equalTo(30)
        }

        configureColumns()
    }

    private func configureColumns() {
        for column in tableView.tableColumns {
            tableView.removeTableColumn(column)
        }

        let columns: [(String, CGFloat, String)]
        switch kind {
        case .orders:
            columns = [
                (NSLocalizedString("时间", comment: ""), 148, "time"),
                (NSLocalizedString("订单号", comment: ""), 140, "orderId"),
                (NSLocalizedString("商品", comment: ""), 160, "title"),
                (NSLocalizedString("金额", comment: ""), 80, "amount"),
                (NSLocalizedString("会员有效期至", comment: ""), 154, "expire")
            ]
        case .redeems:
            columns = [
                (NSLocalizedString("时间", comment: ""), 148, "time"),
                (NSLocalizedString("礼品码", comment: ""), 170, "promoCode"),
                (NSLocalizedString("天数", comment: ""), 64, "days"),
                (NSLocalizedString("会员有效期至", comment: ""), 154, "expire"),
                (NSLocalizedString("备注", comment: ""), 160, "description")
            ]
        }

        for (title, width, identifier) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(identifier))
            column.title = title
            column.width = width
            column.minWidth = 48
            tableView.addTableColumn(column)
        }

        isConfigured = true
        tableView.reloadData()
    }

    private func render() {
        guard isConfigured else { return }
        titleLabel.stringValue = kind.title
        emptyLabel.stringValue = (kind == .orders)
            ? NSLocalizedString("没有查询到会员购买记录", comment: "")
            : NSLocalizedString("没有查询到会员兑换记录", comment: "")

        let count = kind == .orders ? viewModel.orderHistory.count : viewModel.redeemHistory.count
        emptyLabel.isHidden = count > 0 || viewModel.isLoadingHistory
        tableView.reloadData()

        if viewModel.isLoadingHistory {
            statusLabel.stringValue = NSLocalizedString("正在加载…", comment: "")
            statusLabel.textColor = .secondaryLabelColor
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
            statusLabel.stringValue = viewModel.historyStatusMessage ?? ""
            statusLabel.textColor = viewModel.historyStatusMessage == nil ? .secondaryLabelColor : .systemOrange
        }
        reloadButton.isEnabled = !viewModel.isLoadingHistory
    }

    @objc private func sectionChanged(_ sender: Any?) {
        guard let newKind = Kind(rawValue: segmentedControl.selectedSegment) else { return }
        kind = newKind
        configureColumns()
        render()
    }

    @objc private func reloadTapped(_ sender: Any?) {
        Task { @MainActor [weak self] in
            await self?.viewModel.loadHistory()
        }
    }

    @objc private func closeTapped(_ sender: Any?) {
        dismiss(self)
    }
}

extension MembershipHistorySheetViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        switch kind {
        case .orders:
            return viewModel.orderHistory.count
        case .redeems:
            return viewModel.redeemHistory.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("history-cell-\(tableColumn.identifier.rawValue)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeCell(identifier: identifier)
        }

        cell.textField?.stringValue = text(for: tableColumn, row: row)
        cell.textField?.font = .systemFont(ofSize: 11.5)
        cell.textField?.textColor = .labelColor
        return cell
    }

    private func makeCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubview(textField)
        cell.textField = textField
        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(4)
            make.trailing.equalToSuperview().offset(-4)
            make.centerY.equalToSuperview()
        }
        return cell
    }

    private func text(for column: NSTableColumn, row: Int) -> String {
        switch kind {
        case .orders:
            guard row < viewModel.orderHistory.count else { return "" }
            let item = viewModel.orderHistory[row]
            switch column.identifier.rawValue {
            case "time":
                return MembershipDateFormatting.localDateTime(item.orderTime)
            case "orderId":
                return item.orderId
            case "title":
                return item.title
            case "amount":
                return item.displayAmount
            case "expire":
                return MembershipDateFormatting.localDateTime(item.toTime)
            default:
                return item.description
            }
        case .redeems:
            guard row < viewModel.redeemHistory.count else { return "" }
            let item = viewModel.redeemHistory[row]
            switch column.identifier.rawValue {
            case "time":
                return MembershipDateFormatting.localDateTime(item.redeemTime)
            case "promoCode":
                return item.promoCode
            case "days":
                return String(format: NSLocalizedString("%d 天", comment: ""), item.addDays)
            case "expire":
                return MembershipDateFormatting.localDateTime(item.toTime)
            default:
                return item.description
            }
        }
    }
}

final class MembershipViewController: NSViewController {
    private let viewModel: MembershipViewModel

    private let leftPane = NSView()
    private let rightPane = NSView()
    private let divider = NSView()

    // 左侧
    private let accentBar = NSView()
    private let titleLabel = NSTextField(labelWithString: NSLocalizedString("弹弹play 会员", comment: ""))
    private let featureCard = NSView()
    private let featureTitleLabel = NSTextField(labelWithString: "")
    private let featureSummaryLabel = NSTextField(labelWithString: "")
    private let introTitleLabel = NSTextField(labelWithString: NSLocalizedString("会员权益说明", comment: ""))
    private let introTextView = NSTextView()
    private let introScrollView = NSScrollView()
    private let headerStack = NSStackView()

    // 右侧用户卡
    private let statusCard = NSView()
    private let avatarImageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let userNameLabel = NSTextField(labelWithString: "")
    private let memberStatusLabel = NSTextField(labelWithString: "")
    private let memberDetailLabel = NSTextField(labelWithString: "")
    private let resmonitorLabel = NSTextField(labelWithString: "")

    private let segmentedControl = NSSegmentedControl(
        labels: [
            NSLocalizedString("在线支付", comment: ""),
            NSLocalizedString("礼品码", comment: "")
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )
    private let contentContainer = NSView()
    private let payView = NSView()
    private let redeemView = NSView()
    private let closeButton = NSButton(title: NSLocalizedString("关闭", comment: ""), target: nil, action: nil)

    // 支付表单
    private let payForm = NSView()
    private let providerSectionLabel = NSTextField(labelWithString: NSLocalizedString("选择支付方式", comment: ""))
    private let providerStack = NSStackView()
    private let durationSectionLabel = NSTextField(labelWithString: NSLocalizedString("选择会员时长", comment: ""))
    private let durationTableView = NSTableView()
    private let durationScrollView = NSScrollView()
    private let durationEmptyLabel = NSTextField(labelWithString: NSLocalizedString("暂无可购买的会员时长", comment: ""))
    private let priceLabel = NSTextField(labelWithString: "—")
    private let payButton = NSButton(title: NSLocalizedString("去支付", comment: ""), target: nil, action: nil)
    private let orderHistoryLink = NSButton()
    private let paymentInlineLabel = NSTextField(labelWithString: "")

    // 支付二维码面板
    private let paymentPanel = NSView()
    private let qrContainer = NSView()
    private let qrImageView = NSImageView()
    private let qrPlaceholderLabel = NSTextField(labelWithString: NSLocalizedString("二维码", comment: ""))
    private let paymentProviderLabel = NSTextField(labelWithString: "")
    private let paymentTitleLabel = NSTextField(labelWithString: "")
    private let paymentAmountLabel = NSTextField(labelWithString: "")
    private let paymentStatusLabel = NSTextField(labelWithString: "")
    private let paymentSpinner = NSProgressIndicator()
    private let countdownLabel = NSTextField(labelWithString: "")
    private let paymentNoteLabel = NSTextField(labelWithString: "")
    private let openWebButton = NSButton(title: NSLocalizedString("网页支付", comment: ""), target: nil, action: nil)
    private let cancelPaymentButton = NSButton(
        title: NSLocalizedString("取消支付", comment: ""),
        target: nil,
        action: nil
    )

    // 下单遮罩
    private let paymentOverlay = NSView()
    private let overlaySpinner = NSProgressIndicator()
    private let overlayStatusLabel = NSTextField(labelWithString: "")
    private let overlayCancelButton = NSButton(title: NSLocalizedString("取消", comment: ""), target: nil, action: nil)

    // 礼品码
    private let redeemField = NSTextField()
    private let pasteButton = NSButton()
    private let redeemButton = NSButton(title: NSLocalizedString("兑换", comment: ""), target: nil, action: nil)
    private let redeemSpinner = NSProgressIndicator()
    private let redeemStatusLabel = NSTextField(labelWithString: "")
    private let buyPromoCodeLink = NSButton()
    private let redeemHistoryLink = NSButton()

    private var countdownTimer: Timer?
    private var avatarTask: URLSessionDataTask?
    private var renderedAvatarURL: String? = ""
    private var renderedProviderSignature = ""
    private var renderedItemSignature = ""
    private var renderedIntroMarkdown: String?
    private var isSyncingDurationSelection = false
    private var purchaseStatusMessage: String?
    private weak var activeHistorySheet: MembershipHistorySheetViewController?

    init(viewModel: MembershipViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = MembershipRootView(frame: NSRect(x: 0, y: 0, width: 900, height: 680))
        root.wantsLayer = true
        root.onAppearanceChange = { [weak self] in
            self?.applyDynamicColors()
            self?.renderedIntroMarkdown = nil
            self?.render()
        }
        self.view = root

        root.widthAnchor.constraint(equalToConstant: 900).isActive = true
        root.heightAnchor.constraint(equalToConstant: 680).isActive = true

        buildLeftPane()
        buildRightPane()
        buildPayView()
        buildRedeemView()
        installLayout()
        installActions()

        viewModel.onUpdate = { [weak self] in
            self?.render()
        }
        render()
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        updateSectionVisibility()
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        startCountdownTimer()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()
        stopCountdownTimer()
    }

    deinit {
        stopCountdownTimer()
        avatarTask?.cancel()
    }

    // MARK: - Build UI

    private func buildLeftPane() {
        leftPane.translatesAutoresizingMaskIntoConstraints = false

        accentBar.wantsLayer = true
        accentBar.layer?.cornerRadius = 3
        accentBar.translatesAutoresizingMaskIntoConstraints = false

        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.setAccessibilityIdentifier(AccessibilityID.Membership.windowTitle)

        featureCard.wantsLayer = true
        featureCard.layer?.cornerRadius = 10
        featureCard.layer?.borderWidth = 1
        featureCard.translatesAutoresizingMaskIntoConstraints = false

        featureTitleLabel.font = .systemFont(ofSize: 13, weight: .semibold)
        featureTitleLabel.lineBreakMode = .byWordWrapping
        featureTitleLabel.maximumNumberOfLines = 2
        featureTitleLabel.translatesAutoresizingMaskIntoConstraints = false
        featureTitleLabel.setAccessibilityIdentifier(AccessibilityID.Membership.featureBanner)

        featureSummaryLabel.font = .systemFont(ofSize: 12)
        featureSummaryLabel.textColor = .secondaryLabelColor
        featureSummaryLabel.lineBreakMode = .byWordWrapping
        featureSummaryLabel.maximumNumberOfLines = 0
        featureSummaryLabel.translatesAutoresizingMaskIntoConstraints = false
        featureSummaryLabel.setAccessibilityIdentifier(AccessibilityID.Membership.featureSummaryLabel)

        featureCard.addSubview(featureTitleLabel)
        featureCard.addSubview(featureSummaryLabel)

        introTitleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        introTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        introTextView.isEditable = false
        introTextView.isSelectable = true
        introTextView.drawsBackground = false
        introTextView.textContainerInset = NSSize(width: 0, height: 6)
        introTextView.minSize = NSSize(width: 0, height: 0)
        introTextView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        introTextView.isVerticallyResizable = true
        introTextView.isHorizontallyResizable = false
        introTextView.autoresizingMask = [.width]
        introTextView.textContainer?.widthTracksTextView = true
        introTextView.textContainer?.containerSize = NSSize(
            width: 0,
            height: CGFloat.greatestFiniteMagnitude
        )
        introTextView.setAccessibilityIdentifier(AccessibilityID.Membership.introTextView)

        introScrollView.translatesAutoresizingMaskIntoConstraints = false
        introScrollView.hasVerticalScroller = true
        introScrollView.scrollerStyle = .overlay
        introScrollView.drawsBackground = false
        introScrollView.borderType = .noBorder
        introScrollView.documentView = introTextView
        introScrollView.setAccessibilityIdentifier(AccessibilityID.Membership.introScrollView)

        headerStack.orientation = .vertical
        headerStack.alignment = .leading
        headerStack.spacing = 16
        headerStack.translatesAutoresizingMaskIntoConstraints = false
        headerStack.addArrangedSubview(titleLabel)
        headerStack.addArrangedSubview(featureCard)
        headerStack.addArrangedSubview(introTitleLabel)

        leftPane.addSubview(accentBar)
        leftPane.addSubview(headerStack)
        leftPane.addSubview(introScrollView)

        accentBar.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.width.equalTo(100)
            make.height.equalTo(6)
        }
        headerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(accentBar.snp.bottom).offset(14)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        featureCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        featureTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.top.equalToSuperview().offset(12)
        }
        featureSummaryLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(14)
            make.top.equalTo(featureTitleLabel.snp.bottom).offset(4)
            make.bottom.equalToSuperview().offset(-12)
        }
        introTitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        introScrollView.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
            make.top.equalTo(headerStack.snp.bottom).offset(6)
        }

        featureCard.isHidden = true
    }

    private func buildRightPane() {
        rightPane.translatesAutoresizingMaskIntoConstraints = false

        statusCard.wantsLayer = true
        statusCard.layer?.cornerRadius = 10
        statusCard.layer?.borderWidth = 1
        statusCard.setAccessibilityIdentifier(AccessibilityID.Membership.statusCard)

        avatarImageView.wantsLayer = true
        avatarImageView.layer?.cornerRadius = 30
        avatarImageView.layer?.masksToBounds = true
        avatarImageView.imageScaling = .scaleProportionallyUpOrDown
        avatarImageView.setAccessibilityIdentifier(AccessibilityID.Membership.avatar)
        avatarImageView.setAccessibilityLabel(NSLocalizedString("用户头像", comment: ""))

        nameLabel.font = .systemFont(ofSize: 16, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberNameLabel)
        userNameLabel.font = .systemFont(ofSize: 12)
        userNameLabel.textColor = .secondaryLabelColor
        userNameLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberUserNameLabel)
        memberStatusLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        memberStatusLabel.lineBreakMode = .byTruncatingTail
        memberStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberStatusLabel)
        memberDetailLabel.font = .systemFont(ofSize: 11)
        memberDetailLabel.textColor = .secondaryLabelColor
        memberDetailLabel.lineBreakMode = .byTruncatingTail
        memberDetailLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberDetailLabel)
        resmonitorLabel.font = .systemFont(ofSize: 11)
        resmonitorLabel.textColor = .secondaryLabelColor
        resmonitorLabel.lineBreakMode = .byTruncatingTail
        resmonitorLabel.isHidden = true
        resmonitorLabel.setAccessibilityIdentifier(AccessibilityID.Membership.resmonitorLabel)

        let textStack = NSStackView(views: [
            nameLabel,
            userNameLabel,
            memberStatusLabel,
            memberDetailLabel,
            resmonitorLabel
        ])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        nameLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        userNameLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        memberStatusLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        memberDetailLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        resmonitorLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true

        statusCard.addSubview(avatarImageView)
        statusCard.addSubview(textStack)

        avatarImageView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(14)
            make.centerY.equalToSuperview()
            make.width.height.equalTo(60)
        }
        textStack.snp.makeConstraints { make in
            make.leading.equalTo(avatarImageView.snp.trailing).offset(14)
            make.trailing.equalToSuperview().offset(-14)
            make.centerY.equalToSuperview()
        }

        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentStyle = .rounded
        segmentedControl.setAccessibilityIdentifier(AccessibilityID.Membership.sectionControl)
        segmentedControl.target = self
        segmentedControl.action = #selector(sectionChanged(_:))

        contentContainer.translatesAutoresizingMaskIntoConstraints = false

        closeButton.translatesAutoresizingMaskIntoConstraints = false
        closeButton.bezelStyle = .rounded
        closeButton.keyEquivalent = "\u{1b}"
        closeButton.setAccessibilityIdentifier(AccessibilityID.Membership.closeButton)

        rightPane.addSubview(statusCard)
        rightPane.addSubview(segmentedControl)
        rightPane.addSubview(contentContainer)
        rightPane.addSubview(closeButton)

        statusCard.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalToSuperview()
            make.height.equalTo(92)
        }
        segmentedControl.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(statusCard.snp.bottom).offset(14)
            make.height.equalTo(28)
        }
        contentContainer.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(16)
            make.top.equalTo(segmentedControl.snp.bottom).offset(12)
            make.bottom.equalTo(closeButton.snp.top).offset(-12)
        }
        closeButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().inset(16)
            make.bottom.equalToSuperview()
            make.width.equalTo(90)
            make.height.equalTo(32)
        }
    }

    private func buildPayView() {
        payView.translatesAutoresizingMaskIntoConstraints = false
        payForm.translatesAutoresizingMaskIntoConstraints = false
        paymentPanel.translatesAutoresizingMaskIntoConstraints = false
        paymentOverlay.translatesAutoresizingMaskIntoConstraints = false

        providerSectionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        providerSectionLabel.textColor = .secondaryLabelColor
        providerSectionLabel.translatesAutoresizingMaskIntoConstraints = false

        providerStack.translatesAutoresizingMaskIntoConstraints = false
        providerStack.orientation = .horizontal
        providerStack.alignment = .centerY
        providerStack.distribution = .fillEqually
        providerStack.spacing = 12

        durationSectionLabel.font = .systemFont(ofSize: 12, weight: .medium)
        durationSectionLabel.textColor = .secondaryLabelColor
        durationSectionLabel.translatesAutoresizingMaskIntoConstraints = false

        durationTableView.delegate = self
        durationTableView.dataSource = self
        durationTableView.rowHeight = 36
        durationTableView.intercellSpacing = NSSize(width: 0, height: 0)
        durationTableView.headerView = nil
        durationTableView.backgroundColor = .clear
        durationTableView.focusRingType = .none
        durationTableView.selectionHighlightStyle = .regular
        durationTableView.allowsMultipleSelection = false
        durationTableView.columnAutoresizingStyle = .firstColumnOnlyAutoresizingStyle
        durationTableView.setAccessibilityIdentifier(AccessibilityID.Membership.durationList)

        let nameColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("name"))
        nameColumn.width = 190
        nameColumn.minWidth = 120
        durationTableView.addTableColumn(nameColumn)
        let priceColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("price"))
        priceColumn.width = 100
        priceColumn.minWidth = 80
        durationTableView.addTableColumn(priceColumn)

        durationScrollView.translatesAutoresizingMaskIntoConstraints = false
        durationScrollView.hasVerticalScroller = true
        durationScrollView.scrollerStyle = .overlay
        durationScrollView.drawsBackground = false
        durationScrollView.borderType = .noBorder
        durationScrollView.documentView = durationTableView
        durationScrollView.wantsLayer = true
        durationScrollView.layer?.cornerRadius = 7
        durationScrollView.layer?.borderWidth = 1

        durationEmptyLabel.font = .systemFont(ofSize: 12)
        durationEmptyLabel.textColor = .secondaryLabelColor
        durationEmptyLabel.alignment = .center
        durationEmptyLabel.translatesAutoresizingMaskIntoConstraints = false
        durationEmptyLabel.isHidden = true

        priceLabel.font = .systemFont(ofSize: 18, weight: .semibold)
        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.setAccessibilityIdentifier(AccessibilityID.Membership.priceLabel)

        payButton.translatesAutoresizingMaskIntoConstraints = false
        payButton.bezelStyle = .rounded
        payButton.controlSize = .large
        payButton.font = .systemFont(ofSize: 14, weight: .semibold)
        payButton.bezelColor = .controlAccentColor
        payButton.keyEquivalent = "\r"
        payButton.setAccessibilityIdentifier(AccessibilityID.Membership.payButton)

        configureLinkButton(
            orderHistoryLink,
            title: NSLocalizedString("查询会员购买记录", comment: ""),
            identifier: AccessibilityID.Membership.orderHistoryLink,
            action: #selector(orderHistoryTapped(_:))
        )

        paymentInlineLabel.font = .systemFont(ofSize: 11.5)
        paymentInlineLabel.lineBreakMode = .byWordWrapping
        paymentInlineLabel.maximumNumberOfLines = 4
        paymentInlineLabel.isHidden = true
        paymentInlineLabel.translatesAutoresizingMaskIntoConstraints = false
        paymentInlineLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentInlineLabel)

        let priceRow = NSView()
        priceRow.translatesAutoresizingMaskIntoConstraints = false
        priceRow.addSubview(priceLabel)
        priceRow.addSubview(payButton)
        priceLabel.snp.makeConstraints { make in
            make.leading.centerY.equalToSuperview()
        }
        payButton.snp.makeConstraints { make in
            make.trailing.centerY.equalToSuperview()
            make.width.equalTo(148)
            make.height.equalTo(40)
        }
        priceRow.heightAnchor.constraint(equalToConstant: 44).isActive = true

        let historyRow = NSView()
        historyRow.translatesAutoresizingMaskIntoConstraints = false
        historyRow.addSubview(orderHistoryLink)
        orderHistoryLink.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.height.equalTo(22)
        }
        historyRow.heightAnchor.constraint(equalToConstant: 22).isActive = true

        let bottomStack = NSStackView(views: [priceRow, paymentInlineLabel, historyRow])
        bottomStack.translatesAutoresizingMaskIntoConstraints = false
        bottomStack.orientation = .vertical
        bottomStack.alignment = .leading
        bottomStack.spacing = 6

        payForm.addSubview(providerSectionLabel)
        payForm.addSubview(providerStack)
        payForm.addSubview(durationSectionLabel)
        payForm.addSubview(durationScrollView)
        payForm.addSubview(durationEmptyLabel)
        payForm.addSubview(bottomStack)

        providerSectionLabel.snp.makeConstraints { make in
            make.leading.trailing.top.equalToSuperview()
        }
        providerStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(providerSectionLabel.snp.bottom).offset(8)
            make.height.equalTo(64)
        }
        durationSectionLabel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(providerStack.snp.bottom).offset(16)
        }
        durationScrollView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(durationSectionLabel.snp.bottom).offset(8)
            make.bottom.equalTo(bottomStack.snp.top).offset(-12)
        }
        durationEmptyLabel.snp.makeConstraints { make in
            make.center.equalTo(durationScrollView)
            make.leading.greaterThanOrEqualTo(durationScrollView).offset(12)
            make.trailing.lessThanOrEqualTo(durationScrollView).offset(-12)
        }
        bottomStack.snp.makeConstraints { make in
            make.leading.trailing.bottom.equalToSuperview()
        }
        priceRow.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true
        historyRow.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true
        paymentInlineLabel.widthAnchor.constraint(equalTo: bottomStack.widthAnchor).isActive = true

        buildPaymentPanel()
        buildPaymentOverlay()

        payView.addSubview(payForm)
        payView.addSubview(paymentPanel)
        payView.addSubview(paymentOverlay)
        for child in [payForm, paymentPanel, paymentOverlay] {
            child.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }
    }

    private func buildPaymentPanel() {
        paymentPanel.wantsLayer = true
        paymentPanel.layer?.cornerRadius = 10
        paymentPanel.layer?.borderWidth = 1
        paymentPanel.isHidden = true
        paymentPanel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentPanel)

        paymentProviderLabel.font = .systemFont(ofSize: 14, weight: .semibold)
        paymentProviderLabel.alignment = .center
        paymentProviderLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentProviderLabel)
        paymentTitleLabel.font = .systemFont(ofSize: 12)
        paymentTitleLabel.textColor = .secondaryLabelColor
        paymentTitleLabel.alignment = .center
        paymentTitleLabel.lineBreakMode = .byTruncatingTail
        paymentTitleLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentTitleLabel)
        paymentAmountLabel.font = .systemFont(ofSize: 24, weight: .bold)
        paymentAmountLabel.alignment = .center
        paymentAmountLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentAmountLabel)

        qrContainer.wantsLayer = true
        qrContainer.layer?.cornerRadius = 7
        qrContainer.layer?.borderWidth = 1
        qrContainer.translatesAutoresizingMaskIntoConstraints = false

        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrImageView.setAccessibilityIdentifier(AccessibilityID.Membership.qrCodeImage)
        qrImageView.setAccessibilityLabel(NSLocalizedString("支付二维码", comment: ""))

        qrPlaceholderLabel.font = .systemFont(ofSize: 12)
        qrPlaceholderLabel.textColor = .tertiaryLabelColor
        qrPlaceholderLabel.alignment = .center
        qrPlaceholderLabel.maximumNumberOfLines = 3
        qrPlaceholderLabel.lineBreakMode = .byWordWrapping
        qrPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false

        qrContainer.addSubview(qrImageView)
        qrContainer.addSubview(qrPlaceholderLabel)
        qrImageView.snp.makeConstraints { make in
            make.edges.equalToSuperview().inset(8)
        }
        qrPlaceholderLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(12)
            make.trailing.lessThanOrEqualToSuperview().offset(-12)
        }
        qrContainer.snp.makeConstraints { make in
            make.width.height.equalTo(212)
        }

        countdownLabel.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        countdownLabel.textColor = .secondaryLabelColor
        countdownLabel.alignment = .center
        countdownLabel.setAccessibilityIdentifier(AccessibilityID.Membership.countdownLabel)

        paymentStatusLabel.font = .systemFont(ofSize: 12)
        paymentStatusLabel.alignment = .center
        paymentStatusLabel.maximumNumberOfLines = 3
        paymentStatusLabel.lineBreakMode = .byWordWrapping
        paymentStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentStatusLabel)

        paymentSpinner.style = .spinning
        paymentSpinner.controlSize = .small
        paymentSpinner.isDisplayedWhenStopped = false
        paymentSpinner.setAccessibilityIdentifier(AccessibilityID.Membership.paymentSpinner)
        paymentSpinner.translatesAutoresizingMaskIntoConstraints = false
        paymentSpinner.widthAnchor.constraint(equalToConstant: 14).isActive = true
        paymentSpinner.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let statusRow = NSStackView(views: [paymentSpinner, paymentStatusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .centerY
        statusRow.spacing = 6
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        paymentStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        paymentNoteLabel.font = .systemFont(ofSize: 10.5)
        paymentNoteLabel.textColor = .tertiaryLabelColor
        paymentNoteLabel.maximumNumberOfLines = 2
        paymentNoteLabel.lineBreakMode = .byWordWrapping
        paymentNoteLabel.alignment = .center
        paymentNoteLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentNoteLabel)

        for button in [openWebButton, cancelPaymentButton] {
            button.bezelStyle = .rounded
            button.controlSize = .regular
        }
        openWebButton.setAccessibilityIdentifier(AccessibilityID.Membership.openWebButton)
        cancelPaymentButton.setAccessibilityIdentifier(AccessibilityID.Membership.cancelPaymentButton)
        openWebButton.isHidden = true

        let buttonRow = NSStackView(views: [cancelPaymentButton, openWebButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        cancelPaymentButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 96).isActive = true
        openWebButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 80).isActive = true

        let infoStack = NSStackView(views: [
            paymentProviderLabel,
            paymentTitleLabel,
            paymentAmountLabel,
            qrContainer,
            countdownLabel,
            statusRow,
            paymentNoteLabel,
            buttonRow
        ])
        infoStack.orientation = .vertical
        infoStack.alignment = .centerX
        infoStack.spacing = 6
        infoStack.translatesAutoresizingMaskIntoConstraints = false

        paymentTitleLabel.widthAnchor.constraint(equalTo: infoStack.widthAnchor).isActive = true
        paymentNoteLabel.widthAnchor.constraint(equalTo: infoStack.widthAnchor).isActive = true
        statusRow.widthAnchor.constraint(lessThanOrEqualTo: infoStack.widthAnchor).isActive = true
        paymentStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        paymentPanel.addSubview(infoStack)
        infoStack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
            make.top.greaterThanOrEqualToSuperview().offset(12)
            make.bottom.lessThanOrEqualToSuperview().offset(-12)
        }
    }

    private func buildPaymentOverlay() {
        paymentOverlay.wantsLayer = true
        paymentOverlay.layer?.cornerRadius = 10
        paymentOverlay.isHidden = true
        paymentOverlay.setAccessibilityIdentifier(AccessibilityID.Membership.paymentOverlay)

        overlaySpinner.style = .spinning
        overlaySpinner.controlSize = .regular
        overlaySpinner.isDisplayedWhenStopped = false
        overlaySpinner.setAccessibilityIdentifier(AccessibilityID.Membership.paymentOverlaySpinner)

        overlayStatusLabel.font = .systemFont(ofSize: 13, weight: .medium)
        overlayStatusLabel.alignment = .center
        overlayStatusLabel.maximumNumberOfLines = 2
        overlayStatusLabel.lineBreakMode = .byWordWrapping
        overlayStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentOverlayStatusLabel)

        overlayCancelButton.bezelStyle = .rounded
        overlayCancelButton.setAccessibilityIdentifier(AccessibilityID.Membership.paymentOverlayCancelButton)

        let stack = NSStackView(views: [overlaySpinner, overlayStatusLabel, overlayCancelButton])
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 14
        stack.translatesAutoresizingMaskIntoConstraints = false
        paymentOverlay.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.leading.greaterThanOrEqualToSuperview().offset(20)
            make.trailing.lessThanOrEqualToSuperview().offset(-20)
        }
        overlayCancelButton.widthAnchor.constraint(greaterThanOrEqualToConstant: 90).isActive = true
    }

    private func buildRedeemView() {
        redeemView.translatesAutoresizingMaskIntoConstraints = false

        redeemField.translatesAutoresizingMaskIntoConstraints = false
        redeemField.placeholderString = NSLocalizedString("输入礼品码", comment: "")
        redeemField.font = .monospacedSystemFont(ofSize: 14, weight: .regular)
        redeemField.alignment = .center
        redeemField.delegate = self
        redeemField.setAccessibilityIdentifier(AccessibilityID.Membership.redeemField)
        redeemField.target = self
        redeemField.action = #selector(redeemTapped(_:))

        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        pasteButton.isBordered = false
        pasteButton.bezelStyle = .inline
        pasteButton.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: NSLocalizedString("粘贴", comment: "")
        )
        pasteButton.imageScaling = .scaleProportionallyDown
        pasteButton.contentTintColor = .secondaryLabelColor
        pasteButton.toolTip = NSLocalizedString("粘贴", comment: "")
        pasteButton.setAccessibilityLabel(NSLocalizedString("粘贴", comment: ""))
        pasteButton.setAccessibilityIdentifier(AccessibilityID.Membership.pasteButton)

        redeemButton.translatesAutoresizingMaskIntoConstraints = false
        redeemButton.bezelStyle = .rounded
        redeemButton.controlSize = .large
        redeemButton.font = .systemFont(ofSize: 13, weight: .semibold)
        redeemButton.bezelColor = .controlAccentColor
        redeemButton.setAccessibilityIdentifier(AccessibilityID.Membership.redeemButton)

        let inputRow = NSStackView(views: [redeemField, pasteButton, redeemButton])
        inputRow.orientation = .horizontal
        inputRow.alignment = .centerY
        inputRow.spacing = 8
        inputRow.translatesAutoresizingMaskIntoConstraints = false
        redeemField.widthAnchor.constraint(equalToConstant: 190).isActive = true
        redeemField.heightAnchor.constraint(equalToConstant: 32).isActive = true
        pasteButton.widthAnchor.constraint(equalToConstant: 28).isActive = true
        pasteButton.heightAnchor.constraint(equalToConstant: 28).isActive = true
        redeemButton.widthAnchor.constraint(equalToConstant: 72).isActive = true
        redeemButton.heightAnchor.constraint(equalToConstant: 32).isActive = true

        redeemStatusLabel.font = .systemFont(ofSize: 12)
        redeemStatusLabel.alignment = .center
        redeemStatusLabel.maximumNumberOfLines = 4
        redeemStatusLabel.lineBreakMode = .byWordWrapping
        redeemStatusLabel.translatesAutoresizingMaskIntoConstraints = false
        redeemStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.redeemStatusLabel)

        redeemSpinner.style = .spinning
        redeemSpinner.controlSize = .small
        redeemSpinner.isDisplayedWhenStopped = false
        redeemSpinner.setAccessibilityIdentifier(AccessibilityID.Membership.redeemSpinner)
        redeemSpinner.translatesAutoresizingMaskIntoConstraints = false
        redeemSpinner.widthAnchor.constraint(equalToConstant: 14).isActive = true
        redeemSpinner.heightAnchor.constraint(equalToConstant: 14).isActive = true

        let statusRow = NSStackView(views: [redeemSpinner, redeemStatusLabel])
        statusRow.orientation = .horizontal
        statusRow.alignment = .top
        statusRow.spacing = 6
        statusRow.translatesAutoresizingMaskIntoConstraints = false
        redeemStatusLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        configureLinkButton(
            buyPromoCodeLink,
            title: NSLocalizedString("购买礼品码", comment: ""),
            identifier: AccessibilityID.Membership.buyPromoCodeLink,
            action: #selector(buyPromoCodeTapped(_:))
        )
        configureLinkButton(
            redeemHistoryLink,
            title: NSLocalizedString("查询会员兑换记录", comment: ""),
            identifier: AccessibilityID.Membership.redeemHistoryLink,
            action: #selector(redeemHistoryTapped(_:))
        )

        let links = NSStackView(views: [buyPromoCodeLink, redeemHistoryLink])
        links.orientation = .vertical
        links.alignment = .centerX
        links.spacing = 8
        links.translatesAutoresizingMaskIntoConstraints = false

        redeemView.addSubview(inputRow)
        redeemView.addSubview(statusRow)
        redeemView.addSubview(links)

        inputRow.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.centerY.equalToSuperview().offset(-12)
        }
        statusRow.snp.makeConstraints { make in
            make.top.equalTo(inputRow.snp.bottom).offset(14)
            make.leading.greaterThanOrEqualToSuperview().offset(16)
            make.trailing.lessThanOrEqualToSuperview().offset(-16)
            make.centerX.equalToSuperview()
            make.width.lessThanOrEqualTo(300)
        }
        links.snp.makeConstraints { make in
            make.centerX.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    private func installLayout() {
        let root = view
        leftPane.translatesAutoresizingMaskIntoConstraints = false
        rightPane.translatesAutoresizingMaskIntoConstraints = false
        divider.translatesAutoresizingMaskIntoConstraints = false
        divider.wantsLayer = true

        root.addSubview(leftPane)
        root.addSubview(divider)
        root.addSubview(rightPane)

        leftPane.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(24)
            make.top.equalToSuperview().offset(24)
            make.bottom.equalToSuperview().offset(-24)
            make.width.equalTo(500)
        }
        divider.snp.makeConstraints { make in
            make.leading.equalTo(leftPane.snp.trailing)
            make.top.bottom.equalTo(leftPane)
            make.width.equalTo(1)
        }
        rightPane.snp.makeConstraints { make in
            make.leading.equalTo(divider.snp.trailing)
            make.trailing.equalToSuperview().offset(-24)
            make.top.bottom.equalTo(leftPane)
        }

        contentContainer.addSubview(payView)
        contentContainer.addSubview(redeemView)
        for section in [payView, redeemView] {
            section.snp.makeConstraints { make in
                make.edges.equalToSuperview()
            }
        }

        applyDynamicColors()
    }

    private func installActions() {
        segmentedControl.target = self
        segmentedControl.action = #selector(sectionChanged(_:))
        payButton.target = self
        payButton.action = #selector(payTapped(_:))
        openWebButton.target = self
        openWebButton.action = #selector(openWebTapped(_:))
        cancelPaymentButton.target = self
        cancelPaymentButton.action = #selector(cancelPaymentTapped(_:))
        overlayCancelButton.target = self
        overlayCancelButton.action = #selector(cancelPaymentTapped(_:))
        pasteButton.target = self
        pasteButton.action = #selector(pasteTapped(_:))
        redeemButton.target = self
        redeemButton.action = #selector(redeemTapped(_:))
        closeButton.target = self
        closeButton.action = #selector(closeTapped(_:))
    }

    private func configureLinkButton(
        _ button: NSButton,
        title: String,
        identifier: String,
        action: Selector
    ) {
        button.isBordered = false
        button.bezelStyle = .inline
        button.target = self
        button.action = action
        button.setButtonType(.momentaryChange)
        button.setAccessibilityIdentifier(identifier)
        button.setAccessibilityLabel(title)
        updateLinkTitle(button, title: title)
    }

    private func updateLinkTitle(_ button: NSButton, title: String) {
        button.attributedTitle = NSAttributedString(
            string: title,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.linkColor
            ]
        )
    }

    private func applyDynamicColors() {
        accentBar.layer?.backgroundColor = NSColor.controlAccentColor.cgColor
        divider.layer?.backgroundColor = NSColor.separatorColor.withAlphaComponent(0.7).cgColor

        statusCard.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.58).cgColor
        statusCard.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.55).cgColor

        featureCard.layer?.backgroundColor = NSColor.controlAccentColor.withAlphaComponent(0.07).cgColor
        featureCard.layer?.borderColor = NSColor.controlAccentColor.withAlphaComponent(0.24).cgColor

        durationScrollView.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        durationTableView.backgroundColor = .clear

        paymentPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45).cgColor
        paymentPanel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        // 二维码面板保持白底，确保透明/浅色二维码在深色模式下仍可扫描。
        qrContainer.layer?.backgroundColor = NSColor.white.cgColor
        qrContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        qrPlaceholderLabel.textColor = NSColor(white: 0.42, alpha: 1)

        paymentOverlay.layer?.backgroundColor = NSColor.windowBackgroundColor.withAlphaComponent(0.94).cgColor
        overlayStatusLabel.textColor = .labelColor

        for case let card as MembershipProviderCard in providerStack.arrangedSubviews {
            card.refreshAppearance()
        }
    }

    // MARK: - Render

    private func render() {
        nameLabel.stringValue = viewModel.displayName
        userNameLabel.stringValue = viewModel.userNameText
        userNameLabel.isHidden = viewModel.userNameText.isEmpty
        memberStatusLabel.stringValue = viewModel.memberStatusText
        memberDetailLabel.stringValue = viewModel.memberDetailText

        if viewModel.isExpiringSoon {
            memberStatusLabel.textColor = .systemOrange
        } else if viewModel.hasActiveMembership {
            memberStatusLabel.textColor = .systemGreen
        } else {
            memberStatusLabel.textColor = .secondaryLabelColor
        }

        if let resmonitor = viewModel.resmonitorText {
            resmonitorLabel.stringValue = resmonitor
            resmonitorLabel.isHidden = false
        } else {
            resmonitorLabel.isHidden = true
        }

        renderFeature()
        loadAvatar(viewModel.avatarURLString)
        renderPayForm()
        renderPaymentState()
        renderRedeem()
        renderIntro()
        activeHistorySheet?.reloadFromViewModel()
    }

    private func renderFeature() {
        guard let feature = viewModel.feature else {
            featureCard.isHidden = true
            return
        }

        featureTitleLabel.stringValue = String(
            format: NSLocalizedString("会员功能：「%@」", comment: ""),
            feature.title
        )
        featureSummaryLabel.stringValue = feature.summary
        featureCard.isHidden = false
    }

    private func renderPayForm() {
        let providerSignature = viewModel.payConfigs
            .map { "\($0.providerId)|\($0.providerName)" }
            .joined(separator: ";")
        if providerSignature != renderedProviderSignature {
            renderedProviderSignature = providerSignature
            for view in providerStack.arrangedSubviews {
                providerStack.removeArrangedSubview(view)
                view.removeFromSuperview()
            }
            for provider in viewModel.payConfigs {
                let card = MembershipProviderCard(provider: provider)
                card.target = self
                card.action = #selector(providerCardTapped(_:))
                card.setAccessibilityIdentifier(AccessibilityID.Membership.providerCard(provider.providerId))
                providerStack.addArrangedSubview(card)
            }
        }

        for case let card as MembershipProviderCard in providerStack.arrangedSubviews {
            card.isSelectedProvider = card.providerId == viewModel.selectedProviderId
            card.isEnabled = !viewModel.isPaymentInProgress
        }

        let itemSignature = viewModel.currentItems
            .map { "\($0.id)|\($0.name)|\($0.price)|\($0.currency)" }
            .joined(separator: ";")
        if itemSignature != renderedItemSignature {
            renderedItemSignature = itemSignature
            durationTableView.reloadData()
        }
        syncDurationSelection()
        durationEmptyLabel.isHidden = !viewModel.currentItems.isEmpty
        durationTableView.isEnabled = !viewModel.isPaymentInProgress
        durationScrollView.alphaValue = viewModel.isPaymentInProgress ? 0.6 : 1

        priceLabel.stringValue = viewModel.selectedPriceText
        payButton.title = viewModel.payButtonTitle
        payButton.isEnabled = viewModel.canStartPayment
        payButton.bezelColor = payButton.isEnabled ? .controlAccentColor : nil
        renderPaymentInlineMessage()
    }

    private func syncDurationSelection() {
        guard !isSyncingDurationSelection else { return }
        guard let item = viewModel.selectedItem,
              let row = viewModel.currentItems.firstIndex(where: { $0.id == item.id }) else {
            durationTableView.deselectAll(nil)
            return
        }
        guard durationTableView.selectedRow != row else { return }

        isSyncingDurationSelection = true
        durationTableView.selectRowIndexes(IndexSet(integer: row), byExtendingSelection: false)
        durationTableView.scrollRowToVisible(row)
        isSyncingDurationSelection = false
    }

    private func renderPaymentInlineMessage() {
        switch viewModel.paymentState {
        case .success(_, _, _, let message):
            paymentInlineLabel.stringValue = message
            paymentInlineLabel.textColor = .systemGreen
            paymentInlineLabel.isHidden = false
        case .expired(_, let message):
            paymentInlineLabel.stringValue = message
            paymentInlineLabel.textColor = .systemOrange
            paymentInlineLabel.isHidden = false
        case .failed(_, let message):
            paymentInlineLabel.stringValue = message
            paymentInlineLabel.textColor = .systemRed
            paymentInlineLabel.isHidden = false
        case .cancelled:
            paymentInlineLabel.stringValue = NSLocalizedString(
                "已停止查询支付结果。如已付款请勿重复支付，可在购买记录中确认。",
                comment: ""
            )
            paymentInlineLabel.textColor = .systemOrange
            paymentInlineLabel.isHidden = false
        case .idle, .creating, .waiting:
            paymentInlineLabel.stringValue = ""
            paymentInlineLabel.isHidden = true
        }
    }

    private func renderPaymentState() {
        let state = viewModel.paymentState

        switch state {
        case .creating:
            payForm.isHidden = true
            paymentPanel.isHidden = true
            paymentOverlay.isHidden = false
            overlayStatusLabel.stringValue = NSLocalizedString("正在创建订单…", comment: "")
            overlaySpinner.startAnimation(nil)
            paymentSpinner.stopAnimation(nil)

        case .waiting(let presentation, let confirming):
            payForm.isHidden = true
            paymentPanel.isHidden = false
            paymentOverlay.isHidden = true
            overlaySpinner.stopAnimation(nil)

            paymentProviderLabel.stringValue = presentation.providerText
            paymentProviderLabel.textColor = .labelColor
            paymentTitleLabel.stringValue = presentation.title
            paymentAmountLabel.stringValue = presentation.amountText

            if let data = presentation.qrImageData, let image = NSImage(data: data) {
                qrImageView.image = image
                qrPlaceholderLabel.isHidden = true
            } else {
                qrImageView.image = nil
                qrPlaceholderLabel.stringValue = NSLocalizedString("请在网页中完成支付", comment: "")
                qrPlaceholderLabel.isHidden = false
            }

            if confirming {
                paymentStatusLabel.stringValue = NSLocalizedString("支付结果确认中，请勿重复付款", comment: "")
                paymentStatusLabel.textColor = .systemOrange
            } else {
                paymentStatusLabel.stringValue = presentation.statusNote
                    ?? NSLocalizedString("等待支付结果…", comment: "")
                paymentStatusLabel.textColor = .secondaryLabelColor
            }

            paymentSpinner.startAnimation(nil)
            openWebButton.isHidden = presentation.webURL == nil
            cancelPaymentButton.title = NSLocalizedString("取消支付", comment: "")
            paymentNoteLabel.stringValue = NSLocalizedString(
                "关闭支付面板只会停止本机查询，不会取消订单。如已付款请勿重复支付。",
                comment: ""
            )
            updateCountdownLabel()

        case .success, .expired, .failed, .cancelled, .idle:
            payForm.isHidden = false
            paymentPanel.isHidden = true
            paymentOverlay.isHidden = true
            paymentSpinner.stopAnimation(nil)
            overlaySpinner.stopAnimation(nil)
            countdownLabel.stringValue = ""
        }
    }

    private func renderRedeem() {
        let isRedeeming = viewModel.isRedeeming
        redeemButton.isEnabled = !isRedeeming
        redeemField.isEnabled = !isRedeeming
        pasteButton.isEnabled = !isRedeeming
        if isRedeeming {
            redeemSpinner.startAnimation(nil)
        } else {
            redeemSpinner.stopAnimation(nil)
        }

        if let message = purchaseStatusMessage {
            redeemStatusLabel.stringValue = message
            redeemStatusLabel.textColor = .systemOrange
        } else if let message = viewModel.redeemStatusMessage {
            redeemStatusLabel.stringValue = message
            redeemStatusLabel.textColor = viewModel.redeemSucceeded ? .systemGreen : .systemRed
        } else {
            redeemStatusLabel.stringValue = ""
        }
    }

    private func renderIntro() {
        guard renderedIntroMarkdown != viewModel.introMarkdown else { return }
        renderedIntroMarkdown = viewModel.introMarkdown
        introTextView.textStorage?.setAttributedString(Self.markdownText(viewModel.introMarkdown))
        introTextView.scrollToBeginningOfDocument(nil)
    }

    private func loadAvatar(_ urlString: String?) {
        guard urlString != renderedAvatarURL else { return }
        renderedAvatarURL = urlString
        avatarTask?.cancel()

        let placeholder = NSImage(
            systemSymbolName: "person.crop.circle",
            accessibilityDescription: NSLocalizedString("用户头像", comment: "")
        )
        guard let urlString = urlString, let url = URL(string: urlString) else {
            avatarImageView.image = placeholder
            return
        }

        avatarImageView.image = placeholder
        avatarTask = URLSession.shared.dataTask(with: url) { [weak self] data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { return }
            DispatchQueue.main.async {
                guard let self = self, self.renderedAvatarURL == urlString else { return }
                self.avatarImageView.image = image
            }
        }
        avatarTask?.resume()
    }

    // MARK: - Countdown

    private func startCountdownTimer() {
        guard countdownTimer == nil else { return }
        let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.updateCountdownLabel()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        countdownTimer = timer
    }

    private func stopCountdownTimer() {
        countdownTimer?.invalidate()
        countdownTimer = nil
    }

    private func updateCountdownLabel() {
        guard case .waiting(let presentation, _) = viewModel.paymentState else {
            countdownLabel.stringValue = ""
            return
        }
        guard let expireAt = presentation.expireAt else {
            countdownLabel.stringValue = ""
            return
        }
        let remaining = expireAt.timeIntervalSinceNow
        let prefix = presentation.providerId.lowercased() == "wechat"
            ? NSLocalizedString("二维码有效期", comment: "")
            : NSLocalizedString("支付剩余时间", comment: "")
        if remaining > 0 {
            countdownLabel.stringValue = prefix + " " + MembershipDateFormatting.countdown(seconds: remaining)
            countdownLabel.textColor = remaining < 60 ? .systemOrange : .secondaryLabelColor
        } else {
            countdownLabel.stringValue = NSLocalizedString("支付二维码已过期", comment: "")
            countdownLabel.textColor = .systemOrange
        }
    }

    // MARK: - Section

    private func updateSectionVisibility() {
        let isPayTab = segmentedControl.selectedSegment == 0
        payView.isHidden = !isPayTab
        redeemView.isHidden = isPayTab

        if isPayTab {
            payButton.keyEquivalent = "\r"
            redeemButton.keyEquivalent = ""
        } else {
            payButton.keyEquivalent = ""
            redeemButton.keyEquivalent = "\r"
        }
    }

    // MARK: - Actions

    @objc private func sectionChanged(_ sender: Any?) {
        updateSectionVisibility()
    }

    @objc private func providerCardTapped(_ sender: Any?) {
        guard let card = sender as? MembershipProviderCard else { return }
        purchaseStatusMessage = nil
        viewModel.selectProvider(id: card.providerId)
    }

    @objc private func payTapped(_ sender: Any?) {
        switch viewModel.paymentState {
        case .success, .expired, .failed, .cancelled:
            viewModel.resetPayment()
        default:
            break
        }
        purchaseStatusMessage = nil
        viewModel.startPayment()
    }

    @objc private func openWebTapped(_ sender: Any?) {
        viewModel.openWebPayment()
    }

    @objc private func cancelPaymentTapped(_ sender: Any?) {
        viewModel.cancelPayment()
    }

    @objc private func pasteTapped(_ sender: Any?) {
        purchaseStatusMessage = nil
        guard let text = NSPasteboard.general.string(forType: .string) else { return }
        redeemField.stringValue = Self.limitedPromoCode(text)
    }

    @objc private func redeemTapped(_ sender: Any?) {
        purchaseStatusMessage = nil
        let code = Self.limitedPromoCode(redeemField.stringValue)
        redeemField.stringValue = code
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            await self.viewModel.redeem(code: code)
            if self.viewModel.redeemSucceeded {
                self.redeemField.stringValue = ""
            }
        }
    }

    @objc private func buyPromoCodeTapped(_ sender: Any?) {
        guard let url = URL(string: "https://afdian.com/a/kaedei") else { return }
        if !NSWorkspace.shared.open(url) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(url.absoluteString, forType: .string)
            purchaseStatusMessage = NSLocalizedString(
                "无法打开浏览器，链接已复制到剪贴板",
                comment: ""
            )
            renderRedeem()
        }
    }

    @objc private func orderHistoryTapped(_ sender: Any?) {
        presentHistory(kind: .orders)
    }

    @objc private func redeemHistoryTapped(_ sender: Any?) {
        presentHistory(kind: .redeems)
    }

    @objc private func closeTapped(_ sender: Any?) {
        view.window?.performClose(nil)
    }

    private func presentHistory(kind: MembershipHistorySheetViewController.Kind) {
        if let active = activeHistorySheet {
            active.show(kind: kind)
            return
        }

        let sheet = MembershipHistorySheetViewController(viewModel: viewModel, kind: kind)
        activeHistorySheet = sheet
        sheet.onDismiss = { [weak self, weak sheet] in
            guard let self = self else { return }
            if self.activeHistorySheet === sheet {
                self.activeHistorySheet = nil
            }
        }
        presentAsSheet(sheet)
    }

    private static func limitedPromoCode(_ raw: String) -> String {
        let sanitized = MembershipViewModel.sanitizedPromoCode(raw)
        return String(sanitized.prefix(20))
    }

    // MARK: - Markdown（轻量渲染，失败也不阻塞会员中心）

    private static func markdownText(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 12.5)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2.5
        paragraph.paragraphSpacing = 4

        var lines = markdown.components(separatedBy: .newlines)
        // 窗口已有「弹弹play 会员」标题，服务端 Markdown 若以同名 H1 开头则跳过，避免重复。
        if let firstIndex = lines.firstIndex(where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }) {
            let first = lines[firstIndex].trimmingCharacters(in: .whitespaces)
            let normalized = first
                .replacingOccurrences(of: "#", with: "")
                .replacingOccurrences(of: " ", with: "")
                .lowercased()
            if first.hasPrefix("# "),
               normalized == "弹弹play会员" || normalized == "dandanplaymembership" {
                lines.remove(at: firstIndex)
            }
        }

        for rawLine in lines {
            var line = rawLine
            var font = bodyFont

            if line.hasPrefix("### ") {
                line = String(line.dropFirst(4))
                font = NSFont.systemFont(ofSize: 13, weight: .semibold)
            } else if line.hasPrefix("## ") {
                line = String(line.dropFirst(3))
                font = NSFont.systemFont(ofSize: 14, weight: .semibold)
            } else if line.hasPrefix("# ") {
                line = String(line.dropFirst(2))
                font = NSFont.systemFont(ofSize: 16, weight: .bold)
            } else if line.hasPrefix("- ") {
                line = "• " + String(line.dropFirst(2))
            }

            line = line.replacingOccurrences(of: "**", with: "")
            line = line.replacingOccurrences(of: "__", with: "")
            line = line.replacingOccurrences(of: "`", with: "")
            line = replacingMarkdownLinks(in: line)

            if line.isEmpty {
                result.append(NSAttributedString(
                    string: "\n",
                    attributes: [.font: bodyFont, .paragraphStyle: paragraph]
                ))
                continue
            }

            result.append(NSAttributedString(
                string: line + "\n",
                attributes: [
                    .font: font,
                    .foregroundColor: NSColor.labelColor,
                    .paragraphStyle: paragraph
                ]
            ))
        }
        return result
    }

    private static func replacingMarkdownLinks(in line: String) -> String {
        var output = line
        while let start = output.range(of: "["),
              let middle = output.range(of: "](", range: start.upperBound..<output.endIndex),
              let end = output.range(of: ")", range: middle.upperBound..<output.endIndex) {
            let title = output[start.upperBound..<middle.lowerBound]
            output.replaceSubrange(start.lowerBound..<end.upperBound, with: title)
        }
        return output
    }
}

// MARK: - Tables

extension MembershipViewController: NSTableViewDataSource, NSTableViewDelegate {
    func numberOfRows(in tableView: NSTableView) -> Int {
        return viewModel.currentItems.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn, row < viewModel.currentItems.count else { return nil }
        let item = viewModel.currentItems[row]
        let identifier = NSUserInterfaceItemIdentifier("duration-cell-\(tableColumn.identifier.rawValue)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeDurationCell(identifier: identifier)
        }

        if tableColumn.identifier.rawValue == "price" {
            cell.textField?.stringValue = item.formattedPrice
            cell.textField?.alignment = .right
            cell.textField?.font = .systemFont(ofSize: 12.5, weight: .medium)
        } else {
            cell.textField?.stringValue = item.name.isEmpty ? item.id : item.name
            cell.textField?.alignment = .left
            cell.textField?.font = .systemFont(ofSize: 13)
        }
        cell.textField?.textColor = .labelColor
        cell.setAccessibilityIdentifier(AccessibilityID.Membership.durationRowPrefix + item.id)
        return cell
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        let identifier = NSUserInterfaceItemIdentifier("membership-duration-row")
        if let rowView = tableView.makeView(withIdentifier: identifier, owner: nil) as? MembershipDurationRowView {
            return rowView
        }
        let rowView = MembershipDurationRowView()
        rowView.identifier = identifier
        return rowView
    }

    func tableViewSelectionDidChange(_ notification: Notification) {
        guard !isSyncingDurationSelection else { return }
        guard let tableView = notification.object as? NSTableView,
              tableView === durationTableView else { return }
        let row = tableView.selectedRow
        guard row >= 0, row < viewModel.currentItems.count else { return }
        viewModel.selectItem(id: viewModel.currentItems[row].id)
    }

    private func makeDurationCell(identifier: NSUserInterfaceItemIdentifier) -> NSTableCellView {
        let cell = NSTableCellView()
        cell.identifier = identifier
        let textField = NSTextField(labelWithString: "")
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.lineBreakMode = .byTruncatingTail
        cell.addSubview(textField)
        cell.textField = textField
        textField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(12)
            make.trailing.equalToSuperview().offset(-12)
            make.centerY.equalToSuperview()
        }
        return cell
    }
}

extension MembershipViewController: NSTextFieldDelegate {
    func controlTextDidChange(_ obj: Notification) {
        guard let field = obj.object as? NSTextField, field === redeemField else { return }
        purchaseStatusMessage = nil
        let limited = Self.limitedPromoCode(field.stringValue)
        if field.stringValue != limited {
            field.stringValue = limited
        }
    }
}
