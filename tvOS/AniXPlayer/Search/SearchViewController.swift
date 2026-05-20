//
//  SearchViewController.swift
//  AniXPlayer
//
//  tvOS 搜索 — TextField + TableView 焦点导航
//  注：tvOS 无 UISearchController，使用自定义搜索 UI
//

import UIKit
import SnapKit

class SearchViewController: ViewController {

    private var searchResults: [SearchCollection] = []

    private let searchTextField: UITextField = {
        let tf = UITextField()
        tf.placeholder = NSLocalizedString("输入关键词搜索番剧", comment: "")
        tf.borderStyle = .roundedRect
        tf.backgroundColor = UIColor.white.withAlphaComponent(0.1)
        tf.textColor = .white
        tf.font = .systemFont(ofSize: 20)
        tf.returnKeyType = .search
        return tf
    }()

    private lazy var resultTableView: TableView = {
        let tv = TableView(frame: .zero, style: .plain)
        tv.delegate = self
        tv.dataSource = self
        tv.register(SearchResultCell.self, forCellReuseIdentifier: SearchResultCell.reuseIdentifier)
        tv.rowHeight = 90
        return tv
    }()

    private let emptyLabel: Label = {
        let label = Label()
        label.text = NSLocalizedString("输入关键词搜索番剧", comment: "")
        label.textColor = .lightGray
        label.font = .systemFont(ofSize: 20)
        label.textAlignment = .center
        return label
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("搜索", comment: "")

        self.view.addSubview(searchTextField)
        self.view.addSubview(resultTableView)
        self.view.addSubview(emptyLabel)

        searchTextField.snp.makeConstraints { make in
            make.top.equalTo(view.safeAreaLayoutGuide).offset(20)
            make.leading.trailing.equalToSuperview().inset(60)
            make.height.equalTo(50)
        }

        resultTableView.snp.makeConstraints { make in
            make.top.equalTo(searchTextField.snp.bottom).offset(20)
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
}

// MARK: - UITableViewDelegate

extension SearchViewController: UITableViewDelegate {

    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let anime = searchResults[indexPath.section]
        let episode = anime.collection[indexPath.row]
        let detailVC = BangumiDetailViewController(animateId: anime.animeId)
        self.navigationController?.pushViewController(detailVC, animated: true)
    }

    func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        if let header = view as? UITableViewHeaderFooterView {
            header.textLabel?.textColor = .white
            header.textLabel?.font = .systemFont(ofSize: 18, weight: .bold)
        }
    }
}
