//
//  WelcomeRecentViewController.swift
//  AniXPlayer
//
//  macOS：欢迎页继续播放（本地最近播放，最多 10 条）。
//

import Cocoa
import SnapKit

final class WelcomeRecentViewController: WelcomeShellScrollPageViewController {

    weak var router: WelcomeShellRouting?

    private let recentStore = WelcomeRecentStore.shared
    private var items: [WelcomeRecentItem] = []

    private lazy var headerView: WelcomeShellPageHeaderView = {
        let view = WelcomeShellPageHeaderView(
            title: NSLocalizedString("继续播放", comment: ""),
            subtitle: NSLocalizedString("从上次看到的位置继续", comment: "")
        )

        let openButton = WelcomeShellClosureButton(title: NSLocalizedString("打开文件", comment: ""))
        openButton.bezelStyle = .rounded
        openButton.controlSize = .small
        openButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.recentOpenFile)
        openButton.onClick = { [weak self] in
            self?.router?.openLocalFiles()
        }

        let clearButton = WelcomeShellClosureButton(title: NSLocalizedString("清空", comment: ""))
        clearButton.bezelStyle = .rounded
        clearButton.controlSize = .small
        clearButton.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.recentClear)
        clearButton.onClick = { [weak self] in
            self?.confirmClear()
        }

        view.trailingStack.addArrangedSubview(openButton)
        view.trailingStack.addArrangedSubview(clearButton)
        return view
    }()

    private let stateView = WelcomeShellStateView()
    private let listStack = NSStackView()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.recentRoot)
        title = NSLocalizedString("继续播放", comment: "")

        listStack.orientation = .vertical
        listStack.alignment = .width
        listStack.spacing = 8
        listStack.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.recentList)
        stateView.setAccessibilityIdentifier(AccessibilityID.WelcomeShell.recentStatus)

        addFullWidth(headerView, spacingAfter: 4)
        addFullWidth(stateView)
        addFullWidth(listStack)

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(recentDidChange),
            name: .welcomeRecentPlaybackDidChange,
            object: nil
        )

        reload()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    override func viewWillAppear() {
        super.viewWillAppear()
        reload()
    }

    private func reload() {
        items = WelcomeShellDataMapper.recentItems(recentStore.items, limit: 10)
        rebuildList()
    }

    private func rebuildList() {
        listStack.arrangedSubviews.forEach {
            listStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        guard !items.isEmpty else {
            listStack.isHidden = true
            stateView.isHidden = false
            stateView.configure(
                title: NSLocalizedString("还没有播放记录", comment: ""),
                detail: NSLocalizedString("打开视频后，这里会显示最近播放与进度", comment: ""),
                actionTitle: NSLocalizedString("打开文件", comment: ""),
                onAction: { [weak self] in
                    self?.router?.openLocalFiles()
                }
            )
            layoutContent()
            return
        }

        stateView.isHidden = true
        listStack.isHidden = false

        for (index, item) in items.enumerated() {
            let row = WelcomeShellRecentRowView()
            row.configure(with: item, index: index)
            row.onClick = { [weak self] in
                self?.play(item)
            }
            row.onRemove = { [weak self] in
                self?.recentStore.remove(path: item.path)
            }
            listStack.addArrangedSubview(row)
            row.snp.makeConstraints { make in
                make.width.equalTo(listStack)
            }
        }
        layoutContent()
    }

    private func play(_ item: WelcomeRecentItem) {
        guard let url = recentStore.resolveURL(for: item) else {
            recentStore.remove(path: item.path)
            view.show(text: NSLocalizedString("文件已不存在或无法访问", comment: ""))
            return
        }
        let file = LocalFile(with: url)
        router?.play(files: [file], startWith: file)
    }

    private func confirmClear() {
        guard !items.isEmpty else { return }

        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = NSLocalizedString("清空播放历史？", comment: "")
        alert.informativeText = NSLocalizedString("清空后将删除所有最近播放记录，且无法恢复。", comment: "")
        alert.addButton(withTitle: NSLocalizedString("清空", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        if let window = view.window {
            alert.beginSheetModal(for: window) { [weak self] response in
                guard response == .alertFirstButtonReturn else { return }
                self?.recentStore.clear()
            }
        } else if alert.runModal() == .alertFirstButtonReturn {
            recentStore.clear()
        }
    }

    @objc private func recentDidChange() {
        reload()
    }
}
