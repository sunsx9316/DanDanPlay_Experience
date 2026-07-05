//
//  SendDanmakuViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/10.
//

import Cocoa
import SnapKit

class SendDanmakuViewController: ViewController {

    private static let maxColorCount = 10
    private static let colorItemSize = CGSize(width: 26, height: 20)
    private static let colorWrapperSize = CGSize(width: 30, height: 26)

    // MARK: - Callbacks

    var onColorChanged: ((ANXColor) -> Void)?
    var onModeChanged: ((Comment.Mode) -> Void)?

    // MARK: - State

    private var selectedColor: ANXColor
    private var selectedMode: Comment.Mode
    private var selectedPresetIndex: Int = 0
    private var colors: [ANXColor]

    private var colorItemViews: [NSView] = []
    private var editingColorIndex: Int?

    // MARK: - UI

    private lazy var colorLabel: Label = {
        let label = Label()
        label.stringValue = NSLocalizedString("弹幕颜色", comment: "")
        label.font = .ddp_small(weight: .medium)
        return label
    }()

    private lazy var colorStackView: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .horizontal
        stack.spacing = 6
        stack.distribution = .fill
        return stack
    }()

    private lazy var modeLabel: Label = {
        let label = Label()
        label.stringValue = NSLocalizedString("弹幕模式", comment: "")
        label.font = .ddp_small(weight: .medium)
        return label
    }()

    private lazy var modePopup: PopUpButton = {
        let button = PopUpButton()
        for mode in Comment.Mode.allCases {
            button.addItem(withTitle: mode.name)
        }
        if let idx = Comment.Mode.allCases.firstIndex(where: { $0 == selectedMode }) {
            button.selectItem(at: idx)
        }
        button.target = self
        button.action = #selector(modeChanged(_:))
        return button
    }()

    private lazy var resetColorButton: Button = {
        let button = Button(title: NSLocalizedString("恢复默认颜色", comment: ""), target: self, action: #selector(resetColorsClicked))
        button.font = .ddp_small(weight: .regular)
        return button
    }()

    // MARK: - Init

    init(color: ANXColor, mode: Comment.Mode) {
        self.selectedColor = color
        self.selectedMode = mode
        self.colors = Preferences.shared.sendDanmakuColors
        super.init()
        findSelectedPresetIndex()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    deinit {
        NSColorPanel.shared.setTarget(nil)
        NSColorPanel.shared.setAction(nil)
        NSColorPanel.shared.close()
    }

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
                preferredContentSize = NSSize(width: 300, height: 160)
        setupUI()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(colorPanelWillClose(_:)),
            name: NSWindow.willCloseNotification,
            object: NSColorPanel.shared
        )
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(colorLabel)
        view.addSubview(colorStackView)
        view.addSubview(modeLabel)
        view.addSubview(modePopup)
        view.addSubview(resetColorButton)

        colorLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(10)
            make.leading.equalToSuperview().offset(10)
        }

        colorStackView.snp.makeConstraints { make in
            make.top.equalTo(colorLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(10)
            make.trailing.lessThanOrEqualToSuperview().offset(-10)
        }

        modeLabel.snp.makeConstraints { make in
            make.top.equalTo(colorStackView.snp.bottom).offset(8)
            make.leading.equalToSuperview().offset(10)
        }

        modePopup.snp.makeConstraints { make in
            make.top.equalTo(modeLabel.snp.bottom).offset(4)
            make.leading.equalToSuperview().offset(10)
        }

        resetColorButton.snp.makeConstraints { make in
            make.top.equalTo(modePopup.snp.bottom).offset(6)
            make.leading.equalToSuperview().offset(10)
            make.bottom.equalToSuperview().offset(-10)
        }

        rebuildColorButtons()
    }

    private func rebuildColorButtons() {
        colorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        colorItemViews.removeAll()

        for (index, color) in colors.enumerated() {
            let itemView = makeColorItemView(color: color, index: index)
            colorStackView.addArrangedSubview(itemView)
            colorItemViews.append(itemView)
        }

        if colors.count < Self.maxColorCount {
            let addView = makeAddColorView()
            colorStackView.addArrangedSubview(addView)
            colorItemViews.append(addView)
        }

        if selectedPresetIndex >= colors.count {
            selectedPresetIndex = 0
            if let first = colors.first {
                selectedColor = first
            }
        }
        updateSelectionHighlight()
    }

    private func findSelectedPresetIndex() {
        for (index, color) in colors.enumerated() {
            if color.anxRgbValue == selectedColor.anxRgbValue {
                selectedPresetIndex = index
                return
            }
        }
        selectedPresetIndex = 0
    }

    private func makeColorItemView(color: ANXColor, index: Int) -> NSView {
        let wrapper = BaseView()
        let size = Self.colorWrapperSize

        let colorView = BaseView()
        colorView.wantsLayer = true
        colorView.layer?.cornerRadius = 3
        colorView.layer?.backgroundColor = color.cgColor
        wrapper.addSubview(colorView)

        let click = NSClickGestureRecognizer(target: self, action: #selector(presetColorClicked(_:)))
        colorView.addGestureRecognizer(click)

        let doubleClick = NSClickGestureRecognizer(target: self, action: #selector(presetColorDoubleClicked(_:)))
        doubleClick.numberOfClicksRequired = 2
        colorView.addGestureRecognizer(doubleClick)

        colorView.snp.makeConstraints { make in
            make.leading.bottom.equalToSuperview()
            make.width.equalTo(Self.colorItemSize.width)
            make.height.equalTo(Self.colorItemSize.height)
        }

        // delete × button at top-right
        let deleteBtn = BaseView()
        deleteBtn.wantsLayer = true
        deleteBtn.layer?.cornerRadius = 6
        deleteBtn.layer?.backgroundColor = NSColor(white: 0, alpha: 0.7).cgColor
        wrapper.addSubview(deleteBtn)
        deleteBtn.snp.makeConstraints { make in
            make.top.equalToSuperview()
            make.trailing.equalToSuperview()
            make.width.height.equalTo(12)
        }

        let deleteLabel = Label()
        deleteLabel.stringValue = "×"
        deleteLabel.font = .systemFont(ofSize: 9, weight: .bold)
        deleteLabel.textColor = .white
        deleteLabel.alignment = .center
        deleteBtn.addSubview(deleteLabel)
        deleteLabel.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        let deleteClick = NSClickGestureRecognizer(target: self, action: #selector(deleteColorClicked(_:)))
        deleteBtn.addGestureRecognizer(deleteClick)

        wrapper.snp.makeConstraints { make in
            make.width.equalTo(size.width)
            make.height.equalTo(size.height)
        }

        return wrapper
    }

    private func makeAddColorView() -> NSView {
        let container = BaseView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 3
        container.layer?.borderWidth = 1
        container.layer?.borderColor = NSColor(white: 0.5, alpha: 1).cgColor

        let label = Label()
        label.stringValue = "+"
        label.font = .systemFont(ofSize: 13, weight: .bold)
        label.textColor = .lightGray
        label.alignment = .center
        container.addSubview(label)
        label.snp.makeConstraints { make in
            make.center.equalToSuperview()
        }

        container.snp.makeConstraints { make in
            make.width.equalTo(Self.colorItemSize.width)
            make.height.equalTo(Self.colorItemSize.height)
        }

        let click = NSClickGestureRecognizer(target: self, action: #selector(addColorClicked))
        container.addGestureRecognizer(click)

        return container
    }

    private func updateSelectionHighlight() {
        for (index, view) in colorItemViews.enumerated() {
            let isSelected: Bool
            if index < colors.count {
                isSelected = (index == selectedPresetIndex)
            } else {
                isSelected = false
            }
            view.layer?.borderWidth = isSelected ? 2 : 0
            view.layer?.borderColor = isSelected ? NSColor.white.cgColor : nil
        }
    }

    private func updateColorView(at index: Int, with color: ANXColor) {
        guard index < colorItemViews.count else { return }
        colorItemViews[index].subviews.first?.layer?.backgroundColor = color.cgColor
    }

    // MARK: - Actions

    @objc private func presetColorClicked(_ gesture: NSClickGestureRecognizer) {
        guard let colorView = gesture.view,
              let wrapper = colorView.superview,
              let index = colorItemViews.firstIndex(of: wrapper),
              index < colors.count else { return }
        selectedPresetIndex = index
        selectedColor = colors[index]
        Preferences.shared.sendDanmakuColor = selectedColor
        updateSelectionHighlight()
        onColorChanged?(selectedColor)
    }

    @objc private func presetColorDoubleClicked(_ gesture: NSClickGestureRecognizer) {
        guard let colorView = gesture.view,
              let wrapper = colorView.superview,
              let index = colorItemViews.firstIndex(of: wrapper),
              index < colors.count else { return }
        editingColorIndex = index
        NSColorPanel.shared.setTarget(self)
        NSColorPanel.shared.setAction(#selector(colorPanelDidChange(_:)))
        NSColorPanel.shared.color = colors[index]
        NSColorPanel.shared.orderFront(nil)
    }

    @objc private func addColorClicked() {
        guard colors.count < Self.maxColorCount else { return }
        let newColor = ANXColor.white
        colors.append(newColor)
        selectedPresetIndex = colors.count - 1
        selectedColor = newColor
        rebuildColorButtons()
        onColorChanged?(newColor)

        editingColorIndex = selectedPresetIndex
        NSColorPanel.shared.setTarget(self)
        NSColorPanel.shared.setAction(#selector(colorPanelDidChange(_:)))
        NSColorPanel.shared.color = newColor
        NSColorPanel.shared.orderFront(nil)
    }

    @objc private func colorPanelDidChange(_ sender: NSColorPanel) {
        let newColor = sender.color
        if let index = editingColorIndex, index < colors.count {
            colors[index] = newColor
            updateColorView(at: index, with: newColor)
        }
        selectedColor = newColor
        if let index = editingColorIndex {
            selectedPresetIndex = index
        }
        updateSelectionHighlight()
        onColorChanged?(newColor)
    }

    @objc private func colorPanelWillClose(_ notification: Notification) {
        Preferences.shared.sendDanmakuColors = colors
        Preferences.shared.sendDanmakuColor = selectedColor
        editingColorIndex = nil
    }

    @objc private func deleteColorClicked(_ gesture: NSClickGestureRecognizer) {
        guard let deleteBtn = gesture.view,
              let container = deleteBtn.superview,
              let index = colorItemViews.firstIndex(of: container),
              index < colors.count,
              colors.count > 1 else { return }

        let alert = NSAlert()
        alert.messageText = NSLocalizedString("删除颜色", comment: "")
        alert.informativeText = NSLocalizedString("确定要删除该颜色吗？", comment: "")
        alert.addButton(withTitle: NSLocalizedString("删除", comment: ""))
        alert.addButton(withTitle: NSLocalizedString("取消", comment: ""))
        alert.alertStyle = .warning

        guard let window = view.window else { return }
        alert.beginSheetModal(for: window) { [weak self] response in
            guard let self = self, response == .alertFirstButtonReturn else { return }
            guard self.colors.count > 1 else { return }
            self.colors.remove(at: index)
            Preferences.shared.sendDanmakuColors = self.colors
            if self.selectedPresetIndex >= self.colors.count {
                self.selectedPresetIndex = self.colors.count - 1
            }
            if self.selectedPresetIndex >= 0, self.selectedPresetIndex < self.colors.count {
                self.selectedColor = self.colors[self.selectedPresetIndex]
                Preferences.shared.sendDanmakuColor = self.selectedColor
                self.onColorChanged?(self.selectedColor)
            }
            self.rebuildColorButtons()
        }
    }

    @objc private func resetColorsClicked() {
        colors = Preferences.defaultSendDanmakuColors
        Preferences.shared.sendDanmakuColors = colors
        selectedPresetIndex = 0
        if let first = colors.first {
            selectedColor = first
            Preferences.shared.sendDanmakuColor = first
        }
        rebuildColorButtons()
        onColorChanged?(selectedColor)
    }

    @objc private func modeChanged(_ sender: NSPopUpButton) {
        let modes = Comment.Mode.allCases
        let idx = sender.indexOfSelectedItem
        guard idx >= 0, idx < modes.count else { return }
        selectedMode = modes[idx]
        onModeChanged?(modes[idx])
    }
}
