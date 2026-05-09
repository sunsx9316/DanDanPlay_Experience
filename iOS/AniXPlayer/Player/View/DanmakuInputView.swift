//
//  DanmakuInputView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/4/15.
//

import UIKit
import SnapKit
import YYCategories

// MARK: - ColorItem

class ColorItem {
    var color: ANXColor

    init(color: ANXColor) {
        self.color = color
    }
}

// MARK: - DanmakuInputViewDelegate

protocol DanmakuInputViewDelegate: AnyObject {
    func danmakuInputView(_ view: DanmakuInputView, didSendDanmaku text: String, mode: Comment.Mode, color: ANXColor)
    func danmakuInputViewDidExpand(_ view: DanmakuInputView)
    func danmakuInputViewDidCollapse(_ view: DanmakuInputView)
}

// MARK: - ColorButton

private class ColorButton: UIView {

    let item: ColorItem

    var onTap: ((ColorButton) -> Void)?

    var isSelected: Bool = false {
        didSet {
            if isSelected {
                bgView.layer.borderWidth = 2
                bgView.layer.borderColor = UIColor.white.cgColor
                checkmarkLabel.isHidden = false
            } else {
                bgView.layer.borderWidth = 0
                bgView.layer.borderColor = UIColor.clear.cgColor
                checkmarkLabel.isHidden = true
            }
        }
    }

    private lazy var bgView: UIView = {
        let bgView = UIView()
        bgView.isUserInteractionEnabled = false
        bgView.layer.cornerRadius = 3
        bgView.clipsToBounds = true
        return bgView
    }()

    private lazy var checkmarkLabel: UILabel = {
        let label = UILabel()
        label.text = "✓"
        label.font = .systemFont(ofSize: 12, weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        label.backgroundColor = UIColor(white: 0, alpha: 0.5)
        label.layer.cornerRadius = 7
        label.clipsToBounds = true
        label.isHidden = true
        return label
    }()

    init(item: ColorItem) {
        self.item = item
        super.init(frame: .zero)

        bgView.backgroundColor = item.color
        addSubview(bgView)
        addSubview(checkmarkLabel)

        bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
            make.width.equalTo(28)
            make.height.equalTo(20)
        }

        checkmarkLabel.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(4)
            make.bottom.equalToSuperview().offset(4)
            make.width.height.equalTo(14)
        }

        let tap = UITapGestureRecognizer(target: self, action: #selector(handleTap))
        addGestureRecognizer(tap)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func handleTap() {
        onTap?(self)
    }
}

// MARK: - DanmakuInputView

class DanmakuInputView: UIView {

    weak var delegate: DanmakuInputViewDelegate?

    private lazy var bgView: UIView = {
        let view = UIView()
        let tap = UITapGestureRecognizer.init { [weak self] _ in
            self?.collapse()
        }
        view.addGestureRecognizer(tap)
        return view
    }()

    /// 弹幕输入面板
    private lazy var inputPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        return view
    }()

    /// 收起键盘按钮
    private lazy var dismissKeyboardButton: Button = {
        let button = Button(type: .custom)
        button.setTitle("A", for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 16, weight: .medium)
        button.backgroundColor = UIColor(white: 0.3, alpha: 1)
        button.layer.cornerRadius = 15
        button.addTarget(self, action: #selector(onTouchDismissKeyboardButton), for: .touchUpInside)
        return button
    }()

    /// 弹幕输入框
    private lazy var danmakuTextField: TextField = {
        let textField = TextField()
        textField.placeholder = NSLocalizedString("发个弹幕吧", comment: "")
        textField.font = .systemFont(ofSize: 14)
        textField.textColor = .white
        textField.backgroundColor = UIColor(white: 0.2, alpha: 1)
        textField.layer.cornerRadius = 18
        textField.leftView = UIView(frame: CGRect(x: 0, y: 0, width: 15, height: 0))
        textField.leftViewMode = .always
        textField.rightView = UIView(frame: CGRect(x: 0, y: 0, width: 60, height: 0))
        textField.rightViewMode = .always
        textField.returnKeyType = .send
        textField.delegate = self
        textField.attributedPlaceholder = NSAttributedString(
            string: NSLocalizedString("发个弹幕吧", comment: ""),
            attributes: [.foregroundColor: UIColor.lightGray]
        )
        return textField
    }()

    /// 发送按钮
    private lazy var sendButton: Button = {
        let button = Button(type: .custom)
        button.setTitle(NSLocalizedString("发送", comment: ""), for: .normal)
        button.setTitleColor(.white, for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 14, weight: .semibold)
        button.backgroundColor = UIColor(red: 0.29, green: 0.565, blue: 0.886, alpha: 1)
        button.layer.cornerRadius = 15
        button.addTarget(self, action: #selector(onTouchSendButton), for: .touchUpInside)
        return button
    }()

    /// 弹幕配置视图
    private lazy var danmakuConfigPanel: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.1, alpha: 0.95)
        return view
    }()

