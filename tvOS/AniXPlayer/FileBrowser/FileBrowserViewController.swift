//
//  FileBrowserViewController.swift
//  AniXPlayer
//
//  tvOS 文件浏览 — TableView 文件列表 + 焦点导航
//

import UIKit
import SnapKit

class FileBrowserViewController: ViewController {

    private enum FileSource: Int, CaseIterable {
        case local

        var title: String {
            switch self {
            case .local: return NSLocalizedString("本机", comment: "")
            }
        }

        var iconName: String {
            switch self {
            case .local: return "internaldrive"
            }
        }

        var fileManager: FileManagerProtocol {
            switch self {
            case .local: return LocalFileManager.shared
            }
        }
    }

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
        tv.rowHeight = 80
        return tv
    }()

    private var currentDirectory: File?
    private var files: [File] = []
    private var isLoading = false

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("文件浏览", comment: "")

        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = tableView
    }

    // MARK: - Data

    private func loadSourceFiles() {
        files = []
        tableView.reloadData()
    }

    private func enterDirectory(_ directory: File) {
        guard !isLoading else { return }
        isLoading = true

        let fileManager = type(of: directory).fileManager
        fileManager.contentsOfDirectory(at: directory, filterType: .video) { [weak self] result in
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
        if let parent = currentDirectory?.parentFile {
            enterDirectory(parent)
        } else {
            currentDirectory = nil
            files = []
            self.title = NSLocalizedString("文件浏览", comment: "")
            tableView.reloadData()
        }
    }

    private func playFile(_ file: File) {
        let playerVC = PlayerViewController()
        playerVC.file = file
        self.present(playerVC, animated: true)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("错误", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        self.present(alert, animated: true)
    }
}

// MARK: - UITableViewDataSource

extension FileBrowserViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if currentDirectory == nil {
            return FileSource.allCases.count
        }
        return files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell

        if currentDirectory == nil {
            let source = FileSource(rawValue: indexPath.row)!
            cell.configureAsSource(title: source.title, iconName: source.iconName)
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
        if currentDirectory == nil {
            let source = FileSource(rawValue: indexPath.row)!
            switch source {
            case .local:
                enterDirectory(LocalFile.rootFile)
            }
        } else {
            let file = files[indexPath.row]
            if file.type == .folder {
                enterDirectory(file)
            } else {
                playFile(file)
            }
        }
    }
}
