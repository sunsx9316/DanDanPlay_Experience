//
//  TrendingCollectionViewCell.swift
//  AniXPlayer
//
//  macOS：排行榜海报卡片。
//

import Cocoa
import SnapKit

final class TrendingCollectionViewCell: AnimeListCollectionViewCell {

    private let rankLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .systemFont(ofSize: 18, weight: .bold)
        label.textColor = .mainColor
        return label
    }()

    private let metricLabel: Label = {
        let label = Label(labelWithString: "")
        label.font = .ddp_small()
        label.textColor = .subtitleTextColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        return label
    }()

    private let numberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 1
        formatter.minimumFractionDigits = 1
        return formatter
    }()

    static func estimatedHeight(for width: CGFloat) -> CGFloat {
        return width * 1.4 + 104
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        infoStackView.insertArrangedSubview(rankLabel, at: 0)
        infoStackView.addArrangedSubview(metricLabel)
        rankLabel.setContentHuggingPriority(.required, for: .vertical)
        metricLabel.setContentHuggingPriority(.required, for: .vertical)
    }

    func update(trending: TrendingItem, mode: TrendingMetricMode) {
        update(item: trending, ratingNumberFormatter: numberFormatter)

        rankLabel.text = trending.rank > 0 ? "#\(trending.rank)" : ""

        switch mode {
        case .rising:
            let delta = trending.heatDelta.isEmpty ? trending.heat : trending.heatDelta
            let growth = trending.heatGrowthRate.isEmpty ? trending.previousHeat : trending.heatGrowthRate
            metricLabel.text = [
                delta.isEmpty ? nil : NSLocalizedString("热度增长 ", comment: "") + delta,
                growth.isEmpty ? nil : NSLocalizedString("增长率 ", comment: "") + growth,
            ].compactMap { $0 }.joined(separator: " · ")
        default:
            let heat = trending.heat.isEmpty ? "-" : trending.heat
            let days = trending.activeDays > 0
                ? String(format: NSLocalizedString("活跃 %d 天", comment: ""), trending.activeDays)
                : ""
            metricLabel.text = NSLocalizedString("热度 ", comment: "") + heat + (days.isEmpty ? "" : " · " + days)
        }
    }
}
