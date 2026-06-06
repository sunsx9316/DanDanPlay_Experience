//
//  SearchViewController.swift
//  AniXPlayer
//
//  tvOS 搜索 — 先展示搜索结果列表，点击进入番剧详情查看分集
//

import UIKit
import SnapKit

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: MatchInfo)
}

class SearchViewController: ViewController {

    weak var delegate: SearchViewControllerDelegate?

    private var dataSource: [MediaMatchItem] = []

    // MARK: - Search Bar

    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = NSLocalizedString("输入关键词搜索番剧", comment: "")
        tf.borderStyle = .roundedRect
        tf.returnKeyType = .search
        tf.autocapitalizationType = .none
        return tf
    }()

    // MARK: - Results

    private lazy var resultTableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.registerClassCell(class: SearchAnimeCell.self)
        tv.registerClassCell(class: SearchEpisodeCell.self)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 80
        return tv
    }()

    private let emptyLabel: Label = {
        let label = Label()
        label.textColor = .secondaryLabel
        label.font = .ddp_small()
        label.textAlignment = .center
        label.isHidden = true
        return label
    }()

    // MARK: - Init

    private init(with items: [MediaMatchItem]) {
        self.dataSource = items
        super.init(nibName: nil, bundle: nil)
    }

    convenience init() {
        self.init(with: [])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("搜索", comment: "")

        view.addSubview(searchTextField)
        view.addSubview(resultTableView)
        view.addSubview(emptyLabel)

        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(16)
            make.leading.trailing.equalToSuperview().inset(60)
        }

        resultTableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(16)
            make.bottom.equalToSuperview()
            make.leading.trailing.equalToSuperview().inset(40)
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(resultTableView)
        }

        searchTextField.delegate = self

        searchTextField.isHidden = !dataSource.isEmpty
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = searchTextField.isHidden ? resultTableView : searchTextField
    }

    // MARK: - Private

    private func performSearch(keyword: String) {
        guard !keyword.isEmpty else { return }

        SearchNetworkHandle.searchWithKeyword(keyword) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.dataSource = result.collection
                    self.resultTableView.reloadData()
                    self.emptyLabel.isHidden = !self.dataSource.isEmpty
                    if self.dataSource.isEmpty {
                        self.emptyLabel.text = NSLocalizedString("未找到相关番剧", comment: "")
                    }
                } else {
                    self.emptyLabel.text = NSLocalizedString("搜索失败，请重试", comment: "")
                    self.emptyLabel.isHidden = false
                }
            }
        }
    }
}

// MARK: - UITextFieldDelegate

extension SearchViewController: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        guard let keyword = textField.text, !keyword.isEmpty else { return false }
        textField.resignFirstResponder()
        performSearch(keyword: keyword)
        return true
    }
}

// MARK: - UITableViewDataSource

extension SearchViewController: UITableViewDataSource {

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return dataSource.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let item = dataSource[indexPath.row]
        let hasSubItems = item.items?.isEmpty == false

        if hasSubItems {
            let cell = tableView.dequeueCell(class: SearchAnimeCell.self, indexPath: indexPath)
            cell.configure(with: item)
            return cell
        } else {
            let cell = tableView.dequeueCell(class: SearchEpisodeCell.self, indexPath: indexPath)
            cell.configure(with: item)
            return cell
        }
    }
}

// MARK: - UITableViewDelegate

extension SearchViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dataSource[indexPath.row]

        if let items = item.items, !items.isEmpty {
            let vc = SearchViewController(with: items)
            vc.title = item.title
            vc.delegate = self.delegate
            self.navigationController?.pushViewController(vc, animated: true)
        } else if (item.episodeId ?? 0) > 0 {
            self.delegate?.searchViewController(self, didMatched: item)
        }
    }
}

// MARK: - SearchViewControllerDelegate

extension SearchViewController: SearchViewControllerDelegate {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: MatchInfo) {
        self.delegate?.searchViewController(self, didMatched: matchInfo)
    }
}