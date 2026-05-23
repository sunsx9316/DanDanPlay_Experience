//
//  DanmakuInputViewController.swift
//  AniXPlayer
//
//  tvOS 弹幕发送界面 — 输入框 + 颜色选择 + 模式选择
//

import UIKit
import SnapKit

class DanmakuInputViewController: ViewController {

    // MARK: - Callback

    var onSend: ((_ text: String, _ mode: Comment.Mode, _ color: ANXColor) -> Void)?
    var onDismiss: (() -> Void)?

    // MARK: - State

    private var selectedColor: ANXColor = Preferences.shared.sendDanmakuColor
    private var selectedMode: Comment.Mode = .normal
    private var colors: [ANXColor] = Preferences.shared.sendDanmakuColors

    // MARK: - UI

    private let containerView: UIView = {
        let view = UIView()
        view.backgroundColor = UIColor(white: 0.15, alpha: 0.95)
        view.layer.cornerRadius = 20
        return view
    }()

    private let titleLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("发送弹幕", comment: "")
        label.font = .ddp_normal(weight: .bold)
        label.textColor = .white
        label.textAlignment = .center
        return label
    }()

    private lazy var textField: UITextField = {
        let tf = UITextField()
        tf.placeholder = NSLocalizedString("发个弹幕吧", comment: "")
        tf.font = .ddp_small()
        tf.textColor = .white
        tf.returnKeyType = .send
        tf.delegate = self
        return tf
    }()

    private let colorLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("弹幕颜色", comment: "")
        label.font = .ddp_small(weight: .medium)
        label.textColor = .lightGray
        return label
    }()

    private lazy var colorStackView: UIStackView = {
        let stack = UIStackView()
        stack.axis = .horizontal
        stack.spacing = 16
        stack.alignment = .center
        for color in colors {
            let btn = makeColorButton(color: color)
            stack.addArrangedSubview(btn)
        }
        return stack
    }()

    private let modeLabel: UILabel = {
        let label = UILabel()
        label.text = NSLocalizedString("弹幕模式", comment: "")
        label.font = .ddp_small(weight: .medium)
        label.textColor = .lightGray
        return label
    }()

    private lazy var modeSegment: UISegmentedControl = {
        let items = Comment.Mode.allCases.map { $0.name }
        let seg = UISegmentedControl(items: items)
        seg.selectedSegmentIndex = 0
        seg.addTarget(self, action: #selector(modeChanged), for: .valueChanged)
        return seg
    }()

    private lazy var sendButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("发送", comment: ""), for: .normal)
        button.titleLabel?.font = .ddp_small(weight: .bold)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.black, for: .focused)
        button.backgroundColor = .systemGreen
        button.layer.cornerRadius = 10
        button.addTarget(self, action: #selector(sendPressed), for: .primaryActionTriggered)
        return button
    }()

    private lazy var cancelButton: UIButton = {
        let button = UIButton(type: .system)
        button.setTitle(NSLocalizedString("取消", comment: ""), for: .normal)
        button.titleLabel?.font = .ddp_small(weight: .medium)
        button.setTitleColor(.white, for: .normal)
        button.setTitleColor(.black, for: .focused)
        button.addTarget(self, action: #selector(cancelPressed), for: .primaryActionTriggered)
        return button
    }()

    // MARK: - Init

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
        setupUI()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        defaultFocusView = textField
        setNeedsFocusUpdate()
        updateFocusIfNeeded()
    }

    deinit {
        onDismiss?()
    }

    // MARK: - Setup

    private func setupUI() {
        view.addSubview(containerView)

        containerView.addSubview(titleLabel)
        containerView.addSubview(textField)
        containerView.addSubview(colorLabel)
        containerView.addSubview(colorStackView)
        containerView.addSubview(modeLabel)
        containerView.addSubview(modeSegment)
        containerView.addSubview(sendButton)
        containerView.addSubview(cancelButton)

        containerView.snp.makeConstraints { make in
            make.center.equalToSuperview()
            make.width.equalTo(600)
        }

        titleLabel.snp.makeConstraints { make in
            make.top.equalToSuperview().offset(30)
            make.leading.trailing.equalToSuperview().inset(40)
        }

        textField.snp.makeConstraints { make in
            make.top.equalTo(titleLabel.snp.bottom).offset(24)
            make.leading.trailing.equalToSuperview().inset(40)
            make.height.equalTo(48)
        }

        colorLabel.snp.makeConstraints { make in
            make.top.equalTo(textField.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(40)
        }

        colorStackView.snp.makeConstraints { make in
            make.top.equalTo(colorLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(40)
        }

        modeLabel.snp.makeConstraints { make in
            make.top.equalTo(colorStackView.snp.bottom).offset(24)
            make.leading.equalToSuperview().offset(40)
        }

        modeSegment.snp.makeConstraints { make in
            make.top.equalTo(modeLabel.snp.bottom).offset(12)
            make.leading.equalToSuperview().offset(40)
        }

        sendButton.snp.makeConstraints { make in
            make.top.equalTo(modeSegment.snp.bottom).offset(30)
            make.trailing.equalToSuperview().offset(-40)
            make.width.equalTo(120)
            make.height.equalTo(48)
            make.bottom.equalToSuperview().offset(-30)
        }

        cancelButton.snp.makeConstraints { make in
            make.trailing.equalTo(sendButton.snp.leading).offset(-20)
            make.centerY.equalTo(sendButton)
            make.width.equalTo(120)
            make.height.equalTo(48)
        }
    }

    // MARK: - Focus handling

    override func didUpdateFocus(in context: UIFocusUpdateContext, with coordinator: UIFocusAnimationCoordinator) {
        super.didUpdateFocus(in: context, with: coordinator)

        coordinator.addCoordinatedAnimations({
            for case let btn as UIButton in self.colorStackView.arrangedSubviews {
                self.updateColorButtonAppearance(btn, focused: btn === context.nextFocusedView)
            }
        }, completion: nil)
    }

    private func updateColorButtonAppearance(_ btn: UIButton, focused: Bool) {
        let isSelected = btn.backgroundColor == selectedColor
        if isSelected {
            btn.layer.borderWidth = 3
            btn.layer.borderColor = UIColor.white.cgColor
        } else if focused {
            btn.layer.borderWidth = 2
            btn.layer.borderColor = UIColor.white.cgColor
        } else {
            btn.layer.borderWidth = 0
            btn.layer.borderColor = UIColor.clear.cgColor
        }
        btn.transform = focused ? CGAffineTransform(scaleX: 1.25, y: 1.25) : .identity
    }

    private func makeColorButton(color: ANXColor) -> UIButton {
        let btn = UIButton(type: .custom)
        btn.backgroundColor = color
        btn.layer.cornerRadius = 8
        btn.snp.makeConstraints { make in
            make.width.height.equalTo(40)
        }
        btn.addTarget(self, action: #selector(colorButtonPressed(_:)), for: .primaryActionTriggered)
        updateColorButtonAppearance(btn, focused: false)
        return btn
    }

    @objc private func colorButtonPressed(_ sender: UIButton) {
        guard let color = sender.backgroundColor else { return }
        selectedColor = color
        Preferences.shared.sendDanmakuColor = color

        for case let btn as UIButton in colorStackView.arrangedSubviews {
            updateColorButtonAppearance(btn, focused: btn === sender)
        }
    }

    @objc private func modeChanged() {
        selectedMode = Comment.Mode.allCases[modeSegment.selectedSegmentIndex]
    }

    // MARK: - Actions

    @objc private func sendPressed() {
        guard let text = textField.text, !text.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        onSend?(text, selectedMode, selectedColor)
        textField.text = ""
        dismiss(animated: true)
    }

    @objc private func cancelPressed() {
        dismiss(animated: true)
    }
}

// MARK: - UITextFieldDelegate

extension DanmakuInputViewController: UITextFieldDelegate {

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        sendPressed()
        return true
    }
}
