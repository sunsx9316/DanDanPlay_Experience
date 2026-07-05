//
//  PlayerLaunchViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/7/5.
//

import Cocoa
import SnapKit
import ANXLog

class PlayerLaunchViewController: ViewController {

    var onOpenFiles: (([File], File?) -> Void)?

    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] files in
            guard let self = self else { return }

            let mediaFiles = files.filter { !$0.url.isSubtitleFile && !$0.url.isDanmakuFile }
            if !mediaFiles.isEmpty {
                self.onOpenFiles?(mediaFiles, nil)
            }
        }
        return view
    }()

    private lazy var openButton: Button = {
        let button = Button.custom()
        button.bezelStyle = .texturedSquare
        button.title = NSLocalizedString("打开或拖入文件", comment: "")
        button.isBordered = true
        button.showsBorderOnlyWhileMouseInside = true
        button.focusRingType = .none
        button.addTarget(self, action: #selector(pickFile))
        return button
    }()

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = InfoPlistUtils.appName

        self.view.addSubview(dragView)
        self.view.addSubview(openButton)

        dragView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        openButton.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.size.equalTo(CGSize(width: 150, height: 60))
        }

        setupMenu()
    }

    // MARK: - File Menu

    private func setupMenu() {
        if let fileItem = NSApp.appDelegate?.fileMenu?.item(withTag: MenuTag.fileOpen.rawValue) {
            fileItem.target = self
            fileItem.action = #selector(pickFile)
        }
    }

    // MARK: - Actions

    @objc private func pickFile() {
        ANX.logInfo(.UI, "[PlayerLaunch] 点击打开文件")
        LocalFile.fileManager.pickFiles(LocalFile.rootFile, from: self, filterType: .all) { [weak self] result in
            guard let self = self else { return }

            switch result {
            case .success(let files):
                if let first = files.first, files.count == 1, first.url.isSubtitleFile || first.url.isDanmakuFile {
                    self.view.show(text: NSLocalizedString("请先打开视频文件", comment: ""))
                    return
                }
                self.onOpenFiles?(files, nil)
            case .failure:
                break
            }
        }
    }
}
