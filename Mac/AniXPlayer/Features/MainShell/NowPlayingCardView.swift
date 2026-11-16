//
//  NowPlayingCardView.swift
//  AniXPlayer
//
//  macOS：主窗口顶栏的「正在播放」卡片。
//  只展示 PlayerNowPlayingCenter 的通知状态，不持有播放器。
//

import Cocoa
import SnapKit
import Kingfisher

private final class NowPlayingProgressLineView: NSView {

    var progress: Double = 0 {
        didSet { needsDisplay = true }
    }

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        wantsLayer = true
    }

    override func draw(_ dirtyRect: NSRect) {
        NSColor.white.withAlphaComponent(0.10).setFill()
        bounds.fill()

        guard progress > 0 else { return }
        let width = bounds.width * CGFloat(min(max(progress, 0), 1))
        NSColor.mainColor.setFill()
        NSRect(x: 0, y: 0, width: width, height: bounds.height).fill()
    }
}

private final class NowPlayingPlayPauseButton: NSButton {
    /// 主窗口不在前台时也能一次点击切换播放，不需要先激活窗口。
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }
}

final class NowPlayingCardView: WelcomeShellTapView {

    var onFocus: (() -> Void)?
    var onTogglePlay: (() -> Void)?

    private let artworkView = ImageView()
    private let titleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 11.5, weight: .semibold),
        color: .white
    )
    private let subtitleLabel = welcomeShellLabel(
        "",
        font: .systemFont(ofSize: 10),
        color: MainShellPalette.secondaryText
    )
    private let playPauseButton = NowPlayingPlayPauseButton()
    private let progressLine = NowPlayingProgressLineView()
    private var state = PlayerNowPlayingState.empty

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        return true
    }

    // MARK: - Setup

    private func setup() {
        normalBackground = NSColor.white.withAlphaComponent(0.06)
        layer?.cornerRadius = 7
        layer?.cornerCurve = .continuous
        layer?.borderWidth = 1
        borderColorProvider = { MainShellPalette.hairline }
        setAccessibilityIdentifier(AccessibilityID.MainShell.nowPlaying)
        setAccessibilityLabel(NSLocalizedString("未在播放", comment: ""))

        artworkView.setScaling(.aspectFill)
        artworkView.wantsLayer = true
        artworkView.layer?.cornerRadius = 6
        artworkView.layer?.cornerCurve = .continuous
        artworkView.layer?.masksToBounds = true
        artworkView.layer?.backgroundColor = NSColor.mainColor.withAlphaComponent(0.16).cgColor
        artworkView.contentTintColor = .mainColor

        titleLabel.lineBreakMode = .byTruncatingTail
        subtitleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        subtitleLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

        playPauseButton.isBordered = false
        playPauseButton.imagePosition = .imageOnly
        playPauseButton.imageScaling = .scaleProportionallyDown
        playPauseButton.focusRingType = .none
        playPauseButton.refusesFirstResponder = true
        playPauseButton.contentTintColor = .white
        playPauseButton.target = self
        playPauseButton.action = #selector(togglePlay)
        playPauseButton.setAccessibilityIdentifier(AccessibilityID.MainShell.nowPlayingPlayPause)
        playPauseButton.setAccessibilityLabel(NSLocalizedString("暂停", comment: ""))
        playPauseButton.toolTip = NSLocalizedString("暂停", comment: "")
        playPauseButton.isHidden = true

        addSubview(artworkView)
        addSubview(titleLabel)
        addSubview(subtitleLabel)
        addSubview(playPauseButton)
        addSubview(progressLine)

        artworkView.snp.makeConstraints { make in
            make.leading.equalToSuperview().offset(8)
            make.centerY.equalToSuperview().offset(-1)
            make.width.height.equalTo(22)
        }
        playPauseButton.snp.makeConstraints { make in
            make.trailing.equalToSuperview().offset(-7)
            make.centerY.equalToSuperview().offset(-1)
            make.width.height.equalTo(24)
        }
        titleLabel.snp.makeConstraints { make in
            make.leading.equalTo(artworkView.snp.trailing).offset(8)
            make.trailing.equalTo(playPauseButton.snp.leading).offset(-5)
            make.top.equalToSuperview().offset(5)
        }
        subtitleLabel.snp.makeConstraints { make in
            make.leading.trailing.equalTo(titleLabel)
            make.top.equalTo(titleLabel.snp.bottom).offset(0.5)
        }
        progressLine.snp.makeConstraints { make in
            make.leading.trailing.equalToSuperview().inset(8)
            make.bottom.equalToSuperview()
            make.height.equalTo(1.5)
        }
        snp.makeConstraints { make in
            make.height.equalTo(34)
        }

        onClick = { [weak self] in
            self?.onFocus?()
        }

        applyEmptyState()
    }

    // MARK: - State

    func update(state newState: PlayerNowPlayingState) {
        let previous = state
        guard previous != newState else { return }
        state = newState

        let mediaChanged = previous.hasMedia != newState.hasMedia
            || previous.title != newState.title
            || previous.subtitle != newState.subtitle
        let artworkChanged = previous.hasMedia != newState.hasMedia
            || previous.artworkURL != newState.artworkURL
        let playbackChanged = previous.isPlaying != newState.isPlaying

        if isTapEnabled != newState.hasMedia {
            isTapEnabled = newState.hasMedia
        }
        let shouldHidePlayButton = !newState.hasMedia
        if playPauseButton.isHidden != shouldHidePlayButton {
            playPauseButton.isHidden = shouldHidePlayButton
        }

        if newState.hasMedia {
            if mediaChanged {
                titleLabel.stringValue = newState.title
                subtitleLabel.stringValue = newState.subtitle
                subtitleLabel.isHidden = newState.subtitle.isEmpty

                let tooltipParts = [newState.title, newState.subtitle].filter { !$0.isEmpty }
                toolTip = tooltipParts.joined(separator: "\n")
                updateAccessibilityText(title: newState.title, subtitle: newState.subtitle)
            }
            if artworkChanged {
                updateArtwork(url: newState.artworkURL)
            }
            if playbackChanged || mediaChanged {
                updatePlayPauseButton(isPlaying: newState.isPlaying)
            }
        } else if mediaChanged {
            applyEmptyState()
        }

        progressLine.progress = newState.progress
    }

    private func updatePlayPauseButton(isPlaying: Bool) {
        let actionTitle = isPlaying
            ? NSLocalizedString("暂停", comment: "")
            : NSLocalizedString("播放", comment: "")
        playPauseButton.image = welcomeShellSymbol(
            isPlaying ? "pause.fill" : "play.fill",
            pointSize: 12,
            weight: .semibold
        )
        playPauseButton.setAccessibilityLabel(actionTitle)
        playPauseButton.toolTip = actionTitle
    }

    private func applyEmptyState() {
        titleLabel.stringValue = NSLocalizedString("未在播放", comment: "")
        subtitleLabel.stringValue = NSLocalizedString("打开视频后将在此显示", comment: "")
        subtitleLabel.isHidden = false
        toolTip = nil
        setAccessibilityLabel(NSLocalizedString("未在播放", comment: ""))
        resetArtwork()

        isTapEnabled = false
        playPauseButton.isHidden = true
        progressLine.progress = 0
    }

    private func updateAccessibilityText(title: String, subtitle: String) {
        let parts = [NSLocalizedString("正在播放", comment: ""), title]
            + (subtitle.isEmpty ? [] : [subtitle])
        setAccessibilityLabel(parts.joined(separator: "，"))
    }

    private func updateArtwork(url: URL?) {
        artworkView.kf.cancelDownloadTask()

        guard let url = url else {
            resetArtwork()
            return
        }

        if url.isFileURL {
            if let image = NSImage(contentsOf: url) {
                artworkView.contentTintColor = nil
                artworkView.image = image
            } else {
                resetArtwork()
            }
        } else {
            artworkView.contentTintColor = nil
            artworkView.kf.setImage(
                with: url,
                placeholder: Self.placeholderArtwork
            ) { [weak self] result in
                guard let self = self, case .failure = result else { return }
                self.artworkView.contentTintColor = .mainColor
                self.artworkView.image = Self.placeholderArtwork
            }
        }
    }

    private func resetArtwork() {
        artworkView.kf.cancelDownloadTask()
        artworkView.contentTintColor = .mainColor
        artworkView.image = Self.placeholderArtwork
    }

    private static let placeholderArtwork: NSImage? = {
        return welcomeShellSymbol("music.note", pointSize: 11, weight: .medium)
    }()

    @objc private func togglePlay() {
        onTogglePlay?()
    }
}
