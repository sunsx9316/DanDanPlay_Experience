//
//  SearchViewController.swift
//  AniXPlayer
//
//  tvOS 搜索 — 自定义搜索栏 + TableView 展示结果
//

import UIKit
import SnapKit

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ searchViewController: SearchViewController, didMatched matchInfo: MatchInfo)
}

class SearchViewController: ViewController {

    weak var delegate: SearchViewControllerDelegate?

    private var searchResults: [SearchCollection] = []

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
        tv.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseIdentifier)
        tv.rowHeight = UITableView.automaticDimension
        tv.estimatedRowHeight = 60
        return tv
    }()

    private let emptyLabel: Label = {
        let label = Label()
        label.text = NSLocalizedString("输入关键词搜索番剧", comment: "")
        label.textColor = .secondaryLabel
        label.font = .systemFont(ofSize: 16)
        label.textAlignment = .center
        return label
    }()

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
            make.leading.trailing.bottom.equalToSuperview()
        }

        emptyLabel.snp.makeConstraints { make in
            make.center.equalTo(resultTableView)
        }

        searchTextField.delegate = self
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.defaultFocusView = searchTextField
    }

    private func performSearch(keyword: String) {
        guard !keyword.isEmpty else { return }

        SearchNetworkHandle.searchWithKeyword(keyword) { [weak self] result, error in
            guard let self = self else { return }
            DispatchQueue.main.async {
                if let result = result {
                    self.searchResults = result.collection
                    self.resultTableView.reloadData()
                    self.emptyLabel.isHidden = !self.searchResults.isEmpty
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

    func numberOfSections(in tableView: UITableView) -> Int {
        return searchResults.count
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return searchResults[section].collection.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: SearchResultCell.reuseIdentifier, for: indexPath) as! SearchResultCell
        let anime = searchResults[indexPath.section]
        let episode = anime.collection[indexPath.row]
        cell.configure(with: episode)
        return cell
    }

    func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        return searchResults[section].animeTitle
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .label
            header.textLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        }
    }
}

// MARK: - UITableViewDelegate

extension SearchViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let anime = searchResults[indexPath.section]
        let episode = anime.collection[indexPath.row]

        if let delegate = self.delegate {
            delegate.searchViewController(self, didMatched: episode)
        } else {
            let detailVC = BangumiDetailViewController(animateId: anime.animeId)
            self.navigationController?.pushViewController(detailVC, animated: true)
        }
    }
}
