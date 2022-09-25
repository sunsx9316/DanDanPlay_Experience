//
//  PlayerViewController.swift
//  AniXPlayer
//
//  Created by jimhuang on 2022/9/8.
//

import Cocoa
import SnapKit
import DanmakuRender
import Carbon

private class PlayItem {
    
    var watchProgressKey: String? {
        return episodeId == 0 ? nil : "\(episodeId)"
    }
    
    private let media: File
    var playImmediately = false
    var mediaId: String {
        return self.media.url.path
    }
    
    var episodeId = 0
    
    init(item: File) {
        self.media = item
    }
}

class PlayerViewController: ViewController {
    
    private let kShortJumpValue: Int32 = 5
    
    private let kVolumeAddingValue: CGFloat = 20
    
    private lazy var dragView: DragView = {
        let view = DragView()
        view.dragFilesCallBack = { [weak self] urls in
            guard let self = self else { return }
            
            self.openURLs(urls)
        }
            
        return view
    }()
    
    private lazy var uiView: PlayerUIView = {
        let view = PlayerUIView()
        view.delegate = self
        view.dataSource = self
        
        let trackingArea = NSTrackingArea(rect: self.view.bounds, options: [.activeInKeyWindow, .mouseMoved, .inVisibleRect, .mouseEnteredAndExited], owner: self, userInfo: nil)
        view.addTrackingArea(trackingArea)
        
        return view
    }()
    
    private lazy var containerView: NSView = {
        let view = BaseView()
        return view
    }()
    
    private lazy var danmakuRender: DanmakuEngine = {
        let danmakuRender = DanmakuEngine()
        danmakuRender.layoutStyle = .nonOverlapping
        danmakuRender.offsetTime = TimeInterval(Preferences.shared.danmakuOffsetTime)
        return danmakuRender
    }()
    
    /// 弹幕画布容器
    @objc private lazy var danmakuCanvas: NSView = {
        let view = BaseView()
        view.wantsLayer = true
        view.alphaValue = CGFloat(Preferences.shared.danmakuAlpha)
        view.isHidden = !Preferences.shared.isShowDanmaku
        return view
    }()
    
    private lazy var player: MediaPlayer = {
        let player = MediaPlayer()
        player.delegate = self
        return player
    }()
    
    private var playItemMap = [URL : PlayItem]()
    //当前弹幕时间/弹幕数组映射
    private var danmakuDic = [UInt : [DanmakuConverResult]]()
    
    /// 当前弹幕的时间
    private var danmakuTime: UInt?
    
    /// 弹幕字体
    private lazy var danmakuFont = NSFont.systemFont(ofSize: CGFloat(Preferences.shared.danmakuFontSize))
    
    private var matchWindowController: WindowController?
    
    //MARK: - life cycle
    
    deinit {
        self.storeProgress()
        self.closeMatchWindow()
    }

    override func viewWillDisappear() {
        super.viewWillDisappear()

        if self.player.isPlaying {
            self.player.pause()
        }
        
        self.storeProgress()
    }
    
    override func loadView() {
        self.view = .init(frame: .init(x: 0, y: 0, width: 800, height: 600))
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.wantsLayer = true
        self.view.addSubview(self.dragView)
        self.dragView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.view.addSubview(self.containerView)
        self.containerView.addSubview(self.player.mediaView)
        self.containerView.addSubview(self.danmakuCanvas)
        self.danmakuCanvas.addSubview(self.danmakuRender.canvas)
        self.view.addSubview(self.uiView)
        
        self.containerView.snp.makeConstraints { (make) in
            make.edges.equalToSuperview()
        }
        
        self.player.mediaView.frame = self.view.bounds
        self.player.mediaView.autoresizingMask = [.maxYMargin, .maxXMargin, .width, .height]
        
        self.uiView.snp.makeConstraints { make in
            make.edges.equalToSuperview()
        }
        
        self.layoutDanmakuCanvas()
        self.uiView.autoShowControlView()
        self.playerListDidChange(self.player)
        self.changeRepeatMode()
        self.setupMenu()
    }
    
    override func mouseMoved(with event: NSEvent) {
        super.mouseMoved(with: event)
        
        self.uiView.autoShowControlView()
    }
    
