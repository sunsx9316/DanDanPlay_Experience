//
//  MembershipViewController.swift
//  AniXPlayer
//
//  macOS only：会员中心界面（状态卡 / 在线支付 / 礼品码 / 购买记录 / 权益说明）。
//

import AppKit
import Foundation

private final class MembershipRootView: NSView {
    var onAppearanceChange: (() -> Void)?

    override func viewDidChangeEffectiveAppearance() {
        super.viewDidChangeEffectiveAppearance()
        onAppearanceChange?()
    }
}

final class MembershipViewController: NSViewController {
    private let viewModel: MembershipViewModel

    // 状态卡
    private let statusCard = NSView()
    private let avatarImageView = NSImageView()
    private let nameLabel = NSTextField(labelWithString: "")
    private let userNameLabel = NSTextField(labelWithString: "")
    private let memberStatusLabel = NSTextField(labelWithString: "")
    private let memberDetailLabel = NSTextField(labelWithString: "")
    private let featureBannerLabel = NSTextField(labelWithString: "")
    private let resmonitorLabel = NSTextField(labelWithString: "")

    // 分段
    private let segmentedControl = NSSegmentedControl(
        labels: [
            NSLocalizedString("在线支付", comment: ""),
            NSLocalizedString("礼品码", comment: ""),
            NSLocalizedString("购买记录", comment: "")
        ],
        trackingMode: .selectOne,
        target: nil,
        action: nil
    )

    private let contentContainer = NSView()
    private let payView = NSView()
    private let redeemView = NSView()
    private let historyView = NSView()

    // 支付
    private let providerPopup = NSPopUpButton()
    private let itemPopup = NSPopUpButton()
    private let priceLabel = NSTextField(labelWithString: "—")
    private let payButton = NSButton(title: NSLocalizedString("去支付", comment: ""), target: nil, action: nil)
    private let paymentPanel = NSView()
    private let qrContainer = NSView()
    private let qrImageView = NSImageView()
    private let qrPlaceholderLabel = NSTextField(labelWithString: NSLocalizedString("二维码", comment: ""))
    private let paymentProviderLabel = NSTextField(labelWithString: "")
    private let paymentTitleLabel = NSTextField(labelWithString: "")
    private let paymentAmountLabel = NSTextField(labelWithString: "")
    private let paymentStatusLabel = NSTextField(labelWithString: "")
    private let countdownLabel = NSTextField(labelWithString: "")
    private let paymentNoteLabel = NSTextField(labelWithString: "")
    private let openWebButton = NSButton(title: NSLocalizedString("打开网页支付", comment: ""), target: nil, action: nil)
    private let cancelPaymentButton = NSButton(title: NSLocalizedString("取消支付", comment: ""), target: nil, action: nil)

    // 礼品码
    private let redeemField = NSTextField()
    private let pasteButton = NSButton(title: NSLocalizedString("粘贴", comment: ""), target: nil, action: nil)
    private let redeemButton = NSButton(title: NSLocalizedString("兑换", comment: ""), target: nil, action: nil)
    private let redeemStatusLabel = NSTextField(labelWithString: "")
    private let redeemHistoryTable = NSTableView()
    private let historyRedeemTable = NSTableView()

    // 购买记录
    private let orderTable = NSTableView()
    private let historyReloadButton = NSButton(title: NSLocalizedString("刷新", comment: ""), target: nil, action: nil)
    private let historyStatusLabel = NSTextField(labelWithString: "")

    // 会员介绍
    private let introTitleLabel = NSTextField(labelWithString: NSLocalizedString("会员权益说明", comment: ""))
    private let introTextView = NSTextView()
    private let introScrollView = NSScrollView()

    private enum TableTag: Int {
        case orders = 1
        case redeems = 2
    }

    private var countdownTimer: Timer?
    private var avatarTask: URLSessionDataTask?
    private var renderedAvatarURL: String?
    private var renderedProviderIds: [String] = []
    private var renderedItemIds: [String] = []
    private var renderedIntroMarkdown: String?

