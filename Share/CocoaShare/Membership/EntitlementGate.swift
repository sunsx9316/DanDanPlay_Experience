//
//  EntitlementGate.swift
//  AniXPlayer
//
//  macOS only：统一权益门禁。
//
//  业务侧只调用 `EntitlementGate.shared.require(...)`，不要在业务代码里散落
//  `isMember` 判断。门禁负责：登录 -> 刷新权益（60 秒缓存） -> 放行或展示会员中心。
//

import AppKit
import Foundation

/// 需要会员/独立权益的功能。原始值用于埋点与日志，不要随意修改。
enum MembershipFeature: String, CaseIterable, Sendable {
    case aiTranslate
    case aiSummary
    case backupDanmaku
    case gifExport
    case resmonitor
    case batchDanmakuExport
    case onlinePlayback
    case mediaSniffer
    case superResolution
    case videoInterpolation

    var title: String {
        switch self {
        case .aiTranslate:
            return NSLocalizedString("AI 字幕翻译", comment: "")
        case .aiSummary:
            return NSLocalizedString("AI 视频总结", comment: "")
        case .backupDanmaku:
            return NSLocalizedString("会员补充弹幕", comment: "")
        case .gifExport:
            return NSLocalizedString("动图导出", comment: "")
        case .resmonitor:
            return NSLocalizedString("资源监视器", comment: "")
        case .batchDanmakuExport:
            return NSLocalizedString("批量导出弹幕", comment: "")
        case .onlinePlayback:
            return NSLocalizedString("在线观看", comment: "")
        case .mediaSniffer:
            return NSLocalizedString("媒体嗅探", comment: "")
        case .superResolution:
            return NSLocalizedString("超分辨率", comment: "")
        case .videoInterpolation:
            return NSLocalizedString("视频补帧", comment: "")
        }
    }

    var summary: String {
        switch self {
        case .aiTranslate:
            return NSLocalizedString("使用 AI 翻译服务，将字幕翻译为另一种语言。", comment: "")
        case .aiSummary:
            return NSLocalizedString("通过弹弹play AI 服务，为视频生成带时间点的内容总结。", comment: "")
        case .backupDanmaku:
            return NSLocalizedString("主弹幕不足时，从关联/备用来源补充并合并弹幕。", comment: "")
        case .gifExport:
            return NSLocalizedString("将视频片段导出为 GIF 动图。", comment: "")
        case .resmonitor:
            return NSLocalizedString("监控网络、下载与播放状态等运行信息。", comment: "")
        case .batchDanmakuExport:
            return NSLocalizedString("将已缓存的弹幕批量导出为标准 XML 文件。", comment: "")
        case .onlinePlayback:
            return NSLocalizedString("搜索全网视频资源并在线播放，同时加载关联弹幕。", comment: "")
        case .mediaSniffer:
            return NSLocalizedString("自动检测网页中的视频并在弹幕播放器中播放。", comment: "")
        case .superResolution:
            return NSLocalizedString("使用 Anime4K 等着色器实时提升画面清晰度。", comment: "")
        case .videoInterpolation:
            return NSLocalizedString("通过补帧脚本让运动画面更加流畅。", comment: "")
        }
    }

    var detail: String {
        switch self {
        case .aiSummary:
            return NSLocalizedString("AI 视频总结会根据字幕内容生成一段简短概述，并列出每个主题小节的时间点，方便快速了解视频内容。AI 服务由弹弹play提供，可能需要消耗服务端额度。", comment: "")
        case .aiTranslate:
            return NSLocalizedString("字幕翻译通过弹弹play在线翻译服务完成，生成结果可导出为字幕文件。翻译质量与额度由服务端控制。", comment: "")
        case .backupDanmaku:
            return NSLocalizedString("当主弹幕数量不足、来源不可用，或你主动点击「补充弹幕」时，客户端会从关联/备用来源拉取一批弹幕，与主弹幕去重合并后显示。非会员仍可正常观看主弹幕。", comment: "")
        default:
            return summary
        }
    }

    var entitlement: Entitlement {
        switch self {
        case .resmonitor:
            return .resmonitor
        default:
            return .member
        }
    }

    var contextHeadline: String {
        switch entitlement {
        case .member:
            return String(format: NSLocalizedString("「%@」需要弹弹play会员", comment: ""), title)
        case .resmonitor:
            return String(format: NSLocalizedString("「%@」需要资源监视器权益", comment: ""), title)
        }
    }
}

/// 统一权益门禁。
///
/// 依赖通过 `install(loginHandler:paywallHandler:)` 注入，便于：
/// 1. 无宿主单测使用 mock 登录/付费墙；
/// 2. 门禁本身不依赖具体窗口实现。
@MainActor
final class EntitlementGate {
    static let shared = EntitlementGate(store: MembershipStore.shared)

    typealias LoginHandler = (NSWindow?) async -> Bool
    typealias PaywallHandler = (MembershipFeature?, NSWindow?) async -> Bool

    private let store: MembershipEntitlementProviding
    private let nowProvider: () -> Date
    private var loginHandler: LoginHandler?
    private var paywallHandler: PaywallHandler?

    init(
        store: MembershipEntitlementProviding,
        now: @escaping () -> Date = Date.init
    ) {
        self.store = store
        self.nowProvider = now
    }

    /// 由 macOS 集成层调用；应在展示会员中心/菜单入口前完成。
    func install(loginHandler: @escaping LoginHandler, paywallHandler: @escaping PaywallHandler) {
        self.loginHandler = loginHandler
        self.paywallHandler = paywallHandler
    }

    var isInstalled: Bool {
        paywallHandler != nil
    }

    /// 返回 true 表示可以继续使用功能；false 表示用户未登录、未开通或取消。
    func require(
        _ entitlement: Entitlement,
        feature: MembershipFeature,
        presenting window: NSWindow? = nil
    ) async -> Bool {
        if let loginHandler = loginHandler {
            guard await loginHandler(window) else {
                return false
            }
        } else if store.cachedUserInfo == nil {
            // 门禁未接线且没有任何用户信息时不能放行。
            return false
        }

        do {
            _ = try await store.refresh(force: false)
        } catch {
            // 网络失败时允许使用未过期的缓存；服务端仍会对关键接口做最终校验。
        }

        if entitlementStatus(for: entitlement).isActive {
            return true
        }

        guard let paywallHandler = paywallHandler else {
            return false
        }

        let purchased = await paywallHandler(feature, window)
        guard purchased else {
            return false
        }

        do {
            _ = try await store.refresh(force: true)
        } catch {
            // 支付/兑换成功后网络失败：以缓存是否已更新为准，绝不本地延长会员。
        }
        return entitlementStatus(for: entitlement).isActive
    }

    /// 仅用于 UI 展示/判断；业务门禁必须走 `require`。
    func entitlementStatus(for entitlement: Entitlement) -> EntitlementStatus {
        store.entitlementStatus(for: entitlement, now: nowProvider())
    }
}