    /// 颜色选择视图
    private lazy var colorStackView: UIStackView = {
        let stackView = UIStackView()
        stackView.axis = .horizontal
        stackView.spacing = 8
        stackView.distribution = .fill
        return stackView
    }()
     
    private lazy var modes = Comment.Mode.allCases

    /// 模式选择分段控件
    private lazy var modeSegmentedControl: UISegmentedControl = {
        let items = self.modes.compactMap { mode in
            return mode.name
        }

        let control = UISegmentedControl(items: items)
        control.selectedSegmentIndex = 0
        control.selectedSegmentTintColor = .mainColor
        control.setTitleTextAttributes([.foregroundColor: UIColor.textColor, .font: UIFont.ddp_normal], for: .normal)
        control.setTitleTextAttributes([.foregroundColor: UIColor.textColor, .font: UIFont.ddp_normal], for: .selected)
        return control
    }()

    /// 预设颜色列表
    private var presetItems: [ColorItem] = []

    private var selectedItem: ColorItem?

    private var keyboardHeight: CGFloat = 0

    /// 弹幕输入面板高度
    private let inputPanelHeight: CGFloat = 150

    override init(frame: CGRect) {
        super.init(frame: frame)
        self.setupInit()
        setupKeyboardObservers()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        self.setupInit()
        setupKeyboardObservers()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    func expand() {
        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.layoutIfNeeded()
            self.alpha = 1
        }) { _ in
            self.danmakuTextField.becomeFirstResponder()
            self.delegate?.danmakuInputViewDidExpand(self)
        }
    }

    func collapse() {
        danmakuTextField.resignFirstResponder()

        UIView.animate(withDuration: 0.25, delay: 0, options: .curveEaseInOut, animations: {
            self.danmakuConfigPanel.snp.updateConstraints { make in
                make.height.equalTo(0)
            }
            self.layoutIfNeeded()
            self.alpha = 0
        }) { _ in
            self.delegate?.danmakuInputViewDidCollapse(self)
        }
    }

    private func setupKeyboardObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(keyboardWillShow(_:)),
            name: UIResponder.keyboardWillShowNotification,
            object: nil
        )
    }

    @objc private func keyboardWillShow(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let keyboardFrame = userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else {
            return
        }
        keyboardHeight = keyboardFrame.height
        updateInputPanelPosition()
    }

    private func updateInputPanelPosition() {
        UIView.animate(withDuration: 0.25) {
            self.danmakuConfigPanel.snp.updateConstraints { make in
                make.height.equalTo(self.keyboardHeight)
            }
            self.layoutIfNeeded()
        }
    }

    private func setupInit() {
        
        self.alpha = 0
        
        self.addSubview(self.bgView)
        self.addSubview(self.inputPanel)
        self.addSubview(self.danmakuConfigPanel)

        self.inputPanel.addSubview(self.dismissKeyboardButton)
        self.inputPanel.addSubview(self.danmakuTextField)
        self.inputPanel.addSubview(self.sendButton)
        self.danmakuConfigPanel.addSubview(self.colorStackView)
        self.danmakuConfigPanel.addSubview(self.modeSegmentedControl)
        
        self.bgView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.inputPanel.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview()
        }
        
        self.danmakuConfigPanel.snp.makeConstraints { make in
            make.bottom.leading.trailing.equalToSuperview()
            make.top.equalTo(self.inputPanel.snp.bottom)
            make.height.equalTo(0)
        }

        self.dismissKeyboardButton.snp.makeConstraints { make in
            make.leading.equalTo(inputPanel.safeAreaLayoutGuide.snp.leading).offset(12)
            make.top.equalToSuperview().offset(12)
            make.bottom.equalToSuperview().offset(-12)
            make.width.height.equalTo(30)
        }

        self.danmakuTextField.snp.makeConstraints { make in
            make.leading.equalTo(self.dismissKeyboardButton.snp.trailing).offset(8)
            make.trailing.equalTo(self.sendButton.snp.leading).offset(-8)
            make.centerY.equalTo(self.dismissKeyboardButton)
            make.height.equalTo(36)
        }

        self.sendButton.snp.makeConstraints { make in
            make.trailing.equalTo(inputPanel.safeAreaLayoutGuide.snp.trailing).offset(-12)
            make.centerY.equalTo(self.dismissKeyboardButton)
            make.width.equalTo(50)
            make.height.equalTo(30)
        }

        self.colorStackView.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(12)
            make.leading.equalTo(self.dismissKeyboardButton)
            make.height.equalTo(20)
            make.trailing.lessThanOrEqualTo(self.sendButton.snp.trailing)
        }

        self.modeSegmentedControl.snp.makeConstraints { make in
            make.leading.equalTo(self.colorStackView)
            make.top.equalTo(self.colorStackView.snp.bottom).offset(20)
        }

        setupColorButtons()
    }
    
    private func setupColorButtons() {
        self.presetItems = Preferences.shared.sendDanmakuColors.map { ColorItem(color: $0) }
        let items = self.presetItems

        for (index, item) in items.enumerated() {
            let colorButton = ColorButton(item: item)
            colorButton.onTap = { [weak self] _ in
                guard let self = self else { return }
                self.selectItem(item)
            }

            if index == 0 {
                colorButton.isSelected = true
                self.selectedItem = item
            }

            self.colorStackView.addArrangedSubview(colorButton)
            colorButton.snp.makeConstraints { make in
                make.width.equalTo(28)
                make.height.equalTo(20)
            }
        }

        // 添加 + 按钮
        let addButton = Button(type: .system)
        addButton.setTitle("+", for: .normal)
        addButton.setTitleColor(.white, for: .normal)
        addButton.titleLabel?.font = .systemFont(ofSize: 18, weight: .medium)
        addButton.backgroundColor = UIColor(white: 0.3, alpha: 1)
        addButton.layer.cornerRadius = 3
        addButton.clipsToBounds = true
        addButton.addBlock(for: .touchUpInside) { [weak self] _ in
            guard let self = self else { return }

            let items = self.presetItems
            let vc = ColorManagementViewController(items: items, selectedItem: self.selectedItem)
            vc.onSave = { [weak self] newItems in
                Preferences.shared.sendDanmakuColors = newItems.map { $0.color }
                self?.reloadColorButtons()
            }

            let nav = NavigationController(rootViewController: vc)
            self.viewController?.present(nav, animated: true)
        }

        addButton.snp.makeConstraints { make in
            make.width.equalTo(28)
            make.height.equalTo(20)
        }
        self.colorStackView.addArrangedSubview(addButton)
    }

    private func selectItem(_ item: ColorItem) {
        self.selectedItem = item
        for case let button as ColorButton in colorStackView.arrangedSubviews {
            button.isSelected = button.item === item
        }
    }

    private func reloadColorButtons() {
        self.selectedItem = nil
        self.colorStackView.arrangedSubviews.forEach { $0.removeFromSuperview() }
        setupColorButtons()
    }

    // MARK: - Actions

    @objc private func onTouchDismissKeyboardButton() {
        if danmakuTextField.isFirstResponder {
            self.danmakuTextField.resignFirstResponder()
        } else {
            danmakuTextField.becomeFirstResponder()
        }
    }

    @objc private func onTouchSendButton() {
        sendDanmaku()
    }

    private func sendDanmaku() {
        guard let text = self.danmakuTextField.text, !text.isEmpty,
              let color = self.selectedItem?.color else {
            return
        }
        
        let idx = self.modeSegmentedControl.selectedSegmentIndex
        if idx < modes.count && idx >= 0 {
            let mode = modes[idx]
            delegate?.danmakuInputView(self, didSendDanmaku: text, mode: mode, color: color)
            self.danmakuTextField.text = ""
            self.collapse()
        }

    }
}

// MARK: - UITextFieldDelegate
extension DanmakuInputView: UITextFieldDelegate {
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendDanmaku()
        return true
    }

    func textFieldDidBeginEditing(_ textField: UITextField) {
        updateInputPanelPosition()
    }
}
