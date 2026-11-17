//
//  AccountEditSheetViewController.swift
//  AniXPlayer
//
//  macOS only：修改昵称 / 邮箱 / 密码的原生 sheet。
//

import Cocoa
import SnapKit

@MainActor
final class AccountEditSheetViewController: ViewController {

    enum Mode {
        case screenName(current: String)
        case email(currentEmail: String)
        case password
    }

    enum Submission {
        case screenName(String)
        case email(old: String, new: String)
        case password(old: String, new: String, confirmation: String)
    }

    var onSubmit: ((Submission) async throws -> Void)?

    private let mode: Mode
    private let titleLabel = NSTextField(labelWithString: "")
    private let hintLabel = NSTextField(labelWithString: "")
    private let errorLabel = NSTextField(labelWithString: "")
    private let saveButton = NSButton(title: "", target: nil, action: nil)
    private let cancelButton = NSButton(title: "", target: nil, action: nil)
    private let spinner = NSProgressIndicator()
    private let rootStack = NSStackView()
    private let formStack = NSStackView()
    private let buttonRow = NSStackView()

    private let screenNameField = NSTextField()
    private let oldEmailField = NSTextField()
    private let newEmailField = NSTextField()
    private let oldPasswordField = NSSecureTextField()
    private let newPasswordField = NSSecureTextField()
    private let confirmPasswordField = NSSecureTextField()

    private var isSubmitting = false