    override func keyDown(with event: NSEvent) {
        let keyCode = Int(event.keyCode)
        
        switch keyCode {
        case kVK_Tab:
            break
        case kVK_Return:
            self.onToggleFullScreen()
        case kVK_Space:
            self.onClickPlayButton()
        case kVK_LeftArrow, kVK_RightArrow:
            let jumpTime = keyCode == kVK_LeftArrow ? TimeInterval(-kShortJumpValue) : TimeInterval(kShortJumpValue)
            let position = self.player.length == 0 ? 0 : (self.player.currentTime + jumpTime) / self.player.length
            self.setPlayerProgress(CGFloat(position))
        case kVK_UpArrow, kVK_DownArrow:
            let volumeValue = keyCode == kVK_DownArrow ? -kVolumeAddingValue : kVolumeAddingValue
            changeVolume(volumeValue)
        default:
            super.keyDown(with: event)
        }
    }
    
    //MARK: - Private
    private func loadItems(_ items: [File]) {
        for item in items {
            
            if item.type == .folder {
                continue
            }
            
            let url = item.url
            if self.playItemMap[url] == nil {
                let playItem = PlayItem(item: item)
                self.playItemMap[url] = playItem
                self.player.addMediaToPlayList(item)
            }
        }
    }
    
    private func changeVolume(_ addBy: CGFloat) {
        self.player.volume += Int(addBy)
    }
    
    private func findPlayItem(_ protocolItem: File) -> PlayItem? {
        if let protocolItem = protocolItem as? PlayItem {
            return protocolItem
        }
        
        return self.playItemMap[protocolItem.url]
    }
    
    private func changeRepeatMode() {
        switch Preferences.shared.playerMode {
        case .notRepeat:
            player.playMode = .autoPlayNext
        case .repeatAllItem:
            player.playMode = .repeatList
        case .repeatCurrentItem:
            player.playMode = .repeatCurrentItem
        }
    }
    
    private func setPlayerProgress(_ progress: CGFloat) {
        let currentTime = self.player.setPosition(Double(progress))
        self.danmakuRender.time = currentTime
        self.uiView.updateTime()
    }
    
    private func tryParseMedia(_ media: File) {
        
        self.storeProgress()
        
        self.player.stop()
        
        self.uiView.title = media.fileName
        
        let hud = self.view.showProgress(NSLocalizedString("解析视频中...", comment: ""))
        hud.progress = 0
        
        NetworkManager.shared.danmakuWithFile(media) { (progress) in
            DispatchQueue.main.async {
                hud.progress = Double(Float(progress))
                if progress == 0.7 {
                    hud.setStatus(NSLocalizedString("加载弹幕中...", comment: ""))
                }
            }
        } matchCompletion: { (collection, error) in
            DispatchQueue.main.async {
                hud.hide(true, dismissAfterDelay: 2)
                
                if let error = error {
                    self.view.showError(error)
                } else if let collection = collection {
                    self.popMatchWindowController(with: collection, file: media)
                }
            }
        } danmakuCompletion: { (collection, episodeId, error) in
            DispatchQueue.main.async {
                hud.hide(true)
                
                if let error = error {
                    self.view.showError(error)
                } else {
                    let danmakus = collection?.collection ?? []
                    self.playMedia(media, episodeId: episodeId, danmakus: danmakus)
                }
            }
        }
    }
    
    
    /// 播放视频
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 弹幕分集id
    ///   - danmakus: 弹幕
    private func playMedia(_ media: File, episodeId: Int, danmakus: [Comment]) {
        
        if Preferences.shared.autoLoadCustomDanmaku {
            self.loadCustomDanmaku(media) { isSuccess, result in
                if isSuccess, let result = result {
                    self.startPlay(media, episodeId: episodeId, danmakus: result)
                    self.loadCustomSubtitle(media)
                } else {
                    self.startPlay(media, episodeId: episodeId, danmakus: DanmakuManager.shared.conver(danmakus))
                    self.loadCustomSubtitle(media)
                }
            }
        } else {
            self.startPlay(media, episodeId: episodeId, danmakus: DanmakuManager.shared.conver(danmakus))
            self.loadCustomSubtitle(media)
        }
        
    }
    
