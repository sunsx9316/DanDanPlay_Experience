//
//  FilterDanmakuViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/9/17.
//

import AppKit
import RxSwift
import SnapKit

extension FilterDanmakuViewController: NSTableViewDelegate, NSTableViewDataSource {

    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.dataSource.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let model = self.dataSource[row]

        let cell = tableView.dequeueReusableCell(class: FilterDanmakuTableViewCell.self)
        cell.textField.text = model.text
        cell.enableCheckBox.isOn = model.isEnable
        cell.regexCheckBox.state = model.isRegularExp ? .on : .off

        cell.onClickRegexCallBack = { [weak self] aCell in
            guard let self = self else { return }
            self.modifyFilter(at: tableView.row(for: aCell)) { model in
                model.isRegularExp = aCell.regexCheckBox.state == .on
            }
        }

        cell.onClickEnableCallBack = { [weak self] aCell in
            guard let self = self else { return }
            self.modifyFilter(at: tableView.row(for: aCell)) { model in
                model.isEnable = aCell.enableCheckBox.state == .on
            }
        }

        cell.onEndEditingCallBack = { [weak self] aCell in
            guard let self = self else { return }
            let text = aCell.textField.text
            let row = tableView.row(for: aCell)
            self.modifyFilter(at: row) { model in
                model.text = text
            }
        }

        cell.onClickDeleteCallBack = { [weak self] aCell in
            guard let self = self else { return }
            let row = tableView.row(for: aCell)
            guard row >= 0, row < self.dataSource.count else { return }
            let model = self.dataSource[row]
            self.danmakuModel.onRemoveFilterDanmkus(model)
        }

        return cell
    }

    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat {
        return 38
    }

    func tableView(_ tableView: NSTableView, rowViewForRow row: Int) -> NSTableRowView? {
        return tableView.themedRowView(forRow: row)
    }
}

class FilterDanmakuViewController: ViewController {

    private var dataSource: [FilterDanmaku] {
        return self.danmakuModel.filterDanmakus ?? []
    }

    private let danmakuModel: PlayerDanmakuModel!

    private lazy var bag = DisposeBag()

    init(danmakuModel: PlayerDanmakuModel) {
        self.danmakuModel = danmakuModel
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 400, height: 500))
    }

    private lazy var scrollView: ScrollView<TableView> = {
        let tableView = TableView()
        tableView.delegate = self
        tableView.dataSource = self
        tableView.headerView = nil
        tableView.rowSizeStyle = .custom
        tableView.registerClassCell(class: FilterDanmakuTableViewCell.self)
        tableView.enableRowHoverTracking()

        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier(rawValue: ""))
        column.isEditable = false
        tableView.addTableColumn(column)

        let scrollView = ScrollView(containerView: tableView)
        return scrollView
    }()

    private lazy var addTextField: TextField = {
        let field = TextField()
        field.placeholderString = NSLocalizedString("输入屏蔽词后回车添加", comment: "")
        field.font = .ddp_normal
        field.isBordered = true
        field.addTarget(self, action: #selector(onClickAdd(_:)))
        return field
    }()

    private lazy var addButton: Button = {
        let button = Button(title: NSLocalizedString("添加", comment: ""), target: self, action: #selector(onClickAdd(_:)))
        return button
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        self.title = NSLocalizedString("弹幕屏蔽", comment: "")

        let bottomBar = NSView()
        self.view.addSubview(self.scrollView)
        self.view.addSubview(bottomBar)
        bottomBar.addSubview(addTextField)
        bottomBar.addSubview(addButton)

        self.scrollView.snp.makeConstraints { make in
            make.leading.top.trailing.equalToSuperview()
        }

        bottomBar.snp.makeConstraints { make in
            make.leading.bottom.trailing.equalToSuperview()
            make.top.equalTo(self.scrollView.snp.bottom)
            make.height.equalTo(40)
        }

        addTextField.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(10)
            make.centerY.equalToSuperview()
        }

        addButton.snp.makeConstraints { make in
            make.leading.equalTo(addTextField.snp.trailing).offset(10)
            make.trailing.equalToSuperview().offset(-10)
            make.centerY.equalToSuperview()
            make.width.equalTo(60)
        }

        self.danmakuModel.context.filterDanmakus.subscribe(onNext: { [weak self] _ in
            self?.scrollView.containerView.reloadData()
        }).disposed(by: self.bag)
    }

    // MARK: Private

    private func modifyFilter(at row: Int, block: (inout FilterDanmaku) -> Void) {
        guard row >= 0, row < self.dataSource.count else { return }
        var newDataSource = self.dataSource
        var model = newDataSource[row]
        block(&model)
        newDataSource[row] = model
        self.danmakuModel.onChangeFilterDanmkus(newDataSource)
    }

    @objc private func onClickAdd(_ sender: Any) {
        let text = (addTextField.text ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }

        self.danmakuModel.onAddFilterDanmku(text)
        addTextField.text = ""
    }
}
