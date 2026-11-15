# iPhone Duo 适配设计

- 日期：2026-11-15
- 状态：已批准
- 范围：iOS / tvOS 共用布局代码，重点 iOS iPhone Duo

## 1. 意图

让 AniXPlayer 在 iPhone Duo 的闭合、展开、半折叠、横竖屏、Split View 等所有形态下都能自然重排，不依赖设备型号、屏幕尺寸、idiom 或 interface orientation。适配应成为一套可复用的布局规则，而不是针对某个页面写死宽度。

Apple 官方指南：

- [Prepare - iPhone Duo](https://developer.apple.com/iphone-duo/prepare/)
- [Prepare your app for iPhone Duo - Tech Talk](https://developer.apple.com/videos/play/tech-talks/111461/)
- [Preparing your app for iPhone Duo](https://developer.apple.com/documentation/technologyoverviews/preparing-your-app-for-iphone-duo)
- [Strike a pose with adaptive layouts on iPhone Duo](https://developer.apple.com/videos/play/tech-talks/111463/)
- [HIG: Designing for iPhone Duo](https://developer.apple.com/design/human-interface-guidelines/designing-for-iphone-duo)
- Xcode 27.1 官方 App Resizability skill：`xcrun agent skills export`

## 2. 目标

1. 布局尺寸只来自当前 view/window 的 `bounds`、`traitCollection`、`windowScene`，不来自 `UIScreen.main`、`UIDevice.current` 或固定设备尺寸。
2. 布局分支只基于 size class 或可用空间，不基于 idiom 或 interface orientation。
3. 宽度变化时只重新布局，不重建视图树；cell 不接收父容器宽度。
4. 滚动容器填满可用空间，内容通过 safe area、layout margins、readable width 控制。
5. 播放器保持横屏产品策略，但控制栏在 Duo 内屏/折叠态下仍能根据可用空间与 reserved region 自适应。
6. 主界面使用标准 `UITabBarController` 的 sidebar placement；只在存在自然主从关系时评估 `UISplitViewController`。
7. iOS 15 仍可编译运行；iOS 26/27 的 modern API 通过 availability 分支启用。

## 3. 非目标

- 不重做视觉设计，不改变现有品牌色、字号体系。
- 不重写 VLC/MPV 渲染管线，不改变播放器内核选择逻辑。
- 不强制把首页改成 `UISplitViewController`；首页是复合信息流，不是天然主从结构。
- 不把整个 App 改成 SwiftUI。
- 不修改部署目标，不删除 `UIRequiresFullScreen`（当前不存在），不擅自改 Info.plist 方向声明。

## 4. 反目标

- 布局代码出现 `UIScreen.main`、`UIDevice.current.userInterfaceIdiom`、`interfaceOrientation`。
- 把 `tableView.bounds.width`、`collectionView.bounds.width` 作为参数传进 cell。
- 在 `layoutSubviews` 里删除并重建整棵子视图树。
- 用 `regular width == iPad`、`phone == compact` 这类假设。
- 用 `screen.width - 120` 这类屏幕推导常量。
- 用 `scaleAspectFill` 承载不能被裁切的关键内容。

## 5. 约束

- 部署目标：iOS 15.0+ / tvOS 17.6+ / macOS 12.0+。
- `Share/` 下代码三平台共用，新增 UIKit 代码必须用平台条件编译隔离。
- Xcode 工程文件修改必须走 `scripts/xcode_project.rb`，不手动编辑 pbxproj。
- `MPV` / `VLC` 的 wrapper 在 iOS/tvOS/macOS 共用，修改需验证三平台编译。
- iPhone Duo 内屏不遵守 `supportedInterfaceOrientations`；播放器不能假设内屏一定是横屏比例。
- `UIArrangementViewController`、`UIView.reservedRegions`、`UIHingeInteraction`、`prefersInterfaceOrientationLocked`、`UITabBarControllerSidebar.preferredPlacement` 都需要 iOS 26/27.1 availability 分支。

## 6. 官方规则摘要

1. 尺寸从 view/window/scene 读；屏幕信息用 `view.window?.windowScene?.screen`。
2. 不用 orientation 做布局判断；需要判断宽高时比较当前 bounds。
3. 不用 idiom 判断空间；regular width 不等于 iPad。
4. 尺寸变化在 `layoutSubviews` / `viewDidLayoutSubviews` 重新读；`viewWillTransition(to:with:)` 只做副作用。
5. 前景控件在 `safeAreaLayoutGuide` 内；背景可以全屏；safe area 和 layout margins 都可能左右不对称。
6. scroll view 自身填满，`contentInsetAdjustmentBehavior = .automatic`；不要给 scroll view 的 frame 加内容 margin。
7. 优先标准容器：`UINavigationController`、`UITabBarController`、`UISplitViewController`、`UIArrangementViewController`。
8. 自定义 UI 用 `UIView.reservedRegions` / `UIHingeInteraction` 处理 fold 和 camera occlusion。
9. iOS 17+ 用 `registerForTraitChanges`，iOS 15 用 `traitCollectionDidChange`。
10. 全屏媒体检查 `scaleAspectFill` 裁切，必要时按宽高比切换 fit 或设置 focal point。

## 7. 当前状态与问题

已改对的方向：

- `UIViewController+Helper` 使用 `horizontalSizeClass`。
- `ProgressSlider` 使用 `traitCollection.displayScale`。
- `PlayerUIView` 使用 `windowScene.screen`。
- `PlayerNavigationController` 移除方向缓存。
- `preservesSuperviewLayoutMargins` 的思路正确。

需要修正：

1. `TagListTableViewCell` 通过 `update(tags:width:)` 接收 `tableView.bounds.width`；`layoutSubviews` 中 `rebuildTagRows()` 重建所有 row/button；没有 height invalidation；边距从 15/10 变成默认 8。
2. `FileBrowserViewController` 把 table view 的 leading/trailing 约束到 `layoutMarginsGuide`，scroll view 被整体缩进。
3. Player top/bottom bar 用 `layoutMarginsGuide` 替代 `safeAreaLayoutGuide`，可能在 notch/camera/竖排 bar 下越界。
4. `MPVPlayerWrapper` / `VLCPlayerWrapper` 仍用 `window?.screen`，官方要求 `window?.windowScene?.screen`。
5. 方向策略分散：`NavigationController` 全局锁横屏，`PlayerViewController` 锁横屏，`MediaLib` 按 idiom 锁竖屏。
6. `PlayerViewController.adaptivePresentationStyle` 仍用 `UIDevice.current.isPad`。
7. `HomePageBannerItemCell` 使用 `scaleAspectFill`，wide display 下可能裁掉主体。
8. tvOS `TagListTableViewCell` 使用 `UIScreen.main.bounds.width - 120`。
9. `HomePageFunctionTableViewCell` 固定 100pt item + `isPagingEnabled`，宽屏分页不对齐。
10. `GotoLastWatchPointView` 用 `safeAreaInsets.left` 做位移动画，假设 inset 在左侧。

## 8. 方案选择

### 8.1 标签流式布局

- A（已选）：自定义 `TagFlowView`，只创建一次按钮，宽度变化只重新摆放；iOS/tvOS 共用布局引擎。
- B：嵌套 `UICollectionView` 自适应。标准组件，但嵌套滚动和 cell 高度联动复杂。
- C：保留现有 `UIStackView` 小修。改动最小，但仍是手写流式布局，无法彻底解决重建问题。

选择 A。

### 8.2 播放器方向

- A（已选）：播放器保持横屏，其他页面支持全方向。
- B：播放器也支持全方向，控制栏按 size class 自适应。
- C：暂不动方向。

选择 A。播放器在外屏保持横屏产品策略；内屏不遵守方向，所以播放器布局仍然必须按可用空间自适应。

### 8.3 适配范围

- A：最小修复。
- B：通用重构。
- C（已选）：B + 标准容器/侧边栏 + 播放器 arrangement/reserved region。

选择 C，但按阶段落地，避免一次 PR 过大。

## 9. 设计

### 9.1 全局布局规则

新增一个共享的布局工具层（建议 `Share/CocoaShare/View/Layout/`，仅 UIKit 平台编译）：

- `LayoutMetrics`：集中管理设计常量，如 tag 间距、cell 边距、播放器控制栏高度。禁止在业务代码里散落 `screen.width - N`。
- `TraitChangeObserving`：封装 iOS 17+ `registerForTraitChanges` 与 iOS 15 `traitCollectionDidChange` 的兼容。
- `UIView.screenScale`：`window?.windowScene?.screen.scale ?? traitCollection.displayScale`，替换所有 `window?.screen` / `UIScreen.main.scale`。
- `UIView.isWideLayout`：基于 `bounds.width > bounds.height` 或 size class 的语义化判断，仅用于少数确实需要宽高判断的地方。

规则：

- 布局读取必须在 `layoutSubviews` / `viewDidLayoutSubviews` 或 constraint 更新时进行，不缓存一次宽度。
- `traitCollectionDidChange` 只做 trait 相关的重新计算；宽度变化交给 `layoutSubviews`。
- 不存储 `UIScreen`、`safeAreaInsets`、`layoutMargins`。

### 9.2 TagFlowView

新增共享组件 `TagFlowView`（UIKit，iOS/tvOS 共用）：

```swift
struct TagFlowMetrics {
    var horizontalSpacing: CGFloat
    var verticalSpacing: CGFloat
    var contentInsets: NSDirectionalEdgeInsets
    var buttonInsets: NSDirectionalEdgeInsets
    var font: UIFont
    var cornerRadius: CGFloat
    var borderWidth: CGFloat
}

final class TagFlowView: UIView {
    var tags: [BangumiTag]
    var metrics: TagFlowMetrics
    var onTagTap: ((BangumiTag) -> Void)?
    var buttonFactory: (BangumiTag, TagFlowMetrics) -> UIButton
}
```

行为：

- `tags` 变化时只创建/删除按钮；宽度变化不重建。
- `layoutSubviews` 按 `bounds.width` 计算每一行，设置已有按钮的 frame。
- `intrinsicContentSize.height` 由当前宽度计算；宽度变化导致高度变化时调用 `invalidateIntrinsicContentSize()`。
- cell 只做 `update(tags:)`，不再接收 `tableView.bounds.width`。
- cell 的 `contentView.layoutMargins` 设置为设计值（如 10/15）；flow view pin 到 `contentView.layoutMarginsGuide`，因此 flow view 的 `bounds` 已经是内容宽度，不再二次减 margin。
- 支持 Dynamic Type：监听 content size category，重新计算按钮尺寸。
- 支持 RTL：使用 `effectiveUserInterfaceLayoutDirection` 从 leading 到 trailing 排列。
- tvOS：`TagFlowView` 暴露 `preferredFocusEnvironments`，cell 用它作为 focus 环境；按钮使用 `primaryActionTriggered`。

iOS/tvOS 两个 cell 共用 `TagFlowView`，只注入不同的 `TagFlowMetrics` 和 `buttonFactory`。

### 9.3 滚动容器与列表

- `FileBrowserViewController` 的 table view 改为 pin 到 `view.safeAreaLayoutGuide`（top/bottom）和 `view`（leading/trailing），或直接 `view` + `contentInsetAdjustmentBehavior = .automatic`。
- cell 内容使用 `contentView.layoutMarginsGuide` 或 `readableContentGuide`；不要缩进 table view 本身。
- `HomePageBannerTableViewCell` 的 collection view 可以保留 layout margins 的内容缩进；但 `pageControl` 和分页计算以 collection view bounds 为准。
- `HomePageFunctionTableViewCell` 评估去掉 `isPagingEnabled` 或改用 flow/group layout，避免固定 100pt item 与分页宽度不一致。

### 9.4 播放器

方向：

- `NavigationController` 基类移除全局横屏 override；主页、媒体库、我的支持全方向。
- `PlayerNavigationController` 与 `PlayerViewController` 统一锁横屏：
  - iOS 26+：override `prefersInterfaceOrientationLocked` 返回 true，并在需要时调用 `setNeedsUpdateOfPrefersInterfaceOrientationLocked()`。
  - iOS 15–25：保留 `supportedInterfaceOrientations = .landscape` / `shouldAutorotate` 作为兼容。
- 播放器通过 modal 打开的设置、弹幕列表、字幕、选集、投屏等页面纳入本轮适配；不能只靠方向锁，因为 Duo 内屏不遵守 `supportedInterfaceOrientations`。外屏由 `PlayerNavigationController` 统一保持横屏，内屏按可用 width/height 和 size class 自适应。
- `MediaLibNavigationController` / `MediaLibViewController` 移除 idiom 方向锁，支持全方向；如果产品确实需要竖屏，再单独用 `prefersInterfaceOrientationLocked` 明确表达。

布局：

- top/bottom bar 的背景全宽；内容容器 pin 到 `safeAreaLayoutGuide`，内部再用 layout margins/readable width 做设计间距。
- `PlayerUITopView` / `PlayerUIBottomView` 中固定的 20/50/36 等改为 `LayoutMetrics` 常量；如果播放器未来支持窄高度，再按 `verticalSizeClass` 调整。
- `ProgressSlider` 继续用 `traitCollection.displayScale`，并用兼容封装注册 trait change。
- `SnapshotPreviewView` 继续在 `layoutSubviews` 按自身 bounds 计算位置。
- Duo 内屏竖屏/非 16:9 时，视频保持 16:9 letterbox，不 fill/crop；控制栏根据可用空间和 reserved region 避让。不做竖屏专用播放器布局。

Duo reserved region：

- 在 `PlayerUIView` 上添加 `UIHingeInteraction`，监听折叠状态。
- 在 `layoutSubviews` / hinge 更新时调用 `reservedRegionsOfKind(.division)` 与 `.occlusion`，读取 fold/camera 的 frame。
- 新增 `PlayerReservedRegionLayout`：根据 reserved region 调整 top/bottom bar 的位置或内边距，确保控制按钮不被 fold/camera 遮挡。视频本身是连续内容，可以跨 fold；控制栏需要避让。
- iOS 27.1 以下无 reserved region API 时，退回 safe area + layout margins 布局。

`UIArrangementViewController`：

- 目标架构是把播放器控制层与视频层作为 overlay arrangement 的 primary/secondary。
- 由于播放器目前是单个 `PlayerUIView`，第一步先用 `UIHingeInteraction` + reserved region 调整控制栏；第二步再评估是否把视频/控制拆成两个 child view controller 并接入 `UIArrangementViewController`。
- 不在第一步强行重构播放器层级，避免影响 VLC/MPV 渲染。

### 9.5 主界面与标准容器

- `MainViewController` 继续使用 `UITabBarController`。
- iOS 27+ 且在 regular width 下设置 `tabBarController.sidebar.preferredPlacement = .sidebar`；该规则同时作用于 iPad 和 Duo 内屏（所有 regular width 统一），不做设备/idiom 区分。否则保持 `.automatic`。
- 评估把 `UITabBarItem` 迁移到 `UITab` 以获得 sidebar 的 subtitle/group 能力；不强制。
- `UISplitViewController` 只用于存在自然主从关系的流程；首页信息流和文件浏览器列表暂不强行拆分，先保持 `UINavigationController`。
- 继续使用标准 `UINavigationController` / `UITabBarController` bars；不新增自定义 bar。播放器的自定义 bar 由播放器自己处理 safe area/reserved region。

### 9.6 全屏媒体

- `HomePageBannerItemCell` 的 `scaleAspectFill` 保留为装饰性横幅，但需要确认主体在 Duo 内屏不被裁切；如果横幅包含关键文字/人物，按宽高比切换 `.scaleAspectFit` 或设置 focal point。
- 其他 `scaleAspectFill` 的封面图是缩略图，裁切可接受；只需保证 `clipsToBounds` 和圆角一致。

### 9.7 Trait 与缩放

- `ProgressSlider`、`PlayerUIView`、`MPVPlayerWrapper`、`VLCPlayerWrapper` 统一使用 `windowScene.screen.scale` 或 `traitCollection.displayScale`。
- iOS 17+ 优先 `registerForTraitChanges`；iOS 15 用 `traitCollectionDidChange`。新增共享封装，避免每个类重复写兼容分支。
- 不缓存 displayScale 到 layer/constraint 后不更新；如果缓存，注册 trait change 并在 handler 中直接重算。

## 10. 实施阶段

### 阶段 1：基础规则与低风险修复

- 新增 `LayoutMetrics` / trait/screen 工具。
- 修正 `MPVPlayerWrapper` / `VLCPlayerWrapper` 的 `windowScene.screen`。
- 修正 `FileBrowserViewController` 的 scroll view 约束。
- 修正 `PlayerViewController.adaptivePresentationStyle` 为 size class。
- 修正 tvOS Tag cell 的 `UIScreen.main`（由 `TagFlowView` 重构一并解决）。
- 保留现有 `TagListTableViewCell` 行为，先不重构，确保编译通过。

### 阶段 2：TagFlowView

- 新增 `TagFlowView` + `TagFlowLayout` 纯布局引擎。
- 重构 iOS/tvOS `TagListTableViewCell`，删除 `update(tags:width:)` 和 `rebuildTagRows()`。
- 布局引擎验证：新增 `scripts/tests/tag_flow_layout_test.swift`，用独立 Swift 脚本断言不同宽度、RTL、Dynamic Type、空 tags、单行/多行；不新增 Xcode test target（`scripts/xcode_project.rb` 目前不支持创建 target，避免手改 pbxproj）。
- 验证自 sizing cell 在宽度变化后的高度更新；必要时在 table view 层做宽度变化后的 `beginUpdates/endUpdates`。

### 阶段 3：播放器安全区与方向

- `NavigationController` 移除全局横屏锁；`PlayerNavigationController`/`PlayerViewController` 统一横屏策略。
- top/bottom bar 改回 `safeAreaLayoutGuide` 作为内容边界。
- 播放器固定常量收敛到 `LayoutMetrics`。
- 在 iPhone Duo 模拟器验证所有 pose。

### 阶段 4：Duo 高级适配

- `MainViewController` 接入 tab sidebar placement。
- `PlayerUIView` 接入 `UIHingeInteraction` + `reservedRegions`，实现控制栏避让。
- 评估 `UIArrangementViewController` overlay 重构；如果风险高，保留为后续独立变更。
- 验证 Split View、iPhone Mirroring 极限尺寸。

### 阶段 5：验证与清理

- 跑 iOS/tvOS 构建（真机 generic，mars.framework 不支持模拟器）。
- 用官方 App Resizability skill 的检查项复查 `UIScreen.main`、idiom、orientation、safe area、scroll view。
- 在 iPhone Duo 模拟器 Device Hub 测试 closed/open/folded/rotated。
- 在 iPhone Mirroring 拖到极窄/极宽。
- 回归播放器、弹幕、缩略图、字幕、PiP。

## 11. 风险

1. 移除 `NavigationController` 全局横屏锁会改变主页/我的在 iPhone 上的旋转行为，可能暴露未适配的布局。需要逐页验证；如果某页产品上必须横屏，单独用 `prefersInterfaceOrientationLocked` 锁定，不要恢复全局锁。
2. `TagFlowView` 的高度更新依赖 table view 的 self-sizing 行为；宽度变化后可能需要 `beginUpdates/endUpdates` 或自定义 table view 失效逻辑。阶段 2 先用一个页面验证。
3. `UIArrangementViewController` 需要把播放器拆成 child view controllers，可能影响 VLC/MPV 的 view 层级和 PiP。阶段 4 先做 reserved region，arrangement 作为独立变更。
4. iOS 15–25 没有 `prefersInterfaceOrientationLocked`，需要保留旧方向 override；两条路径要一致。
5. tvOS focus engine 对共享 `TagFlowView` 的 focus 行为需要单独验证。
6. `Share/` 中新增 UIKit 代码需要条件编译，避免 macOS 编译失败。

## 12. 已确认

- 播放器保持横屏；主页、媒体库、我的支持全方向。`NavigationController` 不再全局锁横屏。
- 播放器在 Duo 内屏竖屏/非 16:9 时保持 16:9 letterbox，控制栏根据 reserved region 避让；不做 fill/crop，不做竖屏专用布局。
- Tab sidebar 在 iOS 27+ 的所有 regular width 场景启用（iPad + Duo 内屏），不做设备区分。
- 播放器 modal 页面（设置、弹幕、字幕、选集、投屏等）纳入本轮适配，逐页检查。
- 标签流式布局采用自定义 `TagFlowView`。
- 文件浏览器暂不拆 `UISplitViewController`；首页不强行 split。
- 阶段 4 先做 `UIHingeInteraction` + reserved region 避让；`UIArrangementViewController` 作为后续独立变更。
- 测试采用独立 Swift 脚本验证纯布局引擎，不新增 Xcode test target。