    /// 加载本地弹幕
    /// - Parameters:
    ///   - media: 视频
    ///   - completion: 完成回调
    private func loadCustomDanmaku(_ media: File, completion: @escaping((Bool, [UInt : [DanmakuConverResult]]?) -> Void)) {
            DanmakuManager.shared.findCustomDanmakuWithMedia(media) { [weak self] result in
                guard let self = self else { return }
                
                switch result {
                case .success(let files):
                    if files.isEmpty {
                        DispatchQueue.main.async {
                            //没有匹配到本地弹幕
                            completion(false, nil)
                        }
                        return
                    }
                    
                    DanmakuManager.shared.downCustomDanmaku(files[0]) { [weak self] result1 in
                        
                        guard let self = self else { return }
                        
                        switch result1 {
                        case .success(let url):
                            do {
                                let converResult = try DanmakuManager.shared.conver(url)
                                DispatchQueue.main.async {
                                    completion(true, converResult)
                                    self.view.showHUD(NSLocalizedString("加载本地弹幕成功！", comment: ""))
                                }
                            } catch {
                                DispatchQueue.main.async {
                                    completion(false, nil)
                                    self.view.showError(error)
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                completion(false, nil)
                                self.view.showError(error)
                            }
                        }
                    }
                case .failure(let error):
                    DispatchQueue.main.async {
                        completion(false, nil)
                        self.view.showError(error)
                    }
                }
            }
    }
    
    /// 开始播放
    /// - Parameters:
    ///   - media: 视频
    ///   - episodeId: 弹幕分级id
    ///   - danmakus: 弹幕
    private func startPlay(_ media: File, episodeId: Int, danmakus: [UInt : [DanmakuConverResult]]) {
        
        self.danmakuDic = danmakus
        self.danmakuRender.time = 0
        self.danmakuTime = nil
        self.player.play(media)
        
        var frame = self.player.mediaView.frame
        frame.size.width -= 1
        frame.size.height -= 1
        self.player.mediaView.frame = frame
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            self.player.mediaView.frame = self.view.bounds
        }
        
        //定位上次播放的位置
        if let playItem = self.findPlayItem(media) {
            playItem.episodeId = episodeId
            if let watchProgressKey = playItem.watchProgressKey,
               let lastWatchProgress = HistoryManager.shared.watchProgress(mediaKey: watchProgressKey) {
                
                if lastWatchProgress > 0 {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        
                        func lastTimeString() -> String {
                            let timeFormatter = DateFormatter()
                            timeFormatter.dateFormat = "mm:ss"
                            return timeFormatter.string(from: Date(timeIntervalSince1970: self.player.length * lastWatchProgress))
                        }
                        
                        let customView = GotoLastWatchPointView()
                        customView.timeString = NSLocalizedString("上次观看时间：", comment: "") + lastTimeString()
                        customView.didClickGotoButton = { [weak self] in
                            guard let self = self else { return }
                            
                            self.setPlayerProgress(lastWatchProgress)
                            self.uiView.autoShowControlView()
                        }
                        
                        customView.show(from: self.view)
                    }
                }
            }
        }
    }
    
    /// 加载本地字幕
    /// - Parameter media: 视频
    private func loadCustomSubtitle(_ media: File) {
        SubtitleManager.shared.findCustomSubtitleWithMedia(media) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let files):
                if files.isEmpty {
                    return
                }
                
                var subtitleFile = files[0]
                
                //按照优先级加载字幕
                if let subtitleLoadOrder = Preferences.shared.subtitleLoadOrder {
                    for keyName in subtitleLoadOrder {
                        if let matched = files.first(where: { $0.fileName.contains(keyName) }) {
                            subtitleFile = matched
                            break
                        }
                    }
                }
                
                SubtitleManager.shared.downCustomSubtitle(subtitleFile) { result1 in
                    switch result1 {
                    case .success(let subtitle):
                    DispatchQueue.main.async {
                        self.player.currentSubtitle = subtitle
                        self.view.showHUD(NSLocalizedString("加载本地字幕成功！", comment: ""))
                    }
                    case .failure(let error):
                        DispatchQueue.main.async {
                            self.view.showError(error)
                        }
                    }
                }
            case .failure(let error):
                DispatchQueue.main.async {
                    self.view.showError(error)
                }
            }
        }
    }
    
    private func popMatchWindowController(with collection: MatchCollection?, file: File) {
        
        self.matchWindowController?.close()
        
        let vc: MatchsViewController
        
        if let collection = collection {
            vc = .init(with: collection, file: file)
        } else {
            vc = MatchsViewController(file: file)
        }
        
        vc.delegate = self
        
        self.matchWindowController = WindowController()
        self.matchWindowController?.contentViewController = vc
        self.matchWindowController?.showAtCenter(self.view.window)
        self.matchWindowController?.window?.title = vc.title ?? ""
        self.matchWindowController?.window?.level = .floating
        self.matchWindowController?.windowWillCloseCallBack = { [weak self] in
            guard let self = self else { return }
            
            self.matchWindowController = nil
        }
    }
    
    //保存观看记录
    private func storeProgress() {
        if let currentPlayItem = self.player.currentPlayItem,
           let playItem = self.findPlayItem(currentPlayItem),
            let watchProgressKey = playItem.watchProgressKey {
            
            let position = self.player.position
            //播放结束不保存进度
            if position >= 0.99 {
                HistoryManager.shared.cleanWatchProgress(mediaKey: watchProgressKey)
            } else {
                HistoryManager.shared.storeWatchProgress(mediaKey: watchProgressKey, progress: position)
            }
        }
    }
    
    /// 调整播放器和弹幕整体
    /// - Parameter speed: 速度
    private func changeSpeed(_ speed: Double) {
        self.player.speed = speed
        self.danmakuRender.speed = speed
    }
    
    /// 重新布局弹幕画布
    private func layoutDanmakuCanvas() {
        self.danmakuCanvas.snp.remakeConstraints { (make) in
            make.top.leading.trailing.equalTo(self.containerView)
            if Preferences.shared.subtitleSafeArea {
                make.height.equalTo(self.containerView).multipliedBy(0.85)
            } else {
                make.height.equalTo(self.containerView)
            }
        }
        
        self.danmakuRender.canvas.snp.remakeConstraints { make in
            make.top.leading.trailing.equalToSuperview()
            let danmakuProportion = Preferences.shared.danmakuProportion
            make.height.equalToSuperview().multipliedBy(danmakuProportion)
        }
    }
    
    private func onToggleFullScreen() {
        let window = view.window
        window?.collectionBehavior = .fullScreenPrimary
        window?.toggleFullScreen(nil)
    }
    
    private func onClickPlayButton() {
        if self.player.isPlaying {
            self.player.pause()
        } else {
            self.player.play()
        }
    }
    
    private func dismissPresented() {
        let presentedViewControllers = self.presentedViewControllers
        if presentedViewControllers?.isEmpty == false {
            presentedViewControllers?.forEach({ vc in
                vc.dismiss(nil)
            })
        }
    }
    
    private func closeMatchWindow() {
        self.matchWindowController?.close()
        self.matchWindowController = nil
    }
    
    private func setupMenu() {
        let fileItem = NSMenuItem(title: NSLocalizedString("打开...", comment: ""), action: #selector(pickFile), keyEquivalent: "n")
        fileItem.target = self
        NSApp.appDelegate?.fileMenu?.addItem(fileItem)
        
        NSApp.appDelegate?.fileMenu?.addItem(NSMenuItem.separator())
        
    }
    
    /// 文件拾取器
    @objc private func pickFile() {
        
        let currentPlayItem = self.player.currentPlayItem ?? LocalFile.rootFile

        type(of: currentPlayItem).fileManager.pickFiles(currentPlayItem.parentFile, from: self, filterType: .all) { [weak self] result in
            guard let self = self else { return }
            
            switch result {
            case .success(let files):
                
                if files.count == 1 && files[0].url.isSubtitleFile {
                    SubtitleManager.shared.downCustomSubtitle(files[0]) { [weak self] result1 in
                        guard let self = self else { return }
                        
                        switch result1 {
                        case .success(let subtitle):
                            DispatchQueue.main.async {
                                self.player.currentSubtitle = subtitle
                                self.view.showHUD(NSLocalizedString("加载本地字幕成功！", comment: ""))
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.view.showError(error)
                            }
                        }
                    }
                } else if files.count == 1 && files[0].url.isDanmakuFile {
                    DanmakuManager.shared.downCustomDanmaku(files[0]) { [weak self] result1 in
                        
                        guard let self = self else { return }
                        
                        switch result1 {
                        case .success(let url):
                            do {
                                let converResult = try DanmakuManager.shared.conver(url)
                                DispatchQueue.main.async {
                                    self.danmakuDic = converResult
                                    self.view.showHUD(NSLocalizedString("加载本地弹幕成功！", comment: ""))
                                }
                            } catch let error {
                                DispatchQueue.main.async {
                                    self.view.showError(error)
                                }
                            }
                        case .failure(let error):
                            DispatchQueue.main.async {
                                self.view.showError(error)
                            }
                        }
                    }
                } else {
                    self.openURLs(files)
                }
            case .failure(_):
                break
            }
            
        }
    }
    
    @objc private func openDanmakuFiles(_ item: NSMenuItem) {
        
    }
    
    /// 批量加载url
    /// - Parameter urls: url集合
    private func openURLs(_ files: [File]) {
        self.loadItems(files)
        if !files.isEmpty &&
            self.player.playList.contains(where: { $0.url == files.first?.url }) {
            self.tryParseMedia(files[0])
        }
    }
}

