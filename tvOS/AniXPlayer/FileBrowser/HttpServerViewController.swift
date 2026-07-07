//
//  HttpServerViewController.swift
//  AniXPlayer
//
//  tvOS WiFi 文件传输页面
//

import UIKit
import SnapKit

// MARK: - UploadItem

private enum UploadItem {
    case file(File)
    case folder(name: String, completed: Int, total: Int?)

    var total: Int? {
        if case .folder(_, _, let total) = self { return total }
        return nil
    }
}

// MARK: - HttpServerDelegate

extension HttpServerViewController: HttpServerDelegate {
    func httpServer(_ httpServer: HttpServer, didReceiveFileAtPath path: String, folderName: String?, totalFiles: Int?) {
        DispatchQueue.main.async {
            if let folderName = folderName, !folderName.isEmpty {
                if let index = self.uploadItems.firstIndex(where: { item in
                    if case .folder(let name, _, _) = item, name == folderName { return true }
                    return false
                }) {
                    if case .folder(let name, let completed, _) = self.uploadItems[index] {
                        self.uploadItems[index] = .folder(name: name, completed: completed + 1, total: totalFiles ?? self.uploadItems[index].total)
                    }
                } else {
                    self.uploadItems.append(.folder(name: folderName, completed: 1, total: totalFiles))
                }
            } else {
                let file = LocalFile(with: .init(fileURLWithPath: path))
                self.uploadItems.append(.file(file))
            }

            self.tableView.reloadData()
        }
    }

    func httpServerDidStart(_ httpServer: HttpServer) {
        DispatchQueue.main.async {
            self.updateAddress()
        }
    }
}

// MARK: - UITableViewDataSource

extension HttpServerViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return uploadItems.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: FileListCell.self, indexPath: indexPath)
        let item = uploadItems[indexPath.row]
        switch item {
        case .file(let file):
            cell.configure(with: file)
        case .folder(let name, let completed, let total):
            if let total = total {
                cell.configureAsSource(title: "\(name) (\(completed)/\(total))", iconName: "folder")
            } else {
                cell.configureAsSource(title: name, iconName: "folder")
            }
        }
        return cell
    }
}

// MARK: - UITableViewDelegate

extension HttpServerViewController: UITableViewDelegate {}

// MARK: - HttpServerViewController

class HttpServerViewController: ViewController {

    private lazy var httpServer: HttpServer = {
        let httpServer = HttpServer()
        httpServer.delegate = self
        return httpServer
    }()

    private var uploadItems = [UploadItem]()

    private lazy var urlLabel: Label = {
        let label = Label()
        label.font = .ddp_large(weight: .bold)
        label.textColor = .mainColor
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private lazy var instructionLabel: Label = {
        let label = Label()
        label.font = .ddp_small(weight: .medium)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        label.text = NSLocalizedString("在电脑浏览器地址栏输入以下地址", comment: "")
        return label
    }()

    private lazy var tipLabel: Label = {
        let label = Label()
        label.font = .ddp_small()
        label.textColor = .tertiaryLabel
        label.textAlignment = .center
        label.text = NSLocalizedString("上传过程中请勿离开此页面", comment: "")
        return label
    }()

    private lazy var headerStack: UIStackView = {
        let stack = UIStackView(arrangedSubviews: [instructionLabel, urlLabel, tipLabel])
        stack.axis = .vertical
        stack.alignment = .center
        stack.spacing = 20
        stack.layoutMargins = UIEdgeInsets(top: 40, left: 60, bottom: 20, right: 60)
        stack.isLayoutMarginsRelativeArrangement = true
        return stack
    }()

    private lazy var headerContainerView: UIView = {
        let view = FocusableView()
        view.addSubview(headerStack)
        headerStack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        return view
    }()

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: FileListCell.self)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        return tv
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("WiFi传文件", comment: "")

        view.addSubview(headerContainerView)
        view.addSubview(tableView)

        headerContainerView.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.leading.trailing.equalToSuperview()
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(headerContainerView.snp.bottom).offset(20)
            make.leading.trailing.bottom.equalToSuperview()
        }

        httpServer.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        httpServer.stop()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = headerContainerView
    }

    private func updateAddress() {
        let urlString = httpServer.serverURL?.absoluteString ?? ""
        urlLabel.text = "\n\(urlString)\n"
    }
}

// MARK: - FocusableView

private class FocusableView: UIView {
    override var canBecomeFocused: Bool { true }
}
