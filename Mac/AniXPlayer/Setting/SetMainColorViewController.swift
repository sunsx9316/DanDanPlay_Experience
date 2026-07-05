//
//  SetMainColorViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2026/6/3.
//

import Cocoa
import SnapKit

class SetMainColorViewController: ViewController {

    private let model: GlobalSettingModel

    private var selectedColor: NSColor

    private lazy var colorWell: NSColorWell = {
        let cw = NSColorWell()
        cw.color = selectedColor
        cw.addTarget(self, action: #selector(onColorWellChange(_:)))
        return cw
    }()

    private lazy var resetButton: Button = {
        let btn = Button(title: NSLocalizedString("恢复默认", comment: ""), target: self, action: #selector(onTouchReset(_:)))
        btn.bezelStyle = .inline
        return btn
    }()

    private lazy var saveButton: Button = {
        let btn = Button(title: NSLocalizedString("保存", comment: ""), target: self, action: #selector(onTouchSave(_:)))
        btn.bezelStyle = .rounded
        btn.keyEquivalent = "\r"
        return btn
    }()

    init(globalSettingModel: GlobalSettingModel) {
        self.model = globalSettingModel
        self.selectedColor = model.mainColor ?? .defaultMainColor
        super.init()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 340, height: 120))
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        title = NSLocalizedString("设置主题色", comment: "")

        let buttonRow = NSStackView(views: [resetButton, NSView(), saveButton])
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.distribution = .fill

        let stack = NSStackView(views: [colorWell, buttonRow])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 16
        stack.edgeInsets = NSEdgeInsets(top: 20, left: 20, bottom: 20, right: 20)

        view.addSubview(stack)
        stack.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }

        saveButton.snp.makeConstraints { make in
            make.width.equalTo(80)
            make.height.equalTo(28)
        }
    }

    // MARK: - Actions

    @objc private func onColorWellChange(_ sender: NSColorWell) {
        selectedColor = sender.color
    }

    @objc private func onTouchReset(_ sender: NSButton) {
        selectedColor = .defaultMainColor
        colorWell.color = selectedColor
    }

    @objc private func onTouchSave(_ sender: NSButton) {
        let alert = NSAlert()
        alert.messageText = NSLocalizedString("提示", comment: "")
        alert.informativeText = NSLocalizedString("保存需要退出App，是否退出？", comment: "")
        alert.alertStyle = .warning
        alert.addButton(withTitle: NSLocalizedString("确定", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))

        guard let window = view.window else { return }

        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self else { return }
            if response == .alertFirstButtonReturn {
                self.model.onChangeMainColor(self.selectedColor)
                NSApp.terminate(nil)
            }
        }
    }
}
