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

    /// 需要高亮的文件（用于播放列表自动定位当前播放视频）
    var highlightedFile: File?

    // MARK: - UI

    private(set) lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.remembersLastFocusedIndexPath = false
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: FileListCell.self)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
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

        let symbolConfig = UIImage.SymbolConfiguration(pointSize: 28, weight: .medium)
        let backImage = UIImage(systemName: "chevron.backward", withConfiguration: symbolConfig)
        let backItem = UIBarButtonItem(image: backImage, style: .plain, target: self, action: #selector(goBack))
        navigationItem.leftBarButtonItem = backItem

        let sortImage = UIImage(systemName: "arrow.up.arrow.down", withConfiguration: symbolConfig)
        let sortItem = UIBarButtonItem(image: sortImage, style: .plain, target: self, action: #selector(showSortOptions))
        navigationItem.rightBarButtonItem = sortItem

        // 长按"选择/回车"键触发删除菜单
        let longPressRecognizer = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPressSelect))
        longPressRecognizer.allowedPressTypes = [NSNumber(value: UIPress.PressType.select.rawValue)]
        view.addGestureRecognizer(longPressRecognizer)

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

    override var preferredFocusEnvironments: [UIFocusEnvironment] {
        // 数据加载后，将焦点定位到第一个 cell，让按上能自然离开 tableView 到 nav bar
        if !files.isEmpty, let firstCell = tableView.visibleCells.first {
            return [firstCell]
        }
        if let view = defaultFocusView {
            return [view]
        }
        return super.preferredFocusEnvironments
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
                let option = Preferences.shared.fileBrowserSortOption
                let ascending = Preferences.shared.fileBrowserSortAscending
                self.files = files.sorted { $0.sortCompare(to: $1, option: option, ascending: ascending) }
                DispatchQueue.main.async {
                    self.title = directory.fileName
                    self.tableView.reloadData()
                    self.scrollToHighlightedFile()
                    // 数据加载完成后刷新焦点，让引擎从 tableView 定位到具体 cell
                    self.setNeedsFocusUpdate()
                    self.updateFocusIfNeeded()
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

    @objc private func showSortOptions() {
        let alert = UIAlertController(title: NSLocalizedString("排序方式", comment: ""), message: nil, preferredStyle: .alert)

        let isEmby = rootDirectory is EmbyFile
        let options: [FileSortOption] = isEmby ? FileSortOption.allCases : [.default, .fileName, .fileType]
        let currentOption = Preferences.shared.fileBrowserSortOption
        let isAscending = Preferences.shared.fileBrowserSortAscending

        for option in options {
            let marker = option == currentOption ? (isAscending ? " ↑" : " ↓") : ""
            alert.addAction(UIAlertAction(title: option.displayName + marker, style: .default) { [weak self] _ in
                guard let self = self else { return }
                if option == currentOption {
                    Preferences.shared.fileBrowserSortAscending.toggle()
                } else {
                    Preferences.shared.fileBrowserSortOption = option
                }
                if let dir = self.currentDirectory {
                    self.enterDirectory(dir)
                }
            })
        }

        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    func selectFile(_ file: File) {
        delegate?.fileBrowserViewController(self, didSelectFile: file, allFiles: files)
    }

    private func scrollToHighlightedFile() {
        guard let highlightedFile = highlightedFile else { return }
        if let index = files.firstIndex(where: { $0.url == highlightedFile.url }) {
            let indexPath = IndexPath(row: index, section: 0)
            tableView.scrollToRow(at: indexPath, at: .middle, animated: false)
        }
    }

    // MARK: - Delete

    @objc private func handleLongPressSelect(_ recognizer: UILongPressGestureRecognizer) {
        guard recognizer.state == .began else { return }
        // 找到当前焦点所在的 cell
        guard let focusedCell = UIScreen.main.focusedView as? FileListCell,
              let indexPath = tableView.indexPath(for: focusedCell),
              indexPath.row < files.count else { return }

        let file = files[indexPath.row]
        guard file.isCanDelete else { return }

        let confirmAlert = UIAlertController(
            title: NSLocalizedString("删除", comment: ""),
            message: file.type == .folder
                ? NSLocalizedString("确定要删除此文件夹吗？", comment: "")
                : NSLocalizedString("确定要删除此文件吗？", comment: ""),
            preferredStyle: .alert
        )

        confirmAlert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        confirmAlert.addAction(UIAlertAction(title: NSLocalizedString("删除", comment: ""), style: .destructive) { [weak self] _ in
            self?.delete(file: file)
        })

        present(confirmAlert, animated: true)
    }

    private func delete(file: File) {
        let hud = view.showLoading()
        type(of: file).fileManager.deleteFile(file) { [weak self] error in
            DispatchQueue.main.async {
                hud.hide(animated: true)
                guard let self = self else { return }

                if let error = error {
                    self.view.showError(error)
                } else if let dir = self.currentDirectory {
                    self.enterDirectory(dir)
                }
            }
        }
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
        let cell = tableView.dequeueCell(class: FileListCell.self, indexPath: indexPath)
        let file = files[indexPath.row]
        cell.configure(with: file)
        if let highlightedFile = highlightedFile, file.url == highlightedFile.url {
            cell.configureAsHighlighted()
        }
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
