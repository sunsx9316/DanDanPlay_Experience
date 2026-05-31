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

    /// 跳转到连接页（子类覆盖）
    func connectViewController(loginInfo: LoginInfo?) -> RemoteConnectViewController {
        fatalError("subclass must override connectViewController(loginInfo:)")
    }

    // MARK: - UI

    private lazy var addBarItem: UIBarButtonItem = {
        return UIBarButtonItem(barButtonSystemItem: .add, target: self, action: #selector(addNewConnection))
    }()

    private lazy var editBarItem: UIBarButtonItem = {
        return UIBarButtonItem(title: NSLocalizedString("编辑", comment: ""), style: .plain, target: self, action: #selector(toggleEdit))
    }()

    private(set) lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(FileListCell.self, forCellReuseIdentifier: FileListCell.reuseIdentifier)
        tv.rowHeight = 80
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

        navigationItem.rightBarButtonItems = [addBarItem, editBarItem]

        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        view.addSubview(emptyLabel)
        emptyLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }
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

    @objc private func toggleEdit() {
        let editing = !tableView.isEditing
        tableView.setEditing(editing, animated: true)
        editBarItem.title = editing ? NSLocalizedString("完成", comment: "") : NSLocalizedString("编辑", comment: "")
    }

    func connect(with loginInfo: LoginInfo) {
        let vc = connectViewController(loginInfo: loginInfo)
        vc.delegate = self
        navigationController?.pushViewController(vc, animated: true)
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
        let cell = tableView.dequeueReusableCell(withIdentifier: FileListCell.reuseIdentifier, for: indexPath) as! FileListCell
        let info = loginInfos[indexPath.row]

        let title = info.url.host ?? info.url.absoluteString
        let detail = info.remark ?? info.auth?.userName ?? ""

        cell.configureAsSource(title: title, iconName: "server.rack", detail: detail)
        return cell
    }

    func tableView(_ tableView: UITableView, canEditRowAt indexPath: IndexPath) -> Bool {
        return true
    }

    func tableView(_ tableView: UITableView, commit editingStyle: UITableViewCell.EditingStyle, forRowAt indexPath: IndexPath) {
        if editingStyle == .delete {
            deleteHistory(at: indexPath.row)
            tableView.deleteRows(at: [indexPath], with: .automatic)
        }
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
