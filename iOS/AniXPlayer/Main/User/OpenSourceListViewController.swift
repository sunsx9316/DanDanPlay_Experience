//
//  OpenSourceListViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/5/29.
//

import UIKit

class OpenSourceListViewController: ViewController {

    private struct Library {
        let name: String
        let url: String
    }

    private let libraries: [Library] = [
        .init(name: "Alamofire", url: "https://github.com/Alamofire/Alamofire"),
        .init(name: "AMSMB2", url: "https://github.com/amosavian/AMSMB2"),
        .init(name: "ANXLog", url: "https://github.com/sunsx9316/DanDanPlay_Experience"),
        .init(name: "CocoaLumberjack", url: "https://github.com/CocoaLumberjack/CocoaLumberjack"),
        .init(name: "Color-Picker-for-iOS", url: "https://github.com/hayashi311/Color-Picker-for-iOS"),
        .init(name: "DanmakuRender-Swift", url: "https://github.com/sunsx9316/DanmakuRender-Swift"),
        .init(name: "FileProvider", url: "https://github.com/amosavian/FileProvider"),
        .init(name: "FirebaseCrashlytics", url: "https://github.com/firebase/firebase-ios-sdk"),
        .init(name: "GCDWebServer", url: "https://github.com/sunsx9316/GCDWebServer"),
        .init(name: "IQKeyboardManager", url: "https://github.com/hackiftekhar/IQKeyboardManager"),

        .init(name: "MJRefresh", url: "https://github.com/CoderMJLee/MJRefresh"),
        .init(name: "VLCKit", url: "https://code.videolan.org/videolan/VLCKit"),
        .init(name: "MPVKit", url: "https://github.com/mpvkit/MPVKit"),
        .init(name: "RxSwift", url: "https://github.com/ReactiveX/RxSwift"),
        .init(name: "Kingfisher", url: "https://github.com/onevcat/Kingfisher"),
        .init(name: "SnapKit", url: "https://github.com/SnapKit/SnapKit"),
        .init(name: "swift-log", url: "https://github.com/apple/swift-log"),
        .init(name: "YYCategories", url: "https://github.com/sunsx9316/YYCategories"),
    ]

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: SeparatorTableViewCell.self)
        tv.rowHeight = 50
        tv.separatorStyle = .none
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("开源组件", comment: "")
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }
}

extension OpenSourceListViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return libraries.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: SeparatorTableViewCell.self, indexPath: indexPath)
        cell.textLabel?.text = libraries[indexPath.row].name
        cell.textLabel?.font = .systemFont(ofSize: 16)
        cell.accessoryType = .disclosureIndicator
        return cell
    }
}

extension OpenSourceListViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, heightForHeaderInSection section: Int) -> CGFloat {
        return 20
    }

    func tableView(_ tableView: UITableView, heightForFooterInSection section: Int) -> CGFloat {
        return .leastNonzeroMagnitude
    }

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        guard let url = URL(string: libraries[indexPath.row].url) else { return }
        UIApplication.shared.open(url)
    }
}
