//
//  BangumiDetailMetadataCardView.swift
//  AniXPlayer
//
//  macOS：详情页的作品资料 key-value 卡片。
//

import Cocoa
import SnapKit

final class BangumiDetailMetadataCardView: BangumiDetailCardView {

    var onViewAll: (() -> Void)?

    private let fieldsStack: NSStackView = {
        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .width
        stack.spacing = 7
        return stack
    }()

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setup()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setup()
    }

    func configure(with item: BangumiDetail) {
        fieldsStack.arrangedSubviews.forEach {
            fieldsStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        for field in makeFields(from: item) {
            fieldsStack.addArrangedSubview(BangumiDetailMetadataRowView(key: field.key, value: field.value))
        }
    }

    // MARK: - Private

    private func setup() {
        setAccessibilityIdentifier(AccessibilityID.BangumiDetail.metadata)
        let header = addHeader(
            title: NSLocalizedString("作品资料", comment: ""),
            symbolName: "info.circle",
            identifier: AccessibilityID.BangumiDetail.metadataHeader,
            onTap: { [weak self] in
                self?.onViewAll?()
            }
        )
        header.trailingStack.addArrangedSubview(makeViewAllButton(
            identifier: AccessibilityID.BangumiDetail.metadataViewAll,
            onTap: { [weak self] in
                self?.onViewAll?()
            }
        ))
        contentStack.addArrangedSubview(fieldsStack)
    }

    private func makeFields(from item: BangumiDetail) -> [(key: String, value: String)] {
        var fields: [(String, String)] = []

        let typeName = item.typeDescription.isEmpty ? item.type.displayName : item.typeDescription
        if !typeName.isEmpty {
            fields.append((NSLocalizedString("类型", comment: ""), typeName))
        }

        fields.append((
            NSLocalizedString("状态", comment: ""),
            item.isOnAir ? NSLocalizedString("连载中", comment: "") : NSLocalizedString("已完结", comment: "")
        ))

        if !item.episodes.isEmpty || !item.seasons.isEmpty {
            var episodeText = String(
                format: NSLocalizedString("%d 集", comment: ""),
                item.episodes.count
            )
            if item.seasons.count > 1 {
                episodeText += " · " + String(
                    format: NSLocalizedString("%d 季", comment: ""),
                    item.seasons.count
                )
            }
            fields.append((NSLocalizedString("集数", comment: ""), episodeText))
        }

        var airParts: [String] = []
        if item.isOnAir, (0...6).contains(item.airDay) {
            airParts.append(WelcomeShellDataMapper.weekdayTitle(for: item.airDay))
        }
        if let firstAirDate = item.episodes.compactMap({ $0.airDate }).min() {
            airParts.append(String(
                format: NSLocalizedString("首播 %@", comment: ""),
                BangumiDetailDateFormatter.day.string(from: firstAirDate)
            ))
        }
        if !airParts.isEmpty {
            fields.append((NSLocalizedString("放送", comment: ""), airParts.joined(separator: " · ")))
        }

        if item.rating > 0 {
            fields.append((
                NSLocalizedString("评分", comment: ""),
                String(format: "%.1f / 10", item.rating)
            ))
        } else {
            fields.append((NSLocalizedString("评分", comment: ""), NSLocalizedString("暂无评分", comment: "")))
        }

        let sourceRatings = item.ratingDetails.items
            .filter { !$0.source.isEmpty && $0.rating > 0 }
            .sorted { $0.source.localizedCaseInsensitiveCompare($1.source) == .orderedAscending }
            .map { String(format: "%@ %.1f", $0.source, $0.rating) }
        if !sourceRatings.isEmpty {
            fields.append((NSLocalizedString("站点评分", comment: ""), sourceRatings.joined(separator: " · ")))
        }

        let bangumiId = item.bangumiId.trimmingCharacters(in: .whitespacesAndNewlines)
        let identifier = (bangumiId.isEmpty || bangumiId == "0") ? "\(item.animeId)" : bangumiId
        fields.append((NSLocalizedString("作品 ID", comment: ""), identifier))

        return fields
    }
}

// MARK: - Row

private final class BangumiDetailMetadataRowView: NSView {

    private let keyLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12)
        label.textColor = .tertiaryLabelColor
        label.alignment = .left
        label.setContentHuggingPriority(.required, for: .horizontal)
        label.setContentCompressionResistancePriority(.required, for: .horizontal)
        return label
    }()

    private let valueLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 12.5)
        label.textColor = .labelColor
        label.maximumNumberOfLines = 2
        label.lineBreakMode = .byTruncatingTail
        label.cell?.wraps = true
        return label
    }()

    init(key: String, value: String) {
        super.init(frame: .zero)
        keyLabel.text = key
        valueLabel.text = value

        addSubview(keyLabel)
        addSubview(valueLabel)

        keyLabel.snp.makeConstraints { make in
            make.leading.top.equalToSuperview()
            make.width.equalTo(64)
        }
        valueLabel.snp.makeConstraints { make in
            make.leading.equalTo(keyLabel.snp.trailing).offset(12)
            make.top.trailing.equalToSuperview()
            make.bottom.equalToSuperview()
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