// MARK: - MatchsViewControllerDelegate
extension PlayerViewController: MatchsViewControllerDelegate {
    
    func matchsViewController(_ matchsViewController: MatchsViewController, didSelectedEpisodeId episodeId: Int) {
        
        self.closeMatchWindow()
        
        let hud = self.view.showProgress()
        hud.setStatus(NSLocalizedString("加载弹幕中...", comment: ""))
        hud.progress = 0.5

        NetworkManager.shared.danmakuWithEpisodeId(episodeId) { [weak self] (collection, error) in
            
            guard let self = self else { return }
            
            if let error = error {
                DispatchQueue.main.async {
                    hud.progress = 1
                    hud.hide(true)
                    self.view.showError(error)
                }
            } else {
                let danmakus = collection?.collection ?? []
                DispatchQueue.main.async {
                    hud.setStatus(NSLocalizedString("即将开始播放", comment: ""))
                    hud.progress = 1
                    hud.hide(true, dismissAfterDelay: 0.5)
                    self.playMedia(matchsViewController.file, episodeId: episodeId, danmakus: danmakus)
                }
            }
        }
    }
    
    func playNowInMatchsViewController(_ matchsViewController: MatchsViewController) {
        self.closeMatchWindow()
        self.playMedia(matchsViewController.file, episodeId: 0, danmakus: [])
    }
}

