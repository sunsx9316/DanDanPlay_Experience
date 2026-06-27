//
//  RemoteLoginHistoryViewController.swift
//  AniXPlayer
//
//  tvOS 远程服务器登录历史基类
//

import UIKit

class RemoteLoginHistoryViewController: ViewController {

    // MARK: - Data (subclass overrides)

    var loginInfos: [LoginInfo] {
        get { return _loginInfos }
        set { _loginInfos = newValue }
    }

    private var _loginInfos: [LoginInfo] = []

    /// 连接成功后构造 rootFile（子类可覆盖区分 WebDAV rootPath）
    func rootFile(for loginInfo: LoginInfo) -> File {
        fatalError("subclass must override rootFile(for:)")
    }

    func displayName(for loginInfo: LoginInfo) -> String? {
        return loginInfo.auth?.userName
    }

    func displayAddress(for loginInfo: LoginInfo) -> String? {
        return loginInfo.url.absoluteString
    }

    /// 跳转到连接页（子类覆盖）
    func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        fatalError("subclass must override connectViewController(loginInfo:)")
    }

    // MARK: - UI

    private lazy var addBarItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewConnection))
    }()

    private(set) lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: FileListCell.self)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        return tv
    }()

    private lazy var emptyLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("暂无记录，点击右上角 ⊕ 添加", comment: "")
        label.font = .ddp_normal()
        label.textColor = .lightGray
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = fileManagerDesc

        navigationItem.rightBarButtonItems = [addBarItem]

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let longPress = UILongPressGestureRecognizer(target: self, action: #selector(handleLongPress(_:)))
        tableView.addGestureRecognizer(longPress)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        loadData()
        updateEmptyLabel()
    }

    /// 子类可覆盖以控制空状态显隐（SMB 需要同时检查网络邻居）
    var isEmpty: Bool {
        return loginInfos.isEmpty
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = isEmpty ? tableView : tableView
    }

    // MARK: - Subclass info

    var fileManagerDesc: String {
        fatalError("subclass must override fileManagerDesc")
    }

    private func loadData() {
        tableView.reloadData()
    }

    // MARK: - Actions

    @objc private func addNewConnection() {
        let vc = connectViewController(loginInfo: nil)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
    }

    func loginInfoForRow(at indexPath: IndexPath) -> LoginInfo? {
        guard indexPath.row < loginInfos.count else { return nil }
        return loginInfos[indexPath.row]
    }

    @objc private func handleLongPress(_ gesture: UILongPressGestureRecognizer) {
        guard gesture.state == .began else { return }

        let point = gesture.location(in: tableView)
        guard let indexPath = tableView.indexPathForRow(at: point) else { return }
        guard let info = loginInfoForRow(at: indexPath) else { return }
        let alert = UIAlertController(title: info.url.host ?? info.url.absoluteString, message: nil, preferredStyle: .alert)

        alert.addAction(UIAlertAction(title: NSLocalizedString("编辑", comment: ""), style: .default) { [weak self] _ in
            guard let self = self else { return }
            let vc = self.connectViewController(loginInfo: info)
            vc.delegate = self
            self.navigationController?.pushViewController(vc, animated: true)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("删除", comment: ""), style: .destructive) { [weak self] _ in
            self?.confirmDelete(info: info, at: indexPath)
        })

        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    private func confirmDelete(info: LoginInfo, at indexPath: IndexPath) {
        let alert = UIAlertController(
            title: NSLocalizedString("确认删除", comment: ""),
            message: NSLocalizedString("确定要删除该记录吗？", comment: ""),
            preferredStyle: .alert
        )
        alert.addAction(UIAlertAction(title: NSLocalizedString("删除", comment: ""), style: .destructive) { [weak self] _ in
            guard let self = self else { return }
            self.deleteHistory(at: indexPath.row)
            self.tableView.deleteRows(at: [indexPath], with: .automatic)
        })
        alert.addAction(UIAlertAction(title: NSLocalizedString("取消", comment: ""), style: .cancel))
        present(alert, animated: true)
    }

    func connect(with loginInfo: LoginInfo) {
        view.anx_showLoading(NSLocalizedString("连接中…", comment: ""))
        fileManager.connectWithLoginInfo(loginInfo) { [weak self] error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                self.view.anx_hideHUD()
                if let error = error {
                    self.view.anx_showError(error.localizedDescription)
                } else {
                    if let index = self.loginInfos.firstIndex(of: loginInfo) {
                        self.loginInfos.remove(at: index)
                    }
                    self.loginInfos.insert(loginInfo, at: 0)
                    self.saveData()

                    let rootFile = self.rootFile(for: loginInfo)
                    let browserVC = FileBrowserViewController(directory: rootFile)
                    browserVC.delegate = self
                    self.navigationController?.pushViewController(browserVC, animated: true)
                }
            }
        }
    }

    var fileManager: FileManagerProtocol {
        fatalError("subclass must override fileManager")
    }

    private func deleteHistory(at index: Int) {
        loginInfos.remove(at: index)
        saveData()
        updateEmptyLabel()
    }

    func updateEmptyLabel() {
        emptyLabel.isHidden = !isEmpty
    }

    /// 子类覆盖保存数据
    func saveData() {
        fatalError("subclass must override saveData()")
    }
}

// MARK: - UITableViewDataSource

extension RemoteLoginHistoryViewController: UITableViewDataSource {

    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return loginInfos.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueCell(class: FileListCell.self, indexPath: indexPath)
        let info = loginInfos[indexPath.row]

        let title = displayAddress(for: info) ?? ""
        let detail = displayName(for: info) ?? info.remark ?? ""

        cell.configureAsSource(title: title, iconName: "server.rack", detail: detail)
        return cell
    }
}

// MARK: - UITableViewDelegate

extension RemoteLoginHistoryViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let info = loginInfos[indexPath.row]
        connect(with: info)
    }
}

// MARK: - RemoteConnectViewControllerDelegate

extension RemoteLoginHistoryViewController: RemoteConnectViewControllerDelegate {

    func connectViewController(_ vc: RemoteConnectViewController, didSuccessConnect loginInfo: LoginInfo) {
        // 保存记录
        if let index = loginInfos.firstIndex(of: loginInfo) {
            loginInfos.remove(at: index)
        }
        loginInfos.insert(loginInfo, at: 0)
        saveData()

        // 跳转到文件浏览器
        let rootFile = self.rootFile(for: loginInfo)
        let browserVC = FileBrowserViewController(directory: rootFile)
        browserVC.delegate = self

        // 替换当前连接页面
        if var viewControllers = navigationController?.viewControllers {
            viewControllers.removeLast()
            viewControllers.append(browserVC)
            navigationController?.setViewControllers(viewControllers, animated: true)
        }
    }
}

// MARK: - FileBrowserViewControllerDelegate

extension RemoteLoginHistoryViewController: FileBrowserViewControllerDelegate {

    func fileBrowserViewController(_ vc: FileBrowserViewController, didSelectFile: File, allFiles: [File]) {
        let playerVC = PlayerViewController(items: allFiles, selectedItem: didSelectFile)
        present(playerVC, animated: true)
    }
}
