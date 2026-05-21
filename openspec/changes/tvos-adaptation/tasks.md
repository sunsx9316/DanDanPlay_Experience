## 1. 工程搭建

- [x] 1.1 创建 `tvOS/` 目录结构：`AniXPlayer/` 源码目录、`Podfile`、目录框架
- [x] 1.2 编写 tvOS `Podfile`（platform :tvos, '13.0'），配置 MMKV、AMSMB2、GCDWebServer、ANXLog
- [x] 1.3 运行 `pod install`，生成 `AniXPlayer.xcworkspace`
- [x] 1.4 创建 tvOS Xcode 工程：target 配置（SDKROOT=appletvos, deployment target=13.0, device family=3）
- [x] 1.5 创建 `Info.plist`：移除 iOS 专用 Key，保留 Bonjour、ATS 配置
- [x] 1.6 通过相对路径引用 `Share/CocoaShare/` 源文件到 tvOS target
- [x] 1.7 将 `Share/TVVLCKit/` 集成到工程（SPM 本地包或直接链接 xcframework）
- [x] 1.8 更新 `Share/ANXLog/Package.swift`，添加 `.tvOS(.v13)` 平台声明
- [x] 1.9 处理 ANXLog mars.framework 缺失问题（条件编译降级为 os_log）
- [x] 1.10 验证编译：`xcodebuild` tvOS 工程能成功编译

## 2. 基类和焦点引擎

- [x] 2.1 创建 `ViewController` 基类（tvOS 版）：统一背景色、导航栏、deinit 调试
- [x] 2.2 创建 `NavigationController` 基类（tvOS 版）
- [x] 2.3 创建 `TableViewCell` 基类：实现焦点动画（背景色切换、文字颜色变化）
- [x] 2.4 创建 `CollectionViewCell` 基类：实现焦点动画（缩放 1.05x + 阴影 + 视差）
- [x] 2.5 创建 `Button` 基类：焦点样式（背景高亮 + 缩放）
- [x] 2.6 创建 `Label` 基类：焦点样式
- [x] 2.7 创建 `TableView` 基类：焦点配置
- [x] 2.8 创建 `CollectionView` 基类：焦点配置 + 引导布局
- [x] 2.9 在基类中实现 `preferredFocusEnvironments` 默认行为
- [x] 2.10 在基类中实现 `didUpdateFocus(in:with:)` 统一动画逻辑

## 3. AppDelegate 和主框架

- [x] 3.1 创建 `AppDelegate.swift`：UIWindow + 传统模式启动，注册文件类型支持
- [x] 3.2 创建 `MainViewController`：UITabBarController（主页/媒体库/设置 3 个 Tab）
- [x] 3.3 配置 Tab 的焦点行为和图标（使用 SF Symbols）
- [x] 3.4 调用 `Launcher.shared.start()` 初始化 ANXLog、Firebase（条件跳过）、缓存

## 4. 首页

- [x] 4.1 创建 `HomePageViewController`：UICollectionView 网格布局，焦点驱动
- [x] 4.2 创建"继续播放"区域 cell：展示最近播放的番剧封面和标题
- [x] 4.3 创建功能入口 cell：番剧、文件浏览、搜索等入口
- [x] 4.4 创建 `TimelineViewController`：番剧时间表
- [x] 4.5 创建 `FavoriteViewController`：收藏夹
- [x] 4.6 实现首页焦点默认位置和焦点记忆

## 5. 文件浏览

- [x] 5.1 创建 `FileBrowserViewController`：UITableView 文件列表 + 焦点导航
- [x] 5.2 创建文件列表 cell：文件名、大小、类型图标 + 焦点样式
- [x] 5.3 实现目录进入/返回导航
- [x] 5.4 集成 LocalFileManager（SMB/FTP/WebDAV 因 Pod 不可用暂未集成）
- [x] 5.5 移除 QR 码扫描入口、PCLoginHistory、HttpServer 入口

## 6. 番剧详情

- [x] 6.1 创建 `BangumiDetailViewController`：番剧信息和集数列表
- [x] 6.2 创建番剧详情 Header View：封面、标题、简介、标签
- [x] 6.3 创建集数列表 cell：集数编号、标题、焦点样式
- [x] 6.4 实现选择剧集播放
- [x] 6.5 创建 `MatchsViewController`：弹幕匹配页面

## 7. 搜索

- [x] 7.1 创建 `SearchViewController`：自定义搜索 UI（tvOS 无 UISearchController）
- [x] 7.2 实现搜索结果列表 + 焦点导航
- [x] 7.3 实现搜索框焦点进入/退出管理
- [x] 7.4 实现搜索结果点击跳转番剧详情

## 8. 设置

- [x] 8.1 创建 `SettingViewController`：UITableView 设置列表 + 焦点导航
- [x] 8.2 创建开关类型设置 cell（如自动加载弹幕等）
- [x] 8.3 创建导航类型设置 cell（如主题色、字幕顺序等）
- [x] 8.4 创建 `SetMainColorViewController`：颜色选择网格 + 焦点导航
- [x] 8.5 移除分享日志功能（UIActivityViewController 不可用）
- [x] 8.6 确保播放器内核设置仅显示 VLC（不显示 MPV）

## 9. 播放器

- [x] 9.1 创建 `PlayerViewController`：全屏播放器外壳 + dismiss 逻辑
- [x] 9.2 创建 `PlayerUIView`（tvOS 版）：视频渲染区域 + Siri Remote 事件处理
- [x] 9.3 实现 Click 按钮播放/暂停（UIPressesEvent）
- [x] 9.4 实现 Play/Pause 按钮处理
- [x] 9.5 实现触控板左右滑动 seek（方向键映射）
- [x] 9.6 实现 seek 步长（10s，可配置）
- [x] 9.7 实现 Menu 按钮退出播放器
- [x] 9.8 创建控制栏 UI：播放/暂停、快退、快进、设置按钮
- [x] 9.9 实现控制栏焦点导航（方向键在按钮间移动）
- [x] 9.10 实现控制栏显示/自动隐藏逻辑（5 秒超时）
- [x] 9.11 创建播放器设置面板（alert-based 倍速选择）
- [x] 9.12 实现长按 Click 弹出倍速选择菜单（1s 长按）
- [x] 9.13 集成 VLCPlayerWrapper（仅 VLC 内核，不做 MPV）
- [x] 9.14 弹幕渲染：集成 DanmakuRender-Swift（本地 SPM，已添加 `.tvOS(.v12)` 平台声明）
- [x] 9.15 弹幕显示：PlayerModel 串联 match → danmaku → play 全流程，控制栏弹幕开关可用

## 10. 收尾

- [x] 10.1 设计 tvOS App 图标（Top Shelf 图标 + 主图标）
- [ ] 10.2 在真机 Apple TV 上进行完整功能测试
- [ ] 10.3 焦点导航全链路测试（保证所有页面焦点可达、无卡住）
- [ ] 10.4 播放器性能测试（4K/1080p 播放、弹幕渲染流畅度）
- [ ] 10.5 修复测试中发现的问题
- [ ] 10.6 提交代码并将 `Share/TVVLCKit/` 纳入版本管理
