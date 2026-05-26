//
//  FileBrowserViewController.swift
//  AniXPlayer
//
//  tvOS 文件浏览基类 — 提供目录导航、文件列表、代理回调
//

import UIKit
import SnapKit

// MARK: - Delegate

protocol FileBrowserViewControllerDelegate: AnyObject {
    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File])
}

// MARK: - FileBrowserViewController

class FileBrowserViewController: ViewController, FileBrowserViewControllerDelegate {

    weak var delegate: FileBrowserViewControllerDelegate?

    /// 文件过滤类型（nil = 不过滤）
    var filterType: URLFilterType? = .video

    // MARK: - UI

    private(set) lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
        tv.rowHeight = 80
        return tv
    }()

    // MARK: - Data

    private let rootDirectory: File
    private var currentDirectory: File?
    private(set) var files: [File] = []
    private var isLoading = false

    // MARK: - Init

    init(directory: File) {
        self.rootDirectory = directory
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()

        let backImage = UIImage(systemName: "chevron.backward", withConfiguration: UIImage.SymbolConfiguration(pointSize: 28, weight: .medium))
        let backItem = UIBarButtonItem(image: backImage, style: .plain, target: self, action: #selector(goBack))
        navigationItem.leftBarButtonItem = backItem

        self.view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
        }

        enterDirectory(rootDirectory)
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

    @objc private func goBack() {
        if isAtRoot {
            navigationController?.popViewController(animated: true)
        } else if let parent = currentDirectory?.parentFile {
            enterDirectory(parent)
        }
    }

    func selectFile(_ file: File) {
        delegate?.fileBrowserViewController(self, didSelectFile: file, allFiles: files)
    }

    private func showError(_ error: Error) {
        let alert = UIAlertController(title: NSLocalizedString("错误", comment: ""), message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: NSLocalizedString("确定", comment: ""), style: .default))
        self.present(alert, animated: true)
    }

    // MARK: - FileBrowserViewControllerDelegate

    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        delegate?.fileBrowserViewController(vc, didSelectFile: didSelectFile, allFiles: allFiles)
    }
}

// MARK: - UITableViewDataSource

extension FileBrowserViewController: UITableViewDataSource {

    private var isAtRoot: Bool {
        return currentDirectory?.url.standardizedFileURL == rootDirectory.url.standardizedFileURL
    }

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return files.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell
        let file = files[indexPath.row]
        cell.configure(with: file)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension FileBrowserViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let file = files[indexPath.row]
        if file.type == .folder {
            let vc = FileBrowserViewController(directory: file)
            vc.filterType = filterType
            vc.delegate = self
            navigationController?.pushViewController(vc, animated: true)
        } else {
            selectFile(file)
        }
    }
}
