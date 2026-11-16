//
//  MembershipWindowController.swift
//  AniXPlayer
//
//  macOS only：会员中心独立窗口与权益门禁集成。
//
//  集成入口：
//    MembershipWindowController(feature: nil).showWindow()
//  付费墙入口：
//    EntitlementGate.shared.require(.member, feature: .aiSummary, presenting: window)
//

import Cocoa

@MainActor
final class MembershipWindowController: NSWindowController {
    let feature: MembershipFeature?

    private let viewModel: MembershipViewModel
    private let membershipViewController: MembershipViewController
    private weak var presentingWindow: NSWindow?

    private var didFinish = false
    private var finishResult = false
    private var completionWaiters: [CheckedContinuation<Bool, Never>] = []

    private static var activeController: MembershipWindowController?

    init(feature: MembershipFeature?) {
        self.feature = feature
        self.viewModel = MembershipViewModel(feature: feature)
        self.membershipViewController = MembershipViewController(viewModel: viewModel)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 680),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = NSLocalizedString("弹弹play 会员", comment: "")
        window.isReleasedWhenClosed = false
        window.identifier = NSUserInterfaceItemIdentifier(AccessibilityID.Membership.window)
        window.contentViewController = membershipViewController
        // 设置 contentViewController 时 AppKit 会按内容 fittingSize 收缩窗口；
        // 会员页没有强宽度约束，会被压到 200pt。内容侧再加了 >=720 的宽度约束，
        // 这里同步限制内容尺寸，并用 setContentSize 作为其他系统版本的兜底。
        window.contentMinSize = NSSize(width: 720, height: 628)
        window.minSize = NSSize(width: 720, height: 660)
        window.setContentSize(NSSize(width: 760, height: 680))
        window.center()

        super.init(window: window)

        window.delegate = self
        membershipViewController.view.setAccessibilityIdentifier(AccessibilityID.Membership.window)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// 菜单/用户中心入口：先确保登录，再展示会员中心。
    func showWindow() {
        begin(presenting: nil)
    }

    /// 付费墙入口：返回 true 表示窗口关闭时用户已具备会员（最终仍以门禁刷新结果为准）。
    static func present(feature: MembershipFeature?, presenting window: NSWindow?) async -> Bool {
        MacMembershipIntegration.install()

        if let active = activeController {
            active.window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return await active.waitForFinish()
        }

        let controller = MembershipWindowController(feature: feature)
        activeController = controller
        controller.presentingWindow = window
        controller.begin(presenting: window)
        return await controller.waitForFinish()
    }

    private func begin(presenting: NSWindow?) {
        guard !didFinish else { return }
        if window?.isVisible == true {
            window?.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        if let presenting = presenting {
            presentingWindow = presenting
        }

        Self.activeController = self
        Task { @MainActor [weak self] in
            guard let self = self else { return }
            MacMembershipIntegration.install()

            let loggedIn = await LoginGate.shared.ensureLoggedIn(
                presenting: self.presentingWindow ?? self.window
            )
            guard loggedIn else {
                self.finish(false)
                return
            }

            self.viewModel.begin()
            NSApp.activate(ignoringOtherApps: true)
            self.showWindow(nil)
            self.window?.makeKeyAndOrderFront(nil)
        }
    }

    private func waitForFinish() async -> Bool {
        if didFinish {
            return finishResult
        }
        return await withCheckedContinuation { continuation in
            if didFinish {
                continuation.resume(returning: finishResult)
            } else {
                completionWaiters.append(continuation)
            }
        }
    }

    private func finish(_ success: Bool) {
        guard !didFinish else { return }
        didFinish = true
        finishResult = success
        viewModel.stopAll()

        let waiters = completionWaiters
        completionWaiters.removeAll()
        for waiter in waiters {
            waiter.resume(returning: success)
        }

        if Self.activeController === self {
            Self.activeController = nil
        }
    }
}

extension MembershipWindowController: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        let entitlementActive: Bool
        if let feature = feature {
            entitlementActive = viewModel.isEntitlementActive(feature.entitlement)
        } else {
            entitlementActive = viewModel.hasActiveMembership
        }
        // 付费墙只需要知道用户是否完成了支付/兑换；最终权益仍由门禁强制刷新确认。
        finish(viewModel.didCompletePurchase || entitlementActive)
    }
}

/// macOS 集成层：把 LoginGate 与会员中心接到统一门禁上。
@MainActor
enum MacMembershipIntegration {
    static func install() {
        EntitlementGate.shared.install(
            loginHandler: { window in
                await LoginGate.shared.ensureLoggedIn(presenting: window)
            },
            paywallHandler: { feature, window in
                await MembershipWindowController.present(feature: feature, presenting: window)
            }
        )
    }
}
