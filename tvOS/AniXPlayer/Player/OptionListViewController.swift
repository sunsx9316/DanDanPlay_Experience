//
//  OptionListViewController.swift
//  AniXPlayer
//
//  tvOS 通用选项选择器 — TableView 列表 + 选中标记，基于索引回调
//

import UIKit
import SnapKit

class OptionListViewController: ViewController {

    struct Option {
        let title: String
        let subtitle: String?

        init(title: String, subtitle: String? = nil) {
            self.title = title
            self.subtitle = subtitle
        }
    }

    /// 回调选中的索引
    var onSelect: ((Int) -> Void)?

    private let options: [Option]
    private var selectedIndex: Int
    private var blurView: UIVisualEffectView!

    private lazy var tableView: TableView = {
        let tv = TableView(frame: .zero, style: .grouped)
        tv.delegate = self
        tv.dataSource = self
        tv.register(TableViewCell.self, forCellReuseIdentifier: "OptionCell")
        tv.rowHeight = 66
        return tv
    }()

    init(title: String, options: [Option], selectedIndex: Int) {
        self.options = options
        self.selectedIndex = selectedIndex
        super.init(nibName: nil, bundle: nil)
        self.title = title
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        blurView = UIVisualEffectView(effect: adaptiveBlurEffect())
        view.insertSubview(blurView, at: 0)
        blurView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        tableView.backgroundColor = .clear
        view.addSubview(tableView)
        tableView.snp.makeConstraints { make in
            make.top.trailing.bottom.equalToSuperview()
            make.leading.equalToSuperview().offset(40)
        }

        registerForTraitChanges([UITraitUserInterfaceStyle.self]) { [weak self] (_: Self, _: UITraitCollection) in
            guard let self = self else { return }
            self.blurView.effect = self.adaptiveBlurEffect()
        }
    }

    private func adaptiveBlurEffect() -> UIBlurEffect {
        return UIBlurEffect(style: traitCollection.userInterfaceStyle == .dark ? .dark : .light)
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = tableView
    }
}

extension OptionListViewController: UITableViewDataSource {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return options.count
    }

    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "OptionCell", for: indexPath)
        let option = options[indexPath.row]
        cell.textLabel?.text = option.title
        cell.textLabel?.font = .ddp_small()
        cell.textLabel?.textColor = .label
        cell.accessoryType = indexPath.row == selectedIndex ? .checkmark : .none
        cell.selectionStyle = .none
        return cell
    }
}

extension OptionListViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        tableView.deselectRow(at: indexPath, animated: true)
        selectedIndex = indexPath.row
        onSelect?(indexPath.row)
        tableView.reloadData()
    }
}