// MARK: - PlayerUIViewDataSource
extension PlayerViewController: PlayerUIViewDataSource {
    func playerMediaThumbnailer(playerUIView: PlayerUIView) -> MediaThumbnailer? {
        return self.player.mediaThumbnailer
    }
    
    func playerCurrentTime(playerUIView: PlayerUIView) -> TimeInterval {
        return player.currentTime
    }
    
    func playerTotalTime(playerUIView: PlayerUIView) -> TimeInterval {
        return player.length
    }
    
    func playerProgress(playerUIView: PlayerUIView) -> CGFloat {
        return CGFloat(player.position)
    }
}

// MARK: - PlayerUIViewDelegate
extension PlayerViewController: PlayerUIViewDelegate {
    
    func openButtonDidClick(playerUIView: PlayerUIView, button: NSButton) {
        self.pickFile()
    }
    
    func onTouchDanmakuSettingButton(playerUIView: PlayerUIView, button: NSButton) {
        self.dismissPresented()
        
        let vc = DanmakuSettingViewController()
        vc.delegate = self
        
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func onTouchMediaSettingButton(playerUIView: PlayerUIView, button: NSButton) {
        self.dismissPresented()
        
        let vc = MediaSettingViewController(player: self.player)
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func playerUIView(_ playerUIView: PlayerUIView, didChangeControlViewState show: Bool) {
        
    }
    
    func onTouchPlayerList(playerUIView: PlayerUIView, button: NSButton) {
        self.dismissPresented()
        
        let vc = PlayerListViewController()
        vc.delegate = self
        self.present(vc, asPopoverRelativeTo: .zero, of: button, preferredEdge: .minY, behavior: .transient)
    }
    
    func onTouchDanmakuSwitch(playerUIView: PlayerUIView, isOn: Bool) {
        self.danmakuCanvas.isHidden = !isOn
    }
    
    func onTouchSendDanmakuButton(playerUIView: PlayerUIView) {
        guard let item = self.player.currentPlayItem,
              self.findPlayItem(item)?.episodeId != nil else {
            self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
            return
        }
        
//        let vc = SendDanmakuViewController()
//        vc.onTouchSendButtonCallBack = { [weak self] (text, aVC) in
//            guard let self = self else { return }
//
//            guard let item = self.player.currentPlayItem,
//                  let _ = self.findPlayItem(item)?.episodeId else {
//
//                self.view.showHUD("需要指定视频弹幕列表，才能发弹幕哟~")
//                return
//            }
//
////            if !text.isEmpty {
////                let danmaku = DanmakuModel()
////                danmaku.mode = .normal
////                danmaku.time = self.danmakuRender.currentTime + self.danmakuRender.offsetTime
////                danmaku.message = text
////                danmaku.id = "\(Date().timeIntervalSince1970)"
////
////                let msg = SendDanmakuMessage()
////                msg.danmaku = danmaku
////                msg.episodeId = episodeId
////                #warning("待处理")
//////                MessageHandler.sendMessage(msg)
////
//////                self.danmakuRender.sendDanmaku(DanmakuManager.shared.conver(danmaku))
////            }
//
//            aVC.navigationController?.popViewController(animated: true)
//        }
//        self.navigationController?.pushViewController(vc, animated: true)
    }
    
    func onTouchPlayButton(playerUIView: PlayerUIView, isSelected: Bool) {
        self.onClickPlayButton()
    }
    
    func onTouchNextButton(playerUIView: PlayerUIView) {
        if let index = self.player.playList.firstIndex(where: { $0.url == self.player.currentPlayItem?.url }) {
            if index != self.player.playList.count - 1 {
                let item = self.player.playList[index + 1]
                self.tryParseMedia(item)
            }
        }
    }
    
    func doubleTap(playerUIView: PlayerUIView) {
        onToggleFullScreen()
    }
    
    func tapSlider(playerUIView: PlayerUIView, progress: CGFloat) {
        self.setPlayerProgress(progress)
    }
    
    func changeProgress(playerUIView: PlayerUIView, diffValue: CGFloat) {
        let length = self.player.length
        if length > 0 {
            let progress = (CGFloat(self.player.currentTime) + diffValue) / CGFloat(length)
            self.setPlayerProgress(progress)
        }
    }
}

// MARK: - PlayerListViewControllerDelegate
extension PlayerViewController: PlayerListViewControllerDelegate {
    func numberOfRowAtPlayerListViewController() -> Int {
        return self.player.playList.count
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, titleAtRow: Int) -> String {
        return self.player.playList[titleAtRow].fileName
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didSelectedRow: Int) {
        self.dismissPresented()
        
        let file = self.player.playList[didSelectedRow]
        self.tryParseMedia(file)
    }
    
    func playerListViewController(_ viewController: PlayerListViewController, didDeleteRowIndexSet: IndexSet) {
        for row in didDeleteRowIndexSet {
            let file = self.player.playList[row]
            self.player.removeMediaFromPlayList(file)
        }
    }
    
    func currentPlayIndexAtPlayerListViewController(_ viewController: PlayerListViewController) -> Int? {
        return self.player.playList.firstIndex(where: { $0.url == self.player.currentPlayItem?.url })
    }
}

//MARK: - MediaPlayerDelegate
extension PlayerViewController: MediaPlayerDelegate {
    
    func playerListDidChange(_ player: MediaPlayer) {
        self.uiView.showOpenButton = player.playList.isEmpty
    }
    
    func player(_ player: MediaPlayer, stateDidChange state: MediaPlayer.State) {
        switch state {
        case .playing:
            danmakuRender.start()
            self.uiView.isPlay = true
        case .pause, .stop:
            danmakuRender.pause()
            self.uiView.isPlay = false
        }
    }
    
    func player(_ player: MediaPlayer, shouldChangeMedia media: File) -> Bool {
        
        self.tryParseMedia(media)
        
        return false
    }
    
    func player(_ player: MediaPlayer, mediaDidChange media: File?) {
        
        
    }
    
    func player(_ player: MediaPlayer, currentTime: TimeInterval, totalTime: TimeInterval) {
        uiView.updateTime()
        
        let danmakuRenderTime = self.danmakuRender.time
        
        if danmakuRenderTime < 0 {
            return
        }
        
        let intTime = UInt(danmakuRenderTime)
        if intTime == self.danmakuTime {
            return
        }
        
        self.danmakuTime = intTime
        if let danmakus = danmakuDic[intTime] {
            let danmakuDensity = Preferences.shared.danmakuDensity
            for danmakuBlock in danmakus {
                /// 小于弹幕密度才允许发射
                let shouldSendDanmaku = Float.random(in: 0...10) <= danmakuDensity
                if shouldSendDanmaku {
                    let danmaku = danmakuBlock()
                    //修复因为时间误差的问题，导致少数弹幕突然出现在屏幕上的问题
                    danmaku.appearTime = (danmaku.appearTime - Double(intTime)) + danmakuRenderTime
                    self.danmakuRender.send(danmaku)
                }
            }
        }
    }
    
    //MARK: Private Method
    /// 遍历当前的弹幕
    /// - Parameter callBack: 回调
    private func forEachDanmakus(_ callBack: (BaseDanmaku) -> Void) {
        for con in danmakuRender.containers {
            if let danmaku = con.danmaku as? BaseDanmaku {
                callBack(danmaku)
            }
        }
    }
}

// MARK: - DanmakuSettingViewControllerDelegate
extension PlayerViewController: DanmakuSettingViewControllerDelegate {

    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuDensity density: Float) {
        
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuAlpha alpha: Float) {
        danmakuCanvas.alphaValue = CGFloat(alpha)
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuSpeed speed: Float) {
        self.forEachDanmakus { danmaku in
            if let scrollDanmaku = danmaku as? ScrollDanmaku {
                scrollDanmaku.extraSpeed = CGFloat(speed)
            }
        }
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuFontSize fontSize: Double) {
        self.danmakuFont = NSFont.systemFont(ofSize: fontSize)
        self.forEachDanmakus { danmaku in
            danmaku.font = self.danmakuFont
        }
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, danmakuProportion: Double) {
        
        let animate = CAKeyframeAnimation(keyPath: "backgroundColor")
        let mainColor = NSColor.mainColor
        animate.values = [
            NSColor(red: mainColor.redComponent, green: mainColor.greenComponent, blue: mainColor.blueComponent, alpha: 0.3).cgColor,
            NSColor.clear.cgColor
        ]
        animate.duration = 0.5
        animate.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.danmakuRender.canvas.layer?.add(animate, forKey: "CAKeyframeAnimation")
        
        self.layoutDanmakuCanvas()
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeShowDanmaku isShow: Bool) {
        self.danmakuCanvas.isHidden = !isShow
    }
    
    func danmakuSettingViewController(_ vc: DanmakuSettingViewController, didChangeDanmakuOffsetTime danmakuOffsetTime: Int) {
        self.danmakuRender.offsetTime = TimeInterval(danmakuOffsetTime)
    }
    
    func searchDanmakuInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.dismissPresented()
        
        if let item = self.player.currentPlayItem ?? self.player.playList.first {
            self.popMatchWindowController(with: nil, file: item)
        }
    }
    
