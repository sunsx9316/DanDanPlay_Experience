//
//  MacFeatureLauncher.swift
//  AniXPlayer
//
//  macOS：付费/AI 功能的统一入口。
//  菜单、欢迎页和播放器都从这里打开窗口，确保会员门禁只接线一次。
//

import AppKit

@MainActor
enum MacFeatureLauncher {
    private static var translationWindowController: TranslationWindowController?
    private static var summaryWindowController: SummaryWindowController?

    /// 把 LoginGate 和会员中心注册到 EntitlementGate（幂等）。
    static func installEntitlements() {
        MacMembershipIntegration.install()
    }

    static func showMembership(feature: MembershipFeature? = nil, presenting: NSWindow? = nil) {
        installEntitlements()
        Task { @MainActor in
            _ = await MembershipWindowController.present(feature: feature, presenting: presenting)
        }
    }

    static func showTranslation(presenting: NSWindow? = nil) {
        installEntitlements()

        if let controller = translationWindowController {
            controller.showWindow()
            return
        }

        let controller = TranslationWindowController(accessCheck: {
            await EntitlementGate.shared.require(
                .member,
                feature: .aiTranslate,
                presenting: presenting ?? NSApp.keyWindow
            )
        })
        translationWindowController = controller
        controller.showWindow()
    }

    static func showSummary(presenting: NSWindow? = nil) {
        installEntitlements()

        if let controller = summaryWindowController {
            controller.showWindow()
            return
        }

        let controller = SummaryWindowController(accessCheck: {
            await EntitlementGate.shared.require(
                .member,
                feature: .aiSummary,
                presenting: presenting ?? NSApp.keyWindow
            )
        })
        summaryWindowController = controller
        controller.showWindow()
    }
}
