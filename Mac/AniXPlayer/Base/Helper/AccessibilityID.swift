//
//  AccessibilityID.swift
//  AniXPlayer
//
//  统一的 accessibilityIdentifier 常量。
//  XCUITest / AX 脚本都从这里取值，避免字符串散落导致测试找不到控件。
//

import Foundation

enum AccessibilityID {
    enum Launch {
        static let root = "launch.root"
        static let openButton = "launch.openButton"
        static let dragArea = "launch.dragArea"
        static let recentHeader = "launch.recentHeader"
        static let recentList = "launch.recentList"
        static let homeButton = "launch.homeButton"
        static let settingsButton = "launch.settingsButton"
    }

    enum Player {
        static let root = "player.root"
        static let mediaView = "player.mediaView"
        static let danmakuCanvas = "player.danmakuCanvas"
        static let controls = "player.controls"
        static let titleLabel = "player.titleLabel"
        static let progressSlider = "player.progressSlider"
        static let playPauseButton = "player.playPauseButton"
        static let stopButton = "player.stopButton"
        static let nextButton = "player.nextButton"
        static let timeLabel = "player.timeLabel"
        static let danmakuTextField = "player.danmakuTextField"
        static let danmakuConfigButton = "player.danmakuConfigButton"
        static let danmakuSettingButton = "player.danmakuSettingButton"
        static let mediaSettingButton = "player.mediaSettingButton"
        static let playerListButton = "player.playerListButton"
        static let screenshotButton = "player.screenshotButton"
        static let miniProgressSlider = "player.miniProgressSlider"
    }

    enum Login {
        static let window = "login.window"
        static let webView = "login.webView"
    }

    enum Home {
        static let root = "home.root"
        static let banner = "home.banner"
        static let pageIndicator = "home.pageIndicator"
        static let functionArea = "home.functionArea"
        static let timelineButton = "home.timelineButton"
        static let favoritesButton = "home.favoritesButton"
        static let queueHeader = "home.queueHeader"
        static let queueList = "home.queueList"
    }

    enum Membership {
        static let window = "membership.window"
        static let statusCard = "membership.statusCard"
        static let avatar = "membership.avatar"
        static let memberNameLabel = "membership.memberNameLabel"
        static let memberUserNameLabel = "membership.memberUserNameLabel"
        static let memberStatusLabel = "membership.memberStatusLabel"
        static let memberDetailLabel = "membership.memberDetailLabel"
        static let featureBanner = "membership.featureBanner"
        static let sectionControl = "membership.sectionControl"
        static let providerPopup = "membership.providerPopup"
        static let itemPopup = "membership.itemPopup"
        static let priceLabel = "membership.priceLabel"
        static let payButton = "membership.payButton"
        static let paymentPanel = "membership.paymentPanel"
        static let paymentProviderLabel = "membership.paymentProviderLabel"
        static let paymentAmountLabel = "membership.paymentAmountLabel"
        static let paymentTitleLabel = "membership.paymentTitleLabel"
        static let paymentStatusLabel = "membership.paymentStatusLabel"
        static let paymentNoteLabel = "membership.paymentNoteLabel"
        static let countdownLabel = "membership.countdownLabel"
        static let qrCodeImage = "membership.qrCodeImage"
        static let openWebButton = "membership.openWebButton"
        static let cancelPaymentButton = "membership.cancelPaymentButton"
        static let redeemField = "membership.redeemField"
        static let pasteButton = "membership.pasteButton"
        static let redeemButton = "membership.redeemButton"
        static let redeemStatusLabel = "membership.redeemStatusLabel"
        static let redeemHistoryList = "membership.redeemHistoryList"
        static let historyRedeemList = "membership.historyRedeemList"
        static let orderList = "membership.orderList"
        static let historyReloadButton = "membership.historyReloadButton"
        static let historyStatusLabel = "membership.historyStatusLabel"
        static let introTextView = "membership.introTextView"
    }

    enum Translation {
        static let window = "translation.window"
        static let chooseFileButton = "translation.chooseFileButton"
        static let servicePopup = "translation.servicePopup"
        static let fromLanguagePopup = "translation.fromLanguagePopup"
        static let toLanguagePopup = "translation.toLanguagePopup"
        static let modePopup = "translation.modePopup"
        static let translateButton = "translation.translateButton"
        static let cancelButton = "translation.cancelButton"
        static let exportButton = "translation.exportButton"
        static let progress = "translation.progress"
        static let previewTable = "translation.previewTable"
        static let statusLabel = "translation.statusLabel"
    }

    enum Summary {
        static let window = "summary.window"
        static let textView = "summary.textView"
        static let generateButton = "summary.generateButton"
        static let copyButton = "summary.copyButton"
        static let statusLabel = "summary.statusLabel"
    }
}