    func loadDanmakuFileInDanmakuSettingViewController(vc: DanmakuSettingViewController) {
        self.pickFile()
    }
}

// MARK: - MediaSettingViewControllerDelegate
extension PlayerViewController: MediaSettingViewControllerDelegate {
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didOpenSubtitle subtitle: SubtitleProtocol) {
        self.player.currentSubtitle = subtitle
    }
    
    func loadSubtitleFileInMediaSettingViewController(_ vc: MediaSettingViewController) {
        self.pickFile()
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangeSubtitleSafeArea isOn: Bool) {
        
        let animate = CAKeyframeAnimation(keyPath: "backgroundColor")
        let mainColor = NSColor.mainColor
        animate.values = [
            NSColor(red: mainColor.redComponent, green: mainColor.greenComponent, blue: mainColor.blueComponent, alpha: 0.3).cgColor,
            NSColor.clear.cgColor
        ]
        animate.duration = 0.5
        animate.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
        self.danmakuCanvas.layer?.add(animate, forKey: "CAKeyframeAnimation")

        self.layoutDanmakuCanvas()
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerSpeed speed: Double) {
        self.changeSpeed(speed)
    }
    
    func mediaSettingViewController(_ vc: MediaSettingViewController, didChangePlayerMode mode: Preferences.PlayerMode) {
        self.changeRepeatMode()
    }
    
}
