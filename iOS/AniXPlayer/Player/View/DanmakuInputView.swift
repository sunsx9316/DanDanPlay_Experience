//
//  DanmakuInputView.swift
//  AniXPlayer
//
//  Created by jimhuang on 2024/4/15.
//

import UIKit
import SnapKit
import YYCategories

protocol DanmakuInputViewDelegate: AnyObject {
    func danmakuInputView(_ view: DanmakuInputView, didSendDanmaku text: String, mode: Comment.Mode, color: ANXColor)
    func danmakuInputViewDidExpand(_ view: DanmakuInputView)
    func danmakuInputViewDidCollapse(_ view: DanmakuInputView)
}

fileprivate extension Comment.Mode {
    var name: String {
        switch self {
        case .normal:
            return NSLocalizedString("滚动", comment: "")
        case .bottom:
            return NSLocalizedString("置底", comment: "")
        case .top:
            return NSLocalizedString("置顶", comment: "")
        }
    }
}

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

    /// 模式选择分段控件
    private lazy var modeSegmentedControl: UISegmentedControl = {
        let items = Comment.Mode.allCases.compactMap { mode in
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
    private lazy var presetColors: [ANXColor] = [
        ANXColor(anxRgb: 0xFFFFFF), // 白色
        ANXColor(anxRgb: 0xFF0000), // 红色
        ANXColor(anxRgb: 0x00FF00), // 绿色
        ANXColor(anxRgb: 0x0000FF), // 蓝色
        ANXColor(anxRgb: 0xFFFF00), // 黄色
        ANXColor(anxRgb: 0xFF00FF), // 紫色
    ]
    
    private var selectedColor: ANXColor?
    private var selectedColorButton: UIButton?

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
        }

        self.modeSegmentedControl.snp.makeConstraints { make in
            make.leading.equalTo(self.colorStackView)
            make.top.equalTo(self.colorStackView.snp.bottom).offset(8)
        }

        setupColorButtons()
    }
    
    private func selectedColorButton(_ button: UIButton?, isSelected: Bool) {
        guard let button = button else { return }

        if isSelected {
            button.layer.borderWidth = 2
            button.layer.borderColor = UIColor.white.cgColor
        } else {
            button.layer.borderWidth = 0
            button.layer.borderColor = UIColor.clear.cgColor
        }

        if let checkmark = button.viewWithTag(999) {
            checkmark.isHidden = !isSelected
        }
    }

    private func setupColorButtons() {
        for (index, color) in self.presetColors.enumerated() {
            let button = Button(type: .custom)
            button.backgroundColor = color
            button.layer.borderWidth = index == 0 ? 2 : 0
            button.layer.borderColor = index == 0 ? UIColor.white.cgColor : UIColor.clear.cgColor
            button.clipsToBounds = true
            button.layer.cornerRadius = 3
            button.addBlock(for: .touchUpInside) { [weak self, weak weakButton = button] _ in
                guard let self = self else { return }

                self.selectedColor = color

                self.selectedColorButton(self.selectedColorButton, isSelected: false)
                self.selectedColorButton = weakButton
                self.selectedColorButton(weakButton, isSelected: true)
            }

            if index == 0 {
                self.selectedColor = color
                self.selectedColorButton(button, isSelected: true)
            }

            let checkmark = UILabel()
            checkmark.tag = 999
            checkmark.text = "✓"
            checkmark.font = .systemFont(ofSize: 12, weight: .bold)
            checkmark.textColor = .white
            checkmark.textAlignment = .center
            checkmark.backgroundColor = UIColor(white: 0, alpha: 0.3)
            checkmark.layer.cornerRadius = 7
            checkmark.clipsToBounds = true
            checkmark.isHidden = index != 0
            button.addSubview(checkmark)

            checkmark.snp.makeConstraints { make in
                make.trailing.equalToSuperview().offset(2)
                make.bottom.equalToSuperview().offset(2)
                make.width.height.equalTo(14)
            }

            self.colorStackView.addArrangedSubview(button)

            button.snp.makeConstraints { make in
                make.width.equalTo(28)
                make.height.equalTo(20)
            }
        }
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
        guard let text = self.danmakuTextField.text, !text.isEmpty, let color = self.selectedColor else {
            return
        }

        let mode: Comment.Mode
        switch self.modeSegmentedControl.selectedSegmentIndex {
        case 0: mode = .normal  // 普通
        case 1: mode = .top  // 顶部
        case 2: mode = .bottom  // 底部
        default: mode = .normal
        }

        delegate?.danmakuInputView(self, didSendDanmaku: text, mode: mode, color: color)
        self.danmakuTextField.text = ""
        self.danmakuTextField.resignFirstResponder()
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
