//
//  HttpServerViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2021/6/12.
//

import UIKit
import SnapKit

extension HttpServerViewController: HttpServerDelegate {
    func httpServer(_ httpServer: HttpServer, didReceiveFileAtPath path: String, folderName: String?, totalFiles: Int?) {
        DispatchQueue.main.async {
            if let folderName = folderName, !folderName.isEmpty {
                if let index = self.items.firstIndex(where: { item in
                    if case .folder(let name, _, _) = item, name == folderName { return true }
                    return false
                }) {
                    if case .folder(let name, let completed, _) = self.items[index] {
                        self.items[index] = .folder(name: name, completed: completed + 1, total: totalFiles ?? self.items[index].total)
                    }
                } else {
                    self.items.append(.folder(name: folderName, completed: 1, total: totalFiles))
                }
            } else {
                let file = LocalFile(with: .init(fileURLWithPath: path))
                self.items.append(.file(file))
            }

            self.tableView.reloadData()
        }
    }

    func httpServerDidStart(_ httpServer: HttpServer) {
        DispatchQueue.main.async {
            self.resetAddress()
        }
    }
}

private enum UploadItem {
    case file(File)
    case folder(name: String, completed: Int, total: Int?)

    var total: Int? {
        if case .folder(_, _, let total) = self { return total }
        return nil
    }
}

extension HttpServerViewController: UITableViewDelegate, UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return self.items.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch self.items[indexPath.row] {
        case .file(let file):
            let cell = tableView.dequeueCell(class: FileTableViewCell.self, indexPath: indexPath)
            cell.file = file
            cell.backgroundView?.backgroundColor = .backgroundColor
            return cell
        case .folder(let name, let completed, let total):
            let cell = tableView.dequeueCell(class: FolderProgressCell.self, indexPath: indexPath)
            cell.configure(folderName: name, completed: completed, total: total)
            return cell
        }
    }
}

class HttpServerViewController: ViewController {

    private lazy var httpServer: HttpServer = {
        let httpServer = HttpServer()
        httpServer.delegate = self
        return httpServer
    }()

    private lazy var stackView: UIStackView = {
        let stackView = UIStackView()
        stackView.alignment = .center
        stackView.axis = .vertical
        stackView.spacing = 5
        return stackView
    }()

    private weak var addressLabel: UILabel?

    private lazy var tableView: TableView = {
        let tableView = TableView(frame: .zero, style: .plain)
        tableView.delegate = self
        tableView.dataSource = self
        tableView.registerClassCell(class: FileTableViewCell.self)
        tableView.registerClassCell(class: FolderProgressCell.self)
        tableView.allowsSelection = false
        tableView.estimatedRowHeight = 50
        tableView.rowHeight = UITableView.automaticDimension
        return tableView
    }()

    private weak var wifiIconImgView: UIImageView?

    private var items = [UploadItem]()

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)
        self.tableView.reloadData()
        self.setupUI()
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        UIApplication.shared.isIdleTimerDisabled = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        UIApplication.shared.isIdleTimerDisabled = false
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("WiFi传文件", comment: "")

        self.httpServer.start()

        let tipsLabel = Label()
        tipsLabel.text = NSLocalizedString(NSLocalizedString("上传过程中请勿离开此页或锁屏", comment: ""), comment: "")
        self.stackView.addArrangedSubview(tipsLabel)

        let wifiIconImgView = UIImageView()
        self.wifiIconImgView = wifiIconImgView
        self.stackView.addArrangedSubview(wifiIconImgView)

        let addressTipsLabel = Label()
        addressTipsLabel.text = NSLocalizedString("在电脑浏览器地址栏输入", comment: "")
        self.stackView.addArrangedSubview(addressTipsLabel)

        let addressLabel = Label()
        addressLabel.font = .ddp_large
        addressLabel.numberOfLines = 0
        addressLabel.textColor = .mainColor
        addressLabel.isUserInteractionEnabled = true
        addressLabel.addGestureRecognizer(UILongPressGestureRecognizer(actionBlock: { [weak self] ges in
            guard let self = self,
                  let ges = ges as? UILongPressGestureRecognizer else { return }

            if ges.state == .began {
                UIPasteboard.general.string = self.addressLabel?.text?.replacingOccurrences(of: "\n", with: "")
                self.view.showHUD(NSLocalizedString("复制成功~", comment: ""))
            }

        }))
        self.addressLabel = addressLabel
        self.stackView.addArrangedSubview(addressLabel)

        self.view.addSubview(self.stackView)
        self.view.addSubview(self.tableView)
        self.stackView.snp.makeConstraints { make in
            make.top.equalTo(self.view.safeAreaLayoutGuide.snp.top).offset(10)
            make.leading.trailing.equalToSuperview()
        }

        self.tableView.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
            make.top.equalTo(self.stackView.snp.bottom).offset(5)
            make.bottom.equalTo(self.view.safeAreaLayoutGuide.snp.bottom)
        }

        self.setupUI()
        self.resetAddress()
    }

    //MARK: Private Method
    private func resetAddress() {
        self.addressLabel?.text = "\n" + (self.httpServer.serverURL?.absoluteString ?? "") + "\n"
    }

    private func setupUI() {
        self.wifiIconImgView?.image = .init(named: "PickFile/wifi")?.byTintColor(.mainColor)
    }

}