    init(viewModel: MembershipViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        let root = MembershipRootView(frame: NSRect(x: 0, y: 0, width: 760, height: 680))
        root.wantsLayer = true
        root.onAppearanceChange = { [weak self] in
            self?.applyDynamicColors()
            self?.renderedIntroMarkdown = nil
            self?.render()
        }
        self.view = root

        // 防止窗口按 fittingSize 收缩到 200pt：会员页内容没有天然的最小宽度。
        root.widthAnchor.constraint(greaterThanOrEqualToConstant: 720).isActive = true

        buildStatusCard()
        buildSegmentedControl()
        buildPayView()
        buildRedeemView()
        buildHistoryView()
        buildIntro()
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

    private func buildStatusCard() {
        statusCard.translatesAutoresizingMaskIntoConstraints = false
        statusCard.wantsLayer = true
        statusCard.layer?.cornerRadius = 10
        statusCard.layer?.borderWidth = 1
        statusCard.setAccessibilityIdentifier(AccessibilityID.Membership.statusCard)

        avatarImageView.translatesAutoresizingMaskIntoConstraints = false
        avatarImageView.wantsLayer = true
        avatarImageView.layer?.cornerRadius = 8
        avatarImageView.layer?.masksToBounds = true
        avatarImageView.imageScaling = .scaleProportionallyUpOrDown
        avatarImageView.setAccessibilityIdentifier(AccessibilityID.Membership.avatar)
        avatarImageView.setAccessibilityLabel(NSLocalizedString("用户头像", comment: ""))

        nameLabel.font = NSFont.systemFont(ofSize: 17, weight: .semibold)
        nameLabel.lineBreakMode = .byTruncatingTail
        nameLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberNameLabel)
        userNameLabel.font = NSFont.systemFont(ofSize: 12)
        userNameLabel.textColor = .secondaryLabelColor
        userNameLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberUserNameLabel)
        memberStatusLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        memberStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberStatusLabel)
        memberDetailLabel.font = NSFont.systemFont(ofSize: 12)
        memberDetailLabel.textColor = .secondaryLabelColor
        memberDetailLabel.setAccessibilityIdentifier(AccessibilityID.Membership.memberDetailLabel)

        featureBannerLabel.font = NSFont.systemFont(ofSize: 12, weight: .medium)
        featureBannerLabel.textColor = .systemOrange
        featureBannerLabel.lineBreakMode = .byTruncatingTail
        featureBannerLabel.isHidden = true
        featureBannerLabel.setAccessibilityIdentifier(AccessibilityID.Membership.featureBanner)

        resmonitorLabel.font = NSFont.systemFont(ofSize: 11)
        resmonitorLabel.textColor = .secondaryLabelColor
        resmonitorLabel.isHidden = true

        let textStack = NSStackView(views: [
            nameLabel,
            userNameLabel,
            memberStatusLabel,
            memberDetailLabel,
            featureBannerLabel,
            resmonitorLabel
        ])
        textStack.orientation = .vertical
        textStack.alignment = .leading
        textStack.spacing = 1
        textStack.translatesAutoresizingMaskIntoConstraints = false
        memberStatusLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        memberDetailLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        featureBannerLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true
        resmonitorLabel.widthAnchor.constraint(equalTo: textStack.widthAnchor).isActive = true

        statusCard.addSubview(avatarImageView)
        statusCard.addSubview(textStack)

        NSLayoutConstraint.activate([
            avatarImageView.leadingAnchor.constraint(equalTo: statusCard.leadingAnchor, constant: 16),
            avatarImageView.centerYAnchor.constraint(equalTo: statusCard.centerYAnchor),
            avatarImageView.widthAnchor.constraint(equalToConstant: 64),
            avatarImageView.heightAnchor.constraint(equalToConstant: 64),

            textStack.leadingAnchor.constraint(equalTo: avatarImageView.trailingAnchor, constant: 14),
            textStack.trailingAnchor.constraint(equalTo: statusCard.trailingAnchor, constant: -16),
            textStack.centerYAnchor.constraint(equalTo: statusCard.centerYAnchor)
        ])
    }

    private func buildSegmentedControl() {
        segmentedControl.translatesAutoresizingMaskIntoConstraints = false
        segmentedControl.selectedSegment = 0
        segmentedControl.segmentStyle = .rounded
        segmentedControl.setAccessibilityIdentifier(AccessibilityID.Membership.sectionControl)
        segmentedControl.target = self
        segmentedControl.action = #selector(sectionChanged(_:))
    }

    private func buildPayView() {
        payView.translatesAutoresizingMaskIntoConstraints = false

        let providerLabel = makeFieldLabel(NSLocalizedString("支付渠道", comment: ""))
        let itemLabel = makeFieldLabel(NSLocalizedString("会员时长", comment: ""))

        providerPopup.translatesAutoresizingMaskIntoConstraints = false
        providerPopup.setAccessibilityIdentifier(AccessibilityID.Membership.providerPopup)
        providerPopup.target = self
        providerPopup.action = #selector(providerChanged(_:))

        itemPopup.translatesAutoresizingMaskIntoConstraints = false
        itemPopup.setAccessibilityIdentifier(AccessibilityID.Membership.itemPopup)
        itemPopup.target = self
        itemPopup.action = #selector(itemChanged(_:))

        priceLabel.translatesAutoresizingMaskIntoConstraints = false
        priceLabel.font = NSFont.systemFont(ofSize: 16, weight: .semibold)
        priceLabel.alignment = .right
        priceLabel.setAccessibilityIdentifier(AccessibilityID.Membership.priceLabel)

        payButton.translatesAutoresizingMaskIntoConstraints = false
        payButton.bezelStyle = .rounded
        payButton.controlSize = .large
        payButton.keyEquivalent = "\r"
        payButton.setAccessibilityIdentifier(AccessibilityID.Membership.payButton)

        let spacer = NSView()
        spacer.translatesAutoresizingMaskIntoConstraints = false
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)

        let controls = NSStackView(views: [
            providerLabel,
            providerPopup,
            itemLabel,
            itemPopup,
            spacer,
            priceLabel,
            payButton
        ])
        controls.translatesAutoresizingMaskIntoConstraints = false
        controls.orientation = .horizontal
        controls.alignment = .centerY
        controls.spacing = 8

        paymentPanel.translatesAutoresizingMaskIntoConstraints = false
        paymentPanel.wantsLayer = true
        paymentPanel.layer?.cornerRadius = 8
        paymentPanel.layer?.borderWidth = 1
        paymentPanel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentPanel)

        qrContainer.translatesAutoresizingMaskIntoConstraints = false
        qrContainer.wantsLayer = true
        qrContainer.layer?.cornerRadius = 6
        qrContainer.layer?.borderWidth = 1

        qrImageView.translatesAutoresizingMaskIntoConstraints = false
        qrImageView.imageScaling = .scaleProportionallyUpOrDown
        qrImageView.setAccessibilityIdentifier(AccessibilityID.Membership.qrCodeImage)
        qrImageView.setAccessibilityLabel(NSLocalizedString("支付二维码", comment: ""))

        qrPlaceholderLabel.translatesAutoresizingMaskIntoConstraints = false
        qrPlaceholderLabel.font = NSFont.systemFont(ofSize: 12)
        qrPlaceholderLabel.textColor = .tertiaryLabelColor
        qrPlaceholderLabel.alignment = .center

        paymentProviderLabel.font = NSFont.systemFont(ofSize: 13, weight: .medium)
        paymentProviderLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentProviderLabel)
        paymentTitleLabel.font = NSFont.systemFont(ofSize: 12)
        paymentTitleLabel.textColor = .secondaryLabelColor
        paymentTitleLabel.lineBreakMode = .byTruncatingTail
        paymentTitleLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentTitleLabel)
        paymentAmountLabel.font = NSFont.systemFont(ofSize: 24, weight: .bold)
        paymentAmountLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentAmountLabel)
        paymentStatusLabel.font = NSFont.systemFont(ofSize: 12)
        paymentStatusLabel.maximumNumberOfLines = 4
        paymentStatusLabel.lineBreakMode = .byWordWrapping
        paymentStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentStatusLabel)
        countdownLabel.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        countdownLabel.textColor = .secondaryLabelColor
        countdownLabel.setAccessibilityIdentifier(AccessibilityID.Membership.countdownLabel)
        paymentNoteLabel.font = NSFont.systemFont(ofSize: 11)
        paymentNoteLabel.textColor = .tertiaryLabelColor
        paymentNoteLabel.maximumNumberOfLines = 2
        paymentNoteLabel.lineBreakMode = .byWordWrapping
        paymentNoteLabel.setAccessibilityIdentifier(AccessibilityID.Membership.paymentNoteLabel)

        for button in [openWebButton, cancelPaymentButton] {
            button.translatesAutoresizingMaskIntoConstraints = false
            button.bezelStyle = .rounded
            button.controlSize = .regular
        }
        openWebButton.setAccessibilityIdentifier(AccessibilityID.Membership.openWebButton)
        cancelPaymentButton.setAccessibilityIdentifier(AccessibilityID.Membership.cancelPaymentButton)
        openWebButton.isHidden = true

        let buttonRow = NSStackView(views: [openWebButton, cancelPaymentButton])
        buttonRow.translatesAutoresizingMaskIntoConstraints = false
        buttonRow.orientation = .horizontal
        buttonRow.spacing = 8

        let infoStack = NSStackView(views: [
            paymentProviderLabel,
            paymentTitleLabel,
            paymentAmountLabel,
            paymentStatusLabel,
            countdownLabel,
            paymentNoteLabel,
            buttonRow
        ])
        infoStack.translatesAutoresizingMaskIntoConstraints = false
        infoStack.orientation = .vertical
        infoStack.alignment = .leading
        infoStack.spacing = 6

        // 长文案需要跟随右侧信息区宽度换行，避免撑破面板。
        paymentTitleLabel.widthAnchor.constraint(equalTo: infoStack.widthAnchor).isActive = true
        paymentStatusLabel.widthAnchor.constraint(equalTo: infoStack.widthAnchor).isActive = true
        paymentNoteLabel.widthAnchor.constraint(equalTo: infoStack.widthAnchor).isActive = true

        paymentPanel.addSubview(qrContainer)
        qrContainer.addSubview(qrImageView)
        qrContainer.addSubview(qrPlaceholderLabel)
        paymentPanel.addSubview(infoStack)

        payView.addSubview(controls)
        payView.addSubview(paymentPanel)

        NSLayoutConstraint.activate([
            controls.topAnchor.constraint(equalTo: payView.topAnchor),
            controls.leadingAnchor.constraint(equalTo: payView.leadingAnchor),
            controls.trailingAnchor.constraint(equalTo: payView.trailingAnchor),
            controls.heightAnchor.constraint(equalToConstant: 30),

            providerPopup.widthAnchor.constraint(equalToConstant: 118),
            itemPopup.widthAnchor.constraint(equalToConstant: 160),
            priceLabel.widthAnchor.constraint(equalToConstant: 92),
            payButton.widthAnchor.constraint(equalToConstant: 100),

            paymentPanel.topAnchor.constraint(equalTo: controls.bottomAnchor, constant: 12),
            paymentPanel.leadingAnchor.constraint(equalTo: payView.leadingAnchor),
            paymentPanel.trailingAnchor.constraint(equalTo: payView.trailingAnchor),
            paymentPanel.bottomAnchor.constraint(equalTo: payView.bottomAnchor),

            qrContainer.topAnchor.constraint(equalTo: paymentPanel.topAnchor, constant: 18),
            qrContainer.leadingAnchor.constraint(equalTo: paymentPanel.leadingAnchor, constant: 20),
            qrContainer.widthAnchor.constraint(equalToConstant: 160),
            qrContainer.heightAnchor.constraint(equalToConstant: 160),

            qrImageView.topAnchor.constraint(equalTo: qrContainer.topAnchor, constant: 6),
            qrImageView.leadingAnchor.constraint(equalTo: qrContainer.leadingAnchor, constant: 6),
            qrImageView.trailingAnchor.constraint(equalTo: qrContainer.trailingAnchor, constant: -6),
            qrImageView.bottomAnchor.constraint(equalTo: qrContainer.bottomAnchor, constant: -6),

            qrPlaceholderLabel.centerXAnchor.constraint(equalTo: qrContainer.centerXAnchor),
            qrPlaceholderLabel.centerYAnchor.constraint(equalTo: qrContainer.centerYAnchor),

            infoStack.topAnchor.constraint(equalTo: paymentPanel.topAnchor, constant: 18),
            infoStack.leadingAnchor.constraint(equalTo: qrContainer.trailingAnchor, constant: 20),
            infoStack.trailingAnchor.constraint(equalTo: paymentPanel.trailingAnchor, constant: -20),
            infoStack.bottomAnchor.constraint(lessThanOrEqualTo: paymentPanel.bottomAnchor, constant: -18)
        ])
    }

    private func buildRedeemView() {
        redeemView.translatesAutoresizingMaskIntoConstraints = false

        let instruction = makeFieldLabel(NSLocalizedString("输入礼品码兑换会员时长。兑换成功后权益立即生效，无需重启。", comment: ""))
        instruction.maximumNumberOfLines = 2

        redeemField.translatesAutoresizingMaskIntoConstraints = false
        redeemField.placeholderString = NSLocalizedString("礼品码（最多 20 个字符）", comment: "")
        redeemField.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .regular)
        redeemField.setAccessibilityIdentifier(AccessibilityID.Membership.redeemField)
        redeemField.target = self
        redeemField.action = #selector(redeemTapped(_:))

        pasteButton.translatesAutoresizingMaskIntoConstraints = false
        pasteButton.setAccessibilityIdentifier(AccessibilityID.Membership.pasteButton)

        redeemButton.translatesAutoresizingMaskIntoConstraints = false
        redeemButton.bezelStyle = .rounded
        redeemButton.keyEquivalent = "\r"
        redeemButton.setAccessibilityIdentifier(AccessibilityID.Membership.redeemButton)

        redeemStatusLabel.font = NSFont.systemFont(ofSize: 12)
        redeemStatusLabel.maximumNumberOfLines = 3
        redeemStatusLabel.lineBreakMode = .byWordWrapping
        redeemStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.redeemStatusLabel)

        let separator = NSBox()
        separator.translatesAutoresizingMaskIntoConstraints = false
        separator.boxType = .separator

        let historyTitle = NSTextField(labelWithString: NSLocalizedString("兑换记录", comment: ""))
        historyTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        historyTitle.translatesAutoresizingMaskIntoConstraints = false

        let redeemTableScroll = makeTable(
            redeemHistoryTable,
            tag: .redeems,
            columns: [
                (NSLocalizedString("时间", comment: ""), 130),
                (NSLocalizedString("礼品码", comment: ""), 150),
                (NSLocalizedString("天数", comment: ""), 55),
                (NSLocalizedString("会员有效期至", comment: ""), 140),
                (NSLocalizedString("备注", comment: ""), 180)
            ]
        )
        redeemTableScroll.setAccessibilityIdentifier(AccessibilityID.Membership.redeemHistoryList)

        redeemView.addSubview(instruction)
        redeemView.addSubview(redeemField)
        redeemView.addSubview(pasteButton)
        redeemView.addSubview(redeemButton)
        redeemView.addSubview(redeemStatusLabel)
        redeemView.addSubview(separator)
        redeemView.addSubview(historyTitle)
        redeemView.addSubview(redeemTableScroll)

        NSLayoutConstraint.activate([
            instruction.topAnchor.constraint(equalTo: redeemView.topAnchor),
            instruction.leadingAnchor.constraint(equalTo: redeemView.leadingAnchor),
            instruction.trailingAnchor.constraint(equalTo: redeemView.trailingAnchor),

            redeemField.topAnchor.constraint(equalTo: instruction.bottomAnchor, constant: 12),
            redeemField.leadingAnchor.constraint(equalTo: redeemView.leadingAnchor),
            redeemField.heightAnchor.constraint(equalToConstant: 28),

            pasteButton.leadingAnchor.constraint(equalTo: redeemField.trailingAnchor, constant: 8),
            pasteButton.centerYAnchor.constraint(equalTo: redeemField.centerYAnchor),
            pasteButton.widthAnchor.constraint(equalToConstant: 64),

            redeemButton.leadingAnchor.constraint(equalTo: pasteButton.trailingAnchor, constant: 8),
            redeemButton.centerYAnchor.constraint(equalTo: redeemField.centerYAnchor),
            redeemButton.widthAnchor.constraint(equalToConstant: 80),
            redeemButton.trailingAnchor.constraint(lessThanOrEqualTo: redeemView.trailingAnchor),

            redeemStatusLabel.topAnchor.constraint(equalTo: redeemField.bottomAnchor, constant: 8),
            redeemStatusLabel.leadingAnchor.constraint(equalTo: redeemView.leadingAnchor),
            redeemStatusLabel.trailingAnchor.constraint(equalTo: redeemView.trailingAnchor),

            separator.topAnchor.constraint(equalTo: redeemStatusLabel.bottomAnchor, constant: 10),
            separator.leadingAnchor.constraint(equalTo: redeemView.leadingAnchor),
            separator.trailingAnchor.constraint(equalTo: redeemView.trailingAnchor),

            historyTitle.topAnchor.constraint(equalTo: separator.bottomAnchor, constant: 10),
            historyTitle.leadingAnchor.constraint(equalTo: redeemView.leadingAnchor),

            redeemTableScroll.topAnchor.constraint(equalTo: historyTitle.bottomAnchor, constant: 6),
            redeemTableScroll.leadingAnchor.constraint(equalTo: redeemView.leadingAnchor),
            redeemTableScroll.trailingAnchor.constraint(equalTo: redeemView.trailingAnchor),
            redeemTableScroll.bottomAnchor.constraint(equalTo: redeemView.bottomAnchor)
        ])
    }

    private func buildHistoryView() {
        historyView.translatesAutoresizingMaskIntoConstraints = false

        let orderTitle = NSTextField(labelWithString: NSLocalizedString("购买记录", comment: ""))
        orderTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        orderTitle.translatesAutoresizingMaskIntoConstraints = false

        historyReloadButton.translatesAutoresizingMaskIntoConstraints = false
        historyReloadButton.bezelStyle = .rounded
        historyReloadButton.setAccessibilityIdentifier(AccessibilityID.Membership.historyReloadButton)

        let orderTableScroll = makeTable(
            orderTable,
            tag: .orders,
            columns: [
                (NSLocalizedString("时间", comment: ""), 130),
                (NSLocalizedString("订单号", comment: ""), 130),
                (NSLocalizedString("商品", comment: ""), 130),
                (NSLocalizedString("金额", comment: ""), 80),
                (NSLocalizedString("会员有效期至", comment: ""), 140)
            ]
        )
        orderTableScroll.translatesAutoresizingMaskIntoConstraints = false
        orderTableScroll.setAccessibilityIdentifier(AccessibilityID.Membership.orderList)

        let redeemTitle = NSTextField(labelWithString: NSLocalizedString("兑换记录", comment: ""))
        redeemTitle.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        redeemTitle.translatesAutoresizingMaskIntoConstraints = false

        let redeemTableScroll = makeTable(
            historyRedeemTable,
            tag: .redeems,
            columns: [
                (NSLocalizedString("时间", comment: ""), 130),
                (NSLocalizedString("礼品码", comment: ""), 150),
                (NSLocalizedString("天数", comment: ""), 55),
                (NSLocalizedString("会员有效期至", comment: ""), 140),
                (NSLocalizedString("备注", comment: ""), 180)
            ]
        )
        redeemTableScroll.setAccessibilityIdentifier(AccessibilityID.Membership.historyRedeemList)

        historyStatusLabel.font = NSFont.systemFont(ofSize: 11)
        historyStatusLabel.textColor = .secondaryLabelColor
        historyStatusLabel.maximumNumberOfLines = 2
        historyStatusLabel.lineBreakMode = .byWordWrapping
        historyStatusLabel.setAccessibilityIdentifier(AccessibilityID.Membership.historyStatusLabel)
        historyStatusLabel.translatesAutoresizingMaskIntoConstraints = false

        historyView.addSubview(orderTitle)
        historyView.addSubview(historyReloadButton)
        historyView.addSubview(orderTableScroll)
        historyView.addSubview(redeemTitle)
        historyView.addSubview(redeemTableScroll)
        historyView.addSubview(historyStatusLabel)

        NSLayoutConstraint.activate([
            orderTitle.topAnchor.constraint(equalTo: historyView.topAnchor),
            orderTitle.leadingAnchor.constraint(equalTo: historyView.leadingAnchor),

            historyReloadButton.centerYAnchor.constraint(equalTo: orderTitle.centerYAnchor),
            historyReloadButton.trailingAnchor.constraint(equalTo: historyView.trailingAnchor),
            historyReloadButton.widthAnchor.constraint(equalToConstant: 70),

            orderTableScroll.topAnchor.constraint(equalTo: orderTitle.bottomAnchor, constant: 6),
            orderTableScroll.leadingAnchor.constraint(equalTo: historyView.leadingAnchor),
            orderTableScroll.trailingAnchor.constraint(equalTo: historyView.trailingAnchor),
            orderTableScroll.heightAnchor.constraint(equalToConstant: 110),

            redeemTitle.topAnchor.constraint(equalTo: orderTableScroll.bottomAnchor, constant: 8),
            redeemTitle.leadingAnchor.constraint(equalTo: historyView.leadingAnchor),

            redeemTableScroll.topAnchor.constraint(equalTo: redeemTitle.bottomAnchor, constant: 6),
            redeemTableScroll.leadingAnchor.constraint(equalTo: historyView.leadingAnchor),
            redeemTableScroll.trailingAnchor.constraint(equalTo: historyView.trailingAnchor),
            redeemTableScroll.bottomAnchor.constraint(equalTo: historyStatusLabel.topAnchor, constant: -6),

            historyStatusLabel.leadingAnchor.constraint(equalTo: historyView.leadingAnchor),
            historyStatusLabel.trailingAnchor.constraint(equalTo: historyView.trailingAnchor),
            historyStatusLabel.bottomAnchor.constraint(equalTo: historyView.bottomAnchor)
        ])
    }

    private func buildIntro() {
        introTitleLabel.font = NSFont.systemFont(ofSize: 13, weight: .semibold)
        introTitleLabel.translatesAutoresizingMaskIntoConstraints = false

        introTextView.isEditable = false
        introTextView.isSelectable = true
        introTextView.drawsBackground = false
        introTextView.textContainerInset = NSSize(width: 4, height: 4)
        introTextView.setAccessibilityIdentifier(AccessibilityID.Membership.introTextView)
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

        introScrollView.translatesAutoresizingMaskIntoConstraints = false
        introScrollView.hasVerticalScroller = true
        introScrollView.borderType = .bezelBorder
        introScrollView.documentView = introTextView
    }

    private func installLayout() {
        let root = view
        root.addSubview(statusCard)
        root.addSubview(segmentedControl)
        root.addSubview(contentContainer)
        root.addSubview(introTitleLabel)
        root.addSubview(introScrollView)

        contentContainer.translatesAutoresizingMaskIntoConstraints = false
        contentContainer.addSubview(payView)
        contentContainer.addSubview(redeemView)
        contentContainer.addSubview(historyView)

        for section in [payView, redeemView, historyView] {
            NSLayoutConstraint.activate([
                section.topAnchor.constraint(equalTo: contentContainer.topAnchor),
                section.leadingAnchor.constraint(equalTo: contentContainer.leadingAnchor),
                section.trailingAnchor.constraint(equalTo: contentContainer.trailingAnchor),
                section.bottomAnchor.constraint(equalTo: contentContainer.bottomAnchor)
            ])
        }

        NSLayoutConstraint.activate([
            statusCard.topAnchor.constraint(equalTo: root.topAnchor, constant: 20),
            statusCard.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            statusCard.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            statusCard.heightAnchor.constraint(equalToConstant: 108),

            segmentedControl.topAnchor.constraint(equalTo: statusCard.bottomAnchor, constant: 14),
            segmentedControl.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            segmentedControl.widthAnchor.constraint(equalToConstant: 300),
            segmentedControl.heightAnchor.constraint(equalToConstant: 28),

            contentContainer.topAnchor.constraint(equalTo: segmentedControl.bottomAnchor, constant: 12),
            contentContainer.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            contentContainer.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            contentContainer.heightAnchor.constraint(greaterThanOrEqualToConstant: 300),

            introTitleLabel.topAnchor.constraint(equalTo: contentContainer.bottomAnchor, constant: 14),
            introTitleLabel.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),

            introScrollView.topAnchor.constraint(equalTo: introTitleLabel.bottomAnchor, constant: 6),
            introScrollView.leadingAnchor.constraint(equalTo: root.leadingAnchor, constant: 20),
            introScrollView.trailingAnchor.constraint(equalTo: root.trailingAnchor, constant: -20),
            introScrollView.bottomAnchor.constraint(equalTo: root.bottomAnchor, constant: -20),
            introScrollView.heightAnchor.constraint(equalToConstant: 84)
        ])

        applyDynamicColors()
    }

    private func installActions() {
        payButton.target = self
        payButton.action = #selector(payTapped(_:))
        openWebButton.target = self
        openWebButton.action = #selector(openWebTapped(_:))
        cancelPaymentButton.target = self
        cancelPaymentButton.action = #selector(cancelPaymentTapped(_:))
        pasteButton.target = self
        pasteButton.action = #selector(pasteTapped(_:))
        redeemButton.target = self
        redeemButton.action = #selector(redeemTapped(_:))
        historyReloadButton.target = self
        historyReloadButton.action = #selector(reloadHistoryTapped(_:))
    }

    private func applyDynamicColors() {
        statusCard.layer?.backgroundColor = NSColor.controlBackgroundColor.cgColor
        statusCard.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.5).cgColor
        paymentPanel.layer?.backgroundColor = NSColor.controlBackgroundColor.withAlphaComponent(0.45).cgColor
        paymentPanel.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
        qrContainer.layer?.backgroundColor = NSColor.textBackgroundColor.cgColor
        qrContainer.layer?.borderColor = NSColor.separatorColor.withAlphaComponent(0.6).cgColor
    }

    private func makeFieldLabel(_ text: String) -> NSTextField {
        let label = NSTextField(labelWithString: text)
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = NSFont.systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        return label
    }

    private func makeTable(
        _ tableView: NSTableView,
        tag: TableTag,
        columns: [(String, CGFloat)]
    ) -> NSScrollView {
        tableView.tag = tag.rawValue
        tableView.delegate = self
        tableView.dataSource = self
        tableView.usesAlternatingRowBackgroundColors = true
        tableView.rowHeight = 24
        tableView.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        tableView.allowsMultipleSelection = false

        for (title, width) in columns {
            let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(title))
            column.title = title
            column.width = width
            column.minWidth = 40
            tableView.addTableColumn(column)
        }

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = true
        scrollView.borderType = .bezelBorder
        scrollView.documentView = tableView
        return scrollView
    }

    // MARK: - Render

    private func render() {
        nameLabel.stringValue = viewModel.displayName
        userNameLabel.stringValue = viewModel.userNameText
        userNameLabel.isHidden = viewModel.userNameText.isEmpty
        memberStatusLabel.stringValue = viewModel.memberStatusText
        memberDetailLabel.stringValue = viewModel.memberDetailText

        if let banner = viewModel.featureBannerText {
            featureBannerLabel.stringValue = banner
            featureBannerLabel.isHidden = false
        } else {
            featureBannerLabel.isHidden = true
        }

        if let resmonitor = viewModel.resmonitorText {
            resmonitorLabel.stringValue = resmonitor
            resmonitorLabel.isHidden = false
        } else {
            resmonitorLabel.isHidden = true
        }

        if viewModel.isExpiringSoon {
            memberStatusLabel.textColor = .systemOrange
        } else if viewModel.hasActiveMembership {
            memberStatusLabel.textColor = .systemGreen
        } else {
            memberStatusLabel.textColor = .secondaryLabelColor
        }

        loadAvatar(viewModel.avatarURLString)
        renderPayControls()
        renderPaymentPanel()
        renderRedeem()
        renderHistory()
        renderIntro()
    }

    private func renderPayControls() {
        let providerIds = viewModel.payConfigs.map { $0.providerId }
        if providerIds != renderedProviderIds {
            renderedProviderIds = providerIds
            providerPopup.removeAllItems()
            for provider in viewModel.payConfigs {
                providerPopup.addItem(withTitle: provider.providerName.isEmpty ? provider.providerId : provider.providerName)
                providerPopup.lastItem?.representedObject = provider.providerId
            }
        }
        selectPopup(providerPopup, representedObject: viewModel.selectedProviderId)

        let itemIds = viewModel.currentItems.map { $0.id }
        if itemIds != renderedItemIds {
            renderedItemIds = itemIds
            itemPopup.removeAllItems()
            for item in viewModel.currentItems {
                itemPopup.addItem(withTitle: item.name.isEmpty ? item.id : item.name)
                itemPopup.lastItem?.representedObject = item.id
            }
        }
        selectPopup(itemPopup, representedObject: viewModel.selectedItem?.id)

        priceLabel.stringValue = viewModel.selectedPriceText
        payButton.title = viewModel.payButtonTitle
        payButton.isEnabled = viewModel.canStartPayment
        providerPopup.isEnabled = !viewModel.isPaymentInProgress
        itemPopup.isEnabled = !viewModel.isPaymentInProgress
    }

    private func selectPopup(_ popup: NSPopUpButton, representedObject: String?) {
        guard let representedObject = representedObject else { return }
        for item in popup.itemArray where (item.representedObject as? String) == representedObject {
            popup.select(item)
            return
        }
    }

    private func renderPaymentPanel() {
        let state = viewModel.paymentState
        qrImageView.image = nil
        qrPlaceholderLabel.isHidden = false
        openWebButton.isHidden = true
        cancelPaymentButton.isHidden = true
        paymentStatusLabel.textColor = .secondaryLabelColor
        countdownLabel.stringValue = ""
        paymentNoteLabel.stringValue = ""

        qrPlaceholderLabel.stringValue = NSLocalizedString("二维码", comment: "")

        switch state {
        case .idle:
            qrPlaceholderLabel.stringValue = NSLocalizedString("选择时长后支付", comment: "")
            paymentProviderLabel.stringValue = NSLocalizedString("在线支付", comment: "")
            paymentTitleLabel.stringValue = NSLocalizedString("选择会员时长后点击「去支付」", comment: "")
            paymentAmountLabel.stringValue = viewModel.selectedPriceText
            paymentStatusLabel.stringValue = viewModel.statusMessage
                ?? NSLocalizedString("支持微信扫码与支付宝网页支付", comment: "")
            paymentNoteLabel.stringValue = NSLocalizedString("价格由服务端下发；支付成功后会员有效期立即更新。", comment: "")

        case .creating:
            qrPlaceholderLabel.stringValue = NSLocalizedString("正在创建订单…", comment: "")
            paymentProviderLabel.stringValue = NSLocalizedString("正在创建订单", comment: "")
            paymentTitleLabel.stringValue = viewModel.selectedItem?.name ?? ""
            paymentAmountLabel.stringValue = viewModel.selectedPriceText
            paymentStatusLabel.stringValue = NSLocalizedString("正在创建支付订单…", comment: "")
            cancelPaymentButton.isHidden = false
            cancelPaymentButton.title = NSLocalizedString("取消", comment: "")

        case .waiting(let presentation, let confirming):
            paymentProviderLabel.stringValue = presentation.providerText
            paymentTitleLabel.stringValue = presentation.title
            paymentAmountLabel.stringValue = presentation.amountText
            if let data = presentation.qrImageData, let image = NSImage(data: data) {
                qrImageView.image = image
                qrPlaceholderLabel.isHidden = true
            } else {
                qrPlaceholderLabel.stringValue = NSLocalizedString("请在网页中完成支付", comment: "")
            }
            if confirming {
                paymentStatusLabel.stringValue = NSLocalizedString("支付结果确认中，请勿重复付款", comment: "")
                paymentStatusLabel.textColor = .systemOrange
            } else {
                paymentStatusLabel.stringValue = presentation.statusNote
                    ?? NSLocalizedString("等待支付结果…", comment: "")
            }
            if presentation.webURL != nil {
                openWebButton.isHidden = false
            }
            cancelPaymentButton.isHidden = false
            cancelPaymentButton.title = NSLocalizedString("取消支付", comment: "")
            updateCountdownLabel()
            paymentNoteLabel.stringValue = NSLocalizedString("请勿关闭窗口；支付成功后会自动刷新会员有效期。", comment: "")

        case .success(let orderId, let amountText, let memberExpireAt, let message):
            paymentProviderLabel.stringValue = NSLocalizedString("支付成功", comment: "")
            paymentProviderLabel.textColor = .systemGreen
            paymentTitleLabel.stringValue = message
            paymentAmountLabel.stringValue = amountText
            paymentStatusLabel.stringValue = String(
                format: NSLocalizedString("订单号：%@", comment: ""),
                orderId
            )
            if let memberExpireAt = memberExpireAt {
                paymentNoteLabel.stringValue = String(
                    format: NSLocalizedString("会员有效期至 %@（以服务端为准）", comment: ""),
                    MembershipDateFormatting.localDateTime(memberExpireAt)
                )
            }
            cancelPaymentButton.isHidden = false
            cancelPaymentButton.title = NSLocalizedString("完成", comment: "")
            qrPlaceholderLabel.stringValue = NSLocalizedString("已支付", comment: "")

        case .expired(_, let message):
            paymentProviderLabel.stringValue = NSLocalizedString("订单已过期", comment: "")
            paymentProviderLabel.textColor = .systemOrange
            paymentTitleLabel.stringValue = NSLocalizedString("如已付款请勿重复支付", comment: "")
            paymentAmountLabel.stringValue = viewModel.selectedPriceText
            paymentStatusLabel.stringValue = message
            paymentStatusLabel.textColor = .systemOrange
            qrPlaceholderLabel.stringValue = NSLocalizedString("二维码已过期", comment: "")
            cancelPaymentButton.isHidden = false
            cancelPaymentButton.title = NSLocalizedString("关闭", comment: "")

        case .failed(_, let message):
            paymentProviderLabel.stringValue = NSLocalizedString("支付失败", comment: "")
            paymentProviderLabel.textColor = .systemRed
            paymentTitleLabel.stringValue = NSLocalizedString("请稍后重试，或查看购买记录确认", comment: "")
            paymentAmountLabel.stringValue = viewModel.selectedPriceText
            paymentStatusLabel.stringValue = message
            paymentStatusLabel.textColor = .systemRed
            qrPlaceholderLabel.stringValue = NSLocalizedString("支付未完成", comment: "")
            cancelPaymentButton.isHidden = false
            cancelPaymentButton.title = NSLocalizedString("关闭", comment: "")

        case .cancelled:
            paymentProviderLabel.stringValue = NSLocalizedString("已取消支付", comment: "")
            paymentTitleLabel.stringValue = NSLocalizedString("订单仍可能在有效期内继续支付", comment: "")
            paymentAmountLabel.stringValue = viewModel.selectedPriceText
            paymentStatusLabel.stringValue = NSLocalizedString("已停止查询支付结果。如需继续支付，请重新点击「去支付」。", comment: "")
            qrPlaceholderLabel.stringValue = NSLocalizedString("等待支付", comment: "")
        }

        if case .success = state {
            paymentProviderLabel.textColor = .systemGreen
        } else if case .failed = state {
            paymentProviderLabel.textColor = .systemRed
        } else if case .expired = state {
            paymentProviderLabel.textColor = .systemOrange
        } else {
            paymentProviderLabel.textColor = .labelColor
        }
    }

    private func renderRedeem() {
        redeemButton.isEnabled = !viewModel.isRedeeming
        redeemField.isEnabled = !viewModel.isRedeeming
        pasteButton.isEnabled = !viewModel.isRedeeming

        if let message = viewModel.redeemStatusMessage {
            redeemStatusLabel.stringValue = message
            redeemStatusLabel.textColor = viewModel.redeemSucceeded ? .systemGreen : .systemRed
        } else {
            redeemStatusLabel.stringValue = ""
        }
        redeemHistoryTable.reloadData()
    }

    private func renderHistory() {
        orderTable.reloadData()
        historyRedeemTable.reloadData()
        historyStatusLabel.stringValue = viewModel.historyStatusMessage ?? ""
        historyStatusLabel.textColor = viewModel.historyStatusMessage == nil ? .secondaryLabelColor : .systemOrange
        historyReloadButton.isEnabled = !viewModel.isLoadingHistory
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

        guard let urlString = urlString, let url = URL(string: urlString) else {
            avatarImageView.image = NSImage(
                systemSymbolName: "person.crop.circle",
                accessibilityDescription: NSLocalizedString("用户头像", comment: "")
            )
            return
        }

        avatarImageView.image = NSImage(
            systemSymbolName: "person.crop.circle",
            accessibilityDescription: NSLocalizedString("用户头像", comment: "")
        )
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
        let index = segmentedControl.selectedSegment
        payView.isHidden = index != 0
        redeemView.isHidden = index != 1
        historyView.isHidden = index != 2

        if index == 2 && viewModel.orderHistory.isEmpty && viewModel.redeemHistory.isEmpty && !viewModel.isLoadingHistory {
            Task { @MainActor [weak self] in
                await self?.viewModel.loadHistory()
            }
        }
    }

    @objc private func sectionChanged(_ sender: Any?) {
        updateSectionVisibility()
    }

    // MARK: - Actions

    @objc private func providerChanged(_ sender: Any?) {
        guard let providerId = providerPopup.selectedItem?.representedObject as? String else { return }
        viewModel.selectProvider(id: providerId)
    }

    @objc private func itemChanged(_ sender: Any?) {
        guard let itemId = itemPopup.selectedItem?.representedObject as? String else { return }
        viewModel.selectItem(id: itemId)
    }

    @objc private func payTapped(_ sender: Any?) {
        switch viewModel.paymentState {
        case .expired, .failed, .cancelled:
            viewModel.resetPayment()
        default:
            break
        }
        viewModel.startPayment()
    }

    @objc private func openWebTapped(_ sender: Any?) {
        viewModel.openWebPayment()
    }

    @objc private func cancelPaymentTapped(_ sender: Any?) {
        switch viewModel.paymentState {
        case .success, .expired, .failed:
            view.window?.performClose(nil)
        default:
            viewModel.cancelPayment()
        }
    }

    @objc private func pasteTapped(_ sender: Any?) {
        if let text = NSPasteboard.general.string(forType: .string) {
            redeemField.stringValue = text
        }
    }

    @objc private func redeemTapped(_ sender: Any?) {
        let code = redeemField.stringValue
        let sanitized = MembershipViewModel.sanitizedPromoCode(code)
        redeemField.stringValue = sanitized
        Task { @MainActor [weak self] in
            await self?.viewModel.redeem(code: sanitized)
            if self?.viewModel.redeemSucceeded == true {
                self?.redeemField.stringValue = ""
            }
        }
    }

    @objc private func reloadHistoryTapped(_ sender: Any?) {
        Task { @MainActor [weak self] in
            await self?.viewModel.loadHistory()
        }
    }

    // MARK: - Markdown（轻量渲染，失败也不阻塞会员中心）

    private static func markdownText(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let bodyFont = NSFont.systemFont(ofSize: 12)
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineSpacing = 2
        paragraph.paragraphSpacing = 2

        for rawLine in markdown.components(separatedBy: .newlines) {
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
                result.append(NSAttributedString(string: "\n", attributes: [.font: bodyFont, .paragraphStyle: paragraph]))
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
        guard let tag = TableTag(rawValue: tableView.tag) else { return 0 }
        switch tag {
        case .orders:
            return viewModel.orderHistory.count
        case .redeems:
            return viewModel.redeemHistory.count
        }
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard let tableColumn = tableColumn else { return nil }
        let identifier = NSUserInterfaceItemIdentifier("cell-\(tableView.tag)-\(tableColumn.identifier.rawValue)")
        let cell: NSTableCellView
        if let reused = tableView.makeView(withIdentifier: identifier, owner: nil) as? NSTableCellView {
            cell = reused
        } else {
            cell = makeCell(identifier: identifier)
        }

        cell.textField?.stringValue = text(for: tableView, column: tableColumn, row: row)
        cell.textField?.font = NSFont.systemFont(ofSize: 11)
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
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
            textField.trailingAnchor.constraint(equalTo: cell.trailingAnchor, constant: -4),
            textField.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
        ])
        return cell
    }

    private func text(for tableView: NSTableView, column: NSTableColumn, row: Int) -> String {
        guard let tag = TableTag(rawValue: tableView.tag) else { return "" }
        switch tag {
        case .orders:
            guard row < viewModel.orderHistory.count else { return "" }
            let item = viewModel.orderHistory[row]
            switch column.identifier.rawValue {
            case NSLocalizedString("时间", comment: ""):
                return MembershipDateFormatting.localDateTime(item.orderTime)
            case NSLocalizedString("订单号", comment: ""):
                return item.orderId
            case NSLocalizedString("商品", comment: ""):
                return item.title
            case NSLocalizedString("金额", comment: ""):
                return item.displayAmount
            case NSLocalizedString("会员有效期至", comment: ""):
                return MembershipDateFormatting.localDateTime(item.toTime)
            default:
                return item.description
            }
        case .redeems:
            guard row < viewModel.redeemHistory.count else { return "" }
            let item = viewModel.redeemHistory[row]
            switch column.identifier.rawValue {
            case NSLocalizedString("时间", comment: ""):
                return MembershipDateFormatting.localDateTime(item.redeemTime)
            case NSLocalizedString("礼品码", comment: ""):
                return item.promoCode
            case NSLocalizedString("天数", comment: ""):
                return String(format: NSLocalizedString("%d 天", comment: ""), item.addDays)
            case NSLocalizedString("会员有效期至", comment: ""):
                return MembershipDateFormatting.localDateTime(item.toTime)
            default:
                return item.description
            }
        }
    }
}
