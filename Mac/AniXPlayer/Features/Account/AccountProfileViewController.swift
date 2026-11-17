//
//  AccountProfileViewController.swift
//  AniXPlayer
//
//  macOS only：账号资料窗口（账号信息、资料修改、bangumi.tv 关联与退出登录）。
//

import Cocoa
import SnapKit

@MainActor
final class AccountProfileViewController: WelcomeShellScrollPageViewController {

    var onLoggedOut: (() -> Void)?

    private let viewModel = AccountProfileViewModel()

    private let header = AccountProfileHeaderView()
    private let statusLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11.5),
        color: .secondaryLabelColor,
        lines: 3,
        lineBreakMode: .byWordWrapping
    )
    private let accountSectionLabel = welcomeShellLabel(
        NSLocalizedString("账号设置", comment: ""),
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: .secondaryLabelColor
    )
    private let bangumiSectionLabel = welcomeShellLabel(
        NSLocalizedString("bangumi.tv 关联", comment: ""),
        font: .systemFont(ofSize: 13, weight: .semibold),
        color: .secondaryLabelColor
    )

    private let nicknameRow = AccountSettingsRowView(
        title: NSLocalizedString("修改昵称", comment: ""),
        subtitle: NSLocalizedString("1–50 个字符", comment: ""),
        symbolName: "pencil",
        identifier: AccessibilityID.Account.nicknameRow
    )
    private let emailRow = AccountSettingsRowView(
        title: NSLocalizedString("修改邮箱", comment: ""),
        subtitle: NSLocalizedString("新邮箱可能需要重新验证", comment: ""),
        symbolName: "envelope",
        identifier: AccessibilityID.Account.emailRow
    )
    private let passwordRow = AccountSettingsRowView(
        title: NSLocalizedString("修改密码", comment: ""),
        subtitle: NSLocalizedString("修改后可能需要重新登录", comment: ""),
        symbolName: "lock",
        identifier: AccessibilityID.Account.passwordRow
    )
    private let verifyEmailRow = AccountSettingsRowView(
        title: NSLocalizedString("验证邮箱", comment: ""),
        subtitle: NSLocalizedString("在浏览器中打开邮箱验证页面", comment: ""),
        symbolName: "checkmark.seal",
        identifier: AccessibilityID.Account.verifyEmailRow
    )
    private let bangumiCard = AccountBangumiCardView()
    private let logoutRow = AccountSettingsRowView(
        title: NSLocalizedString("退出登录", comment: ""),
        subtitle: NSLocalizedString("清除本机的登录状态", comment: ""),
        symbolName: "rectangle.portrait.and.arrow.right",
        identifier: AccessibilityID.Account.logoutRow,
        destructive: true
    )

    private var observerTokens: [NSObjectProtocol] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("账号资料", comment: "")
        view.setAccessibilityIdentifier(AccessibilityID.Account.root)

        statusLabel.setAccessibilityIdentifier(AccessibilityID.Account.status)
        statusLabel.isHidden = true

        addFullWidth(header)
        addFullWidth(statusLabel, spacingAfter: 0)
        addFullWidth(accountSectionLabel, spacingAfter: 0)
        addFullWidth(nicknameRow, spacingAfter: 0)
        addFullWidth(emailRow, spacingAfter: 0)
        addFullWidth(passwordRow, spacingAfter: 0)
        addFullWidth(verifyEmailRow, spacingAfter: 4)
        addFullWidth(bangumiSectionLabel, spacingAfter: 0)
        addFullWidth(bangumiCard, spacingAfter: 6)
        addFullWidth(logoutRow)

        configureActions()
        installObservers()
        render()

        viewModel.onUpdate = { [weak self] in
            self?.render()
        }
        Task { @MainActor [weak self] in
            await self?.viewModel.reloadSession()
        }
    }

    deinit {
        observerTokens.forEach { NotificationCenter.default.removeObserver($0) }
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        Task { @MainActor [weak self] in
            await self?.viewModel.reloadSession()
        }
    }

    // MARK: - Actions

    private func configureActions() {
        header.onHeaderAction = { [weak self] in
            guard let self = self else { return }
            if self.viewModel.isLoggedIn {
                Task { @MainActor [weak self] in
                    await self?.viewModel.refreshProfile()
                }
            } else {
                Task { @MainActor [weak self] in
                    await self?.login()
                }
            }
        }

        nicknameRow.onClick = { [weak self] in
            guard let self = self, self.viewModel.canEdit else { return }
            let current = self.viewModel.profile?.screenName ?? ""
            self.presentEditor(.screenName(current: current))
        }
        emailRow.onClick = { [weak self] in
            guard let self = self, self.viewModel.canEdit else { return }
            let current = self.viewModel.profile?.email ?? ""
            self.presentEditor(.email(currentEmail: current))
        }
        passwordRow.onClick = { [weak self] in
            guard let self = self, self.viewModel.canEdit else { return }
            self.presentEditor(.password)
        }
        verifyEmailRow.onClick = { [weak self] in
            guard let self = self, self.viewModel.canEdit else { return }
            Task { @MainActor [weak self] in
                await self?.viewModel.verifyEmail()
            }
        }

        bangumiCard.onAuthorize = { [weak self] in
            guard let self = self, self.viewModel.canEdit else { return }
            Task { @MainActor [weak self] in
                await self?.viewModel.authorizeBangumi()
            }
        }
        bangumiCard.onManage = { [weak self] in
            guard let self = self, self.viewModel.canEdit else { return }
            Task { @MainActor [weak self] in
                await self?.viewModel.manageBangumi()
            }
        }
        bangumiCard.onRefresh = { [weak self] in
            guard let self = self, !self.viewModel.isSubmitting else { return }
            Task { @MainActor [weak self] in
                await self?.viewModel.refreshProfile()
            }
        }

        logoutRow.onClick = { [weak self] in
            self?.confirmLogout()
        }
    }

    private func installObservers() {
        observerTokens.append(NotificationCenter.default.addObserver(
            forName: .AnixUserLoginStateDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.viewModel.reloadSession()
            }
        })

        observerTokens.append(NotificationCenter.default.addObserver(
            forName: NSApplication.didBecomeActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self = self, self.viewModel.consumePendingExternalRefresh() else { return }
                await self.viewModel.refreshProfile(silent: true)
            }
        })
    }

    private func login() async {
        _ = await LoginGate.shared.ensureLoggedIn(presenting: view.window)
        await viewModel.reloadSession()
    }

    private func presentEditor(_ mode: AccountEditSheetViewController.Mode) {
        let editor = AccountEditSheetViewController(mode: mode)
        editor.onSubmit = { [weak self] submission in
            guard let self = self else { return }
            switch submission {
            case .screenName(let screenName):
                try await self.viewModel.changeScreenName(screenName)
            case .email(let oldEmail, let newEmail):
                try await self.viewModel.changeEmail(old: oldEmail, new: newEmail)
            case .password(let oldPassword, let newPassword, let confirmation):
                try await self.viewModel.changePassword(
                    old: oldPassword,
                    new: newPassword,
                    confirmation: confirmation
                )
            }
        }
        presentAsSheet(editor)
    }

    private func confirmLogout() {
        guard let window = view.window else { return }
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("确定退出登录吗？", comment: "")
        alert.informativeText = NSLocalizedString("退出后，需要重新登录才能管理账号资料。", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("退出登录", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        alert.beginSheetModal(for: window) { [weak self] response in
            guard response == .alertFirstButtonReturn else { return }
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                await self.viewModel.logout()
                self.onLoggedOut?()
            }
        }
    }

    // MARK: - Render

    private func render() {
        header.update(
            isLoggedIn: viewModel.isLoggedIn,
            profile: viewModel.profile,
            isRefreshing: viewModel.isRefreshing
        )

        let loggedIn = viewModel.isLoggedIn
        let hasEmail = !(viewModel.profile?.email ?? "").isEmpty
        let needsEmailVerification = hasEmail && viewModel.profile?.emailVerified != true

        accountSectionLabel.isHidden = !loggedIn
        nicknameRow.isHidden = !loggedIn
        emailRow.isHidden = !loggedIn
        passwordRow.isHidden = !loggedIn
        verifyEmailRow.isHidden = !(loggedIn && needsEmailVerification)
        bangumiSectionLabel.isHidden = !loggedIn
        bangumiCard.isHidden = !loggedIn
        logoutRow.isHidden = !loggedIn

        let enabled = viewModel.canEdit
        nicknameRow.setEnabled(enabled)
        emailRow.setEnabled(enabled)
        passwordRow.setEnabled(enabled)
        verifyEmailRow.setEnabled(enabled)
        logoutRow.setEnabled(!viewModel.isSubmitting)
        bangumiCard.update(state: viewModel.bangumiState, isBusy: !enabled)

        if let status = viewModel.statusMessage {
            statusLabel.stringValue = status.text
            statusLabel.isHidden = false
            switch status.tone {
            case .info:
                statusLabel.textColor = .secondaryLabelColor
            case .success:
                statusLabel.textColor = .systemGreen
            case .error:
                statusLabel.textColor = .systemRed
            }
            statusLabel.setAccessibilityLabel(status.text)
        } else {
            statusLabel.isHidden = true
            statusLabel.stringValue = ""
            statusLabel.setAccessibilityLabel(nil)
        }

        layoutContent()
    }
}
