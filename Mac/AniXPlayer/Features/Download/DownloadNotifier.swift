//
//  DownloadNotifier.swift
//  AniXPlayer
//
//  macOS：下载完成/失败的系统通知。仅在前台运行时展示横幅，点击后定位任务。
//

import AppKit
import Foundation
import UserNotifications

final class DownloadNotifier: NSObject, UNUserNotificationCenterDelegate {

    static let shared = DownloadNotifier()

    /// 用户点击通知后回调任务 ID（主线程）。
    var onSelectTask: ((UUID) -> Void)? {
        didSet {
            guard let pendingSelection, let onSelectTask else { return }
            self.pendingSelection = nil
            DispatchQueue.main.async {
                onSelectTask(pendingSelection)
            }
        }
    }

    private static let requestedKey = "download.notificationsRequested"
    private let center = UNUserNotificationCenter.current()
    private var isActivated = false
    private var pendingSelection: UUID?

    private override init() {
        super.init()
    }

    func activate() {
        guard !isActivated else { return }
        isActivated = true
        center.delegate = self
    }

    /// 只请求一次系统权限；之后被拒绝时由设置页提示用户去系统设置。
    func requestAuthorizationIfNeeded(preferences: DownloadPreferences = .shared) {
        guard preferences.notificationsEnabled else { return }
        guard !UserDefaults.standard.bool(forKey: Self.requestedKey) else { return }
        UserDefaults.standard.set(true, forKey: Self.requestedKey)

        center.requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    func authorizationStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        center.getNotificationSettings { settings in
            completion(settings.authorizationStatus)
        }
    }

    func notifyTaskFinished(_ task: DownloadTask, preferences: DownloadPreferences = .shared) {
        guard preferences.notificationsEnabled else { return }
        guard task.status == .completed || task.status == .failed else { return }

        let content = UNMutableNotificationContent()
        if task.status == .completed {
            content.title = NSLocalizedString("下载完成", comment: "")
            content.body = task.displayTitle
        } else {
            content.title = NSLocalizedString("下载失败", comment: "")
            let detail = task.errorMessage?.trimmingCharacters(in: .whitespacesAndNewlines)
            if let detail, !detail.isEmpty {
                content.body = "\(task.displayTitle)\n\(detail)"
            } else {
                content.body = task.displayTitle
            }
        }
        content.sound = .default
        content.userInfo = ["taskID": task.id.uuidString]

        let request = UNNotificationRequest(
            identifier: "download.\(task.id.uuidString).\(UUID().uuidString)",
            content: content,
            trigger: nil
        )
        center.add(request, withCompletionHandler: nil)
    }

    func openNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications",
        ]
        for candidate in candidates {
            if let url = URL(string: candidate), NSWorkspace.shared.open(url) {
                return
            }
        }
    }

    // MARK: - UNUserNotificationCenterDelegate

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        defer { completionHandler() }
        guard let value = response.notification.request.content.userInfo["taskID"] as? String,
              let taskID = UUID(uuidString: value) else {
            return
        }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            if let onSelectTask = self.onSelectTask {
                onSelectTask(taskID)
            } else {
                self.pendingSelection = taskID
            }
        }
    }
}