    init(mode: Mode) {
        self.mode = mode
        super.init()
        preferredContentSize = NSSize(width: 420, height: preferredHeight)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 420, height: preferredHeight))
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setup()
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        firstResponderField.becomeFirstResponder()
    }

    private var preferredHeight: CGFloat {
        switch mode {
        case .screenName:
            return 260
        case .email:
            return 340
        case .password:
            return 410
        }
    }

    private var firstResponderField: NSTextField {
        switch mode {
        case .screenName:
            return screenNameField
        case .email:
            return newEmailField
        case .password:
            return oldPasswordField
        }
    }

    private var sheetIdentifier: String {
        switch mode {
        case .screenName: return AccessibilityID.Account.nicknameSheet
        case .email: return AccessibilityID.Account.emailSheet
        case .password: return AccessibilityID.Account.passwordSheet
        }
    }

    // MARK: - Setup

    private func setup() {
        view.setAccessibilityIdentifier(sheetIdentifier)

        titleLabel.font = .systemFont(ofSize: 17, weight: .semibold)
        hintLabel.font = .systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.maximumNumberOfLines = 0
        hintLabel.lineBreakMode = .byWordWrapping

        errorLabel.font = .systemFont(ofSize: 11)
        errorLabel.textColor = .systemRed
        errorLabel.maximumNumberOfLines = 0
        errorLabel.lineBreakMode = .byWordWrapping
        errorLabel.isHidden = true
        errorLabel.setAccessibilityIdentifier(AccessibilityID.Account.formError)
        errorLabel.setAccessibilityLabel(NSLocalizedString("错误信息", comment: ""))

        formStack.orientation = .vertical
        formStack.alignment = .width
        formStack.spacing = 10

        rootStack.orientation = .vertical
        rootStack.alignment = .width
        rootStack.spacing = 12
        rootStack.detachesHiddenViews = true

        configureFields()

        saveButton.title = NSLocalizedString("保存", comment: "")
        saveButton.bezelStyle = .rounded
        saveButton.target = self
        saveButton.action = #selector(saveTapped)
        saveButton.keyEquivalent = "\r"
        saveButton.setAccessibilityIdentifier(AccessibilityID.Account.formSave)

        cancelButton.title = NSLocalizedString("取消", comment: "")
        cancelButton.bezelStyle = .rounded
        cancelButton.target = self
        cancelButton.action = #selector(cancelTapped)
        cancelButton.keyEquivalent = "\u{1b}"
        cancelButton.setAccessibilityIdentifier(AccessibilityID.Account.formCancel)

        spinner.style = .spinning
        spinner.controlSize = .small
        spinner.isDisplayedWhenStopped = false

        let spacer = NSView()
        spacer.setContentHuggingPriority(.defaultLow, for: .horizontal)
        buttonRow.orientation = .horizontal
        buttonRow.alignment = .centerY
        buttonRow.spacing = 8
        buttonRow.addArrangedSubview(spinner)
        buttonRow.addArrangedSubview(spacer)
        buttonRow.addArrangedSubview(cancelButton)
        buttonRow.addArrangedSubview(saveButton)

        rootStack.addArrangedSubview(titleLabel)
        rootStack.addArrangedSubview(hintLabel)
        rootStack.addArrangedSubview(formStack)
        rootStack.addArrangedSubview(errorLabel)
        rootStack.addArrangedSubview(buttonRow)

        view.addSubview(rootStack)
        rootStack.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(20)
            make.top.equalToSuperview().offset(18)
            make.bottom.lessThanOrEqualToSuperview().offset(-18)
        }
        cancelButton.snp.makeConstraints { make in
            make.width.equalTo(80)
        }
        saveButton.snp.makeConstraints { make in
            make.width.equalTo(80)
        }

        applyModeText()
    }

    private func configureFields() {
        configure(textField: screenNameField, identifier: AccessibilityID.Account.nicknameField)
        configure(textField: oldEmailField, identifier: AccessibilityID.Account.oldEmailField)
        configure(textField: newEmailField, identifier: AccessibilityID.Account.newEmailField)
        configure(secureField: oldPasswordField, identifier: AccessibilityID.Account.oldPasswordField)
        configure(secureField: newPasswordField, identifier: AccessibilityID.Account.newPasswordField)
        configure(secureField: confirmPasswordField, identifier: AccessibilityID.Account.confirmPasswordField)

        switch mode {
        case .screenName(let current):
            screenNameField.stringValue = current
            formStack.addArrangedSubview(fieldGroup(
                title: NSLocalizedString("昵称", comment: ""),
                control: screenNameField
            ))

        case .email(let currentEmail):
            oldEmailField.stringValue = currentEmail
            formStack.addArrangedSubview(fieldGroup(
                title: NSLocalizedString("当前邮箱", comment: ""),
                control: oldEmailField
            ))
            formStack.addArrangedSubview(fieldGroup(
                title: NSLocalizedString("新邮箱", comment: ""),
                control: newEmailField
            ))

        case .password:
            formStack.addArrangedSubview(fieldGroup(
                title: NSLocalizedString("当前密码", comment: ""),
                control: oldPasswordField
            ))
            formStack.addArrangedSubview(fieldGroup(
                title: NSLocalizedString("新密码", comment: ""),
                control: newPasswordField
            ))
            formStack.addArrangedSubview(fieldGroup(
                title: NSLocalizedString("确认新密码", comment: ""),
                control: confirmPasswordField
            ))
        }
    }

    private func configure(textField: NSTextField, identifier: String) {
        textField.font = .systemFont(ofSize: 13)
        textField.isEditable = true
        textField.isSelectable = true
        textField.bezelStyle = .roundedBezel
        textField.setAccessibilityIdentifier(identifier)
    }

    private func configure(secureField: NSSecureTextField, identifier: String) {
        secureField.font = .systemFont(ofSize: 13)
        secureField.bezelStyle = .roundedBezel
        secureField.setAccessibilityIdentifier(identifier)
    }

    private func fieldGroup(title: String, control: NSTextField) -> NSStackView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.textColor = .secondaryLabelColor

        let stack = NSStackView(views: [label, control])
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 4
        control.snp.makeConstraints { make in
            make.height.equalTo(26)
        }
        return stack
    }

    private func applyModeText() {
        switch mode {
        case .screenName:
            titleLabel.stringValue = NSLocalizedString("修改昵称", comment: "")
            hintLabel.stringValue = NSLocalizedString("昵称长度需为 1–50 个字符", comment: "")
            saveButton.setAccessibilityLabel(NSLocalizedString("保存昵称", comment: ""))
        case .email:
            titleLabel.stringValue = NSLocalizedString("修改邮箱", comment: "")
            hintLabel.stringValue = NSLocalizedString(
                "修改后可能需要重新验证新邮箱，并重新登录弹弹play账号。",
                comment: ""
            )
            saveButton.setAccessibilityLabel(NSLocalizedString("保存邮箱", comment: ""))
        case .password:
            titleLabel.stringValue = NSLocalizedString("修改密码", comment: "")
            hintLabel.stringValue = NSLocalizedString(
                "密码长度为 5–20 位；修改后可能需要使用新密码重新登录。",
                comment: ""
            )
            saveButton.setAccessibilityLabel(NSLocalizedString("保存密码", comment: ""))
        }
    }

    // MARK: - Actions

    @objc private func saveTapped() {
        guard !isSubmitting else { return }

        let submission: Submission
        do {
            submission = try validatedSubmission()
        } catch {
            showError(error.localizedDescription)
            return
        }

        errorLabel.isHidden = true
        setSubmitting(true)

        Task { @MainActor [weak self] in
            guard let self = self else { return }
            do {
                try await self.onSubmit?(submission)
                self.setSubmitting(false)
                self.presentingViewController?.dismiss(self)
            } catch {
                self.setSubmitting(false)
                self.showError(error.localizedDescription)
            }
        }
    }

    @objc private func cancelTapped() {
        guard !isSubmitting else { return }
        presentingViewController?.dismiss(self)
    }

    private func validatedSubmission() throws -> Submission {
        switch mode {
        case .screenName:
            let value = try AccountProfileValidator.screenName(screenNameField.stringValue)
            return .screenName(value)
        case .email:
            let values = try AccountProfileValidator.emailChange(
                old: oldEmailField.stringValue,
                new: newEmailField.stringValue
            )
            return .email(old: values.old, new: values.new)
        case .password:
            let values = try AccountProfileValidator.passwordChange(
                old: oldPasswordField.stringValue,
                new: newPasswordField.stringValue,
                confirmation: confirmPasswordField.stringValue
            )
            return .password(
                old: values.old,
                new: values.new,
                confirmation: confirmPasswordField.stringValue
            )
        }
    }

    private func setSubmitting(_ submitting: Bool) {
        isSubmitting = submitting
        saveButton.isEnabled = !submitting
        cancelButton.isEnabled = !submitting
        screenNameField.isEnabled = !submitting
        oldEmailField.isEnabled = !submitting
        newEmailField.isEnabled = !submitting
        oldPasswordField.isEnabled = !submitting
        newPasswordField.isEnabled = !submitting
        confirmPasswordField.isEnabled = !submitting
        saveButton.title = submitting
            ? NSLocalizedString("保存中…", comment: "")
            : NSLocalizedString("保存", comment: "")
        if submitting {
            spinner.startAnimation(nil)
        } else {
            spinner.stopAnimation(nil)
        }
    }

    private func showError(_ message: String) {
        errorLabel.stringValue = message
        errorLabel.isHidden = message.isEmpty
        errorLabel.setAccessibilityLabel(message)
    }
}
