//
//  FileBrowserViewController.swift
//  AniXPlayer
//
//  tvOS 文件浏览 — TableView 文件列表 + 焦点导航
//

import UIKit
import SnapKit

class FileBrowserViewController: ViewController {

    /// 文件选择回调（非 nil 时为选择模式，点击文件会回调而不是播放）
    var didSelectFile: ((File) -> Void)?

    /// 文件过滤类型（nil = 不过滤）
    var filterType: URLFilterType? = .video

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
        tv.rowHeight = 80
        return tv
    }()

    private let rootDirectory: File
    private var currentDirectory: File?
    private var files: [File] = []
    private var isLoading = false

    init(directory: File) {
        self.rootDirectory = directory
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        let wifiButton = Button(type: .system)
        wifiButton.setImage(UIImage(systemName: "wifi"), for: .normal)
        wifiButton.setTitle(NSLocalizedString("WiFi传文件", comment: ""), for: .normal)
        wifiButton.addTarget(self, action: #selector(openWiFiTransfer), for: .primaryActionTriggered)

        self.view.addSubview(wifiButton)
        self.view.addSubview(tableView)

        wifiButton.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide.snp.top).offset(8)
            make.trailing.equalToSuperview().offset(-20)
        }

        tableView.snp.makeConstraints { make in
            make.top.equalTo(wifiButton.snp.bottom).offset(8)
            make.leading.trailing.bottom.equalToSuperview()
        }

        enterDirectory(rootDirectory)
    }

    @objc private func openWiFiTransfer() {
        let httpVC = HttpServerViewController()
        navigationController?.pushViewController(httpVC, animated: true)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        if let dir = currentDirectory {
            enterDirectory(dir)
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    // MARK: - Data

    private func enterDirectory(_ directory: File) {
        guard !isLoading else { return }
        isLoading = true

        let fileManager = type(of: directory).fileManager
        fileManager.contentsOfDirectory(at: directory, filterType: filterType) { [weak self] result in
            guard let self = self else { return }
            self.isLoading = false

            switch result {
            case .success(let files):
                self.currentDirectory = directory
                self.files = files
                DispatchQueue.main.async {
                    self.title = directory.fileName
                    self.tableView.reloadData()
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.showError(error)
                }
            }
        }
    }

    private func goBack() {
        if isAtRoot {
            navigationController?.popViewController(animated: true)
        } else if let parent = currentDirectory?.parentFile {
            enterDirectory(parent)
        }
    }

    private func selectFile(_ file: File) {
        if let didSelectFile = didSelectFile {
            didSelectFile(file)
        } else {
            let playerVC = PlayerViewController()
            playerVC.file = file
            self.present(playerVC, animated: true)
        }
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("错误", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        self.present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension FileBrowserViewController: UITableViewDataSource {

    private var isAtRoot: Bool {
        return currentDirectory?.url.standardizedFileURL == rootDirectory.url.standardizedFileURL
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return section == 0 ? 1 : files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell

        if indexPath.section == 0 {
            let backTitle = isAtRoot
                ? NSLocalizedString("媒体库", comment: "")
                : NSLocalizedString("返回上一页", comment: "")
            cell.configureAsSource(title: backTitle, iconName: "arrow.uturn.backward")
        } else {
            let file = files[indexPath.row]
            cell.configure(with: file)
        }

        return cell
    }
}

// MARK: - UITableViewDelegate

extension FileBrowserViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == 0 {
            goBack()
        } else {
            let file = files[indexPath.row]
            if file.type == .folder {
                enterDirectory(file)
            } else {
                selectFile(file)
            }
        }
    }
}
