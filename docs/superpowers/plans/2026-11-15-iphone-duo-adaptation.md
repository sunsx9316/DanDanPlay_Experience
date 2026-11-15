# iPhone Duo 适配 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 把 AniXPlayer 的 iOS 布局从设备/屏幕假设迁移到 size class、局部 bounds、safe area 和 reserved region 驱动的通用布局，并在 iPhone Duo 的闭合、展开、半折叠、横竖屏和 Split View 下验证。

**Architecture:** 先建立共享的屏幕/布局工具和纯布局引擎，再重构标签流式布局、方向策略、播放器安全区和主界面 sidebar；播放器高级适配先用 `UIHingeInteraction` + `reservedRegions`，`UIArrangementViewController` 留作后续独立变更。

**Tech Stack:** Swift、UIKit、SnapKit、Xcode 27.1、iOS 15+/tvOS 17.6+/macOS 12+。

**Spec:** `docs/superpowers/specs/2026-11-15-iphone-duo-adaptation-design.md`

## Global Constraints

- 部署目标：iOS 15.0+、tvOS 17.6+、macOS 12.0+。
- 使用 Xcode 27.1 / iOS 27.1 SDK；不提升部署目标。
- `Share/CocoaShare` 代码三平台共用；UIKit 代码必须包在 `#if os(iOS) || os(tvOS)` 中。
- 不新增第三方依赖。
- 新增/删除 Xcode 文件必须用 `ruby scripts/xcode_project.rb <ios|tvos|mac> add|remove <path>`，禁止手动编辑 pbxproj。
- 所有构建命令必须成功；Mac 构建也要保持绿色。
- 提交使用 Conventional Commits，中文标题，scope 小写。
- 允许命名设计常量；禁止从屏幕宽度/设备型号推导布局值。
- 测试脚本放在 `scripts/tests/`，不加入 Xcode target。
- 手动 UI 验证优先 iPhone Duo 模拟器；若 mars.framework 仍不支持模拟器，改用真机，不要因此跳过验证。

## Review Focus

1. **Duo 内屏竖屏播放器 modal**：内屏不遵守 `supportedInterfaceOrientations`，设置/弹幕/字幕/选集等页面可能以竖屏出现；打开这些页面时控件不能被裁切或压到 fold/camera 下。
2. **Bangumi 标签 cell 折叠/展开**：table 宽度变化后 cell 高度必须重新计算；标签不能重叠、裁切或出现半行。
3. **非对称 safe area / 竖排 bar**：播放器控制栏不能假设左右 inset 对称；camera/竖排 bar 出现时控件必须仍然可点。
4. **iPad regular width sidebar**：tab sidebar 不能在 iPad 和 Duo 内屏遮挡内容或破坏 tab 切换。
5. **tvOS focus**：共享 `TagFlowView` 后，遥控器焦点必须仍能在标签按钮间移动，`primaryActionTriggered` 必须触发标签点击。

---

## File Structure

**Create:**

- `Share/CocoaShare/View/Layout/UIView+Screen.swift` — 当前窗口屏幕/缩放读取。
- `iOS/AniXPlayer/Player/PlayerModalNavigationController.swift` — 播放器 modal 的横屏容器。
- `Share/CocoaShare/View/TagFlow/TagFlowLayout.swift` — 纯流式布局引擎（CoreGraphics）。
- `Share/CocoaShare/View/TagFlow/TagFlowView.swift` — iOS/tvOS 共用标签流式视图。
- `iOS/AniXPlayer/Player/View/PlayerUI/PlayerLayoutMetrics.swift` — 播放器设计常量。
- `iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift` — fold/camera 避让算法。
- `scripts/tests/tag_flow_layout_test.swift` — TagFlowLayout 断言脚本。
- `scripts/tests/player_reserved_region_layout_test.swift` — PlayerReservedRegionLayout 断言脚本。

**Modify:**

- `Share/CocoaShare/MediaPlayer/Wrapper/MPV/MPVPlayerWrapper.swift`
- `Share/CocoaShare/MediaPlayer/Wrapper/VLCPlayerWrapper.swift`
- `iOS/AniXPlayer/Bangumi/View/TagListTableViewCell.swift`
- `iOS/AniXPlayer/Bangumi/BangumiDetailViewController.swift`
- `tvOS/AniXPlayer/BangumiDetail/View/TagListTableViewCell.swift`
- `tvOS/AniXPlayer/BangumiDetail/BangumiDetailViewController.swift`
- `iOS/AniXPlayer/Vendor/Base/ViewController/NavigationController.swift`
- `iOS/AniXPlayer/Main/MediaLib/MediaLibNavigationController.swift`
- `iOS/AniXPlayer/Main/MediaLib/MediaLibViewController.swift`
- `iOS/AniXPlayer/Player/PlayerNavigationController.swift`
- `iOS/AniXPlayer/Player/PlayerViewController.swift`
- `iOS/AniXPlayer/Player/Setting/PlayerSettingViewController.swift`
- `iOS/AniXPlayer/Player/PlayerControlAnimater.swift`
- `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIBottomView.swift`
- `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUITopView.swift`
- `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIView.swift`
- `iOS/AniXPlayer/Player/View/PlayerUI/ProgressSlider.swift`
- `iOS/AniXPlayer/Files/FileBrowserViewController.swift`
- `iOS/AniXPlayer/HomePage/Banner/HomePageBannerTableViewCell.swift`
- `iOS/AniXPlayer/HomePage/Banner/HomePageBannerItemCell.swift`
- `iOS/AniXPlayer/HomePage/Function/HomePageFunctionTableViewCell.swift`
- `iOS/AniXPlayer/Main/MainViewController.swift`
- `iOS/AniXPlayer/Player/View/GotoLastWatchPointView.swift`
- 可能删除：`iOS/AniXPlayer/Helper/UIDevice+Helper.swift`（如果 grep 确认无引用）。

---

### Task 1: 屏幕/窗口上下文工具

**Files:**
- Create: `Share/CocoaShare/View/Layout/UIView+Screen.swift`
- Modify: `Share/CocoaShare/MediaPlayer/Wrapper/MPV/MPVPlayerWrapper.swift:636-642`
- Modify: `Share/CocoaShare/MediaPlayer/Wrapper/VLCPlayerWrapper.swift:626-634`

**Interfaces:**
- Produces: `UIView.anxScreen: UIScreen?`、`UIView.anxScreenScale: CGFloat`（仅 iOS/tvOS）。

- [ ] **Step 1: 创建屏幕上下文扩展**

```swift
#if os(iOS) || os(tvOS)
import UIKit

extension UIView {
    var anxScreen: UIScreen? {
        window?.windowScene?.screen
    }

    var anxScreenScale: CGFloat {
        anxScreen?.scale ?? traitCollection.displayScale
    }
}
#endif
```

- [ ] **Step 2: 替换 MPV 的屏幕缩放**

`MPVView.screenScale` 的 iOS/tvOS 分支改为 `return anxScreenScale`，macOS 分支保持 `NSScreen.main?.backingScaleFactor ?? 2.0`。

- [ ] **Step 3: 替换 VLC 的屏幕缩放**

`VLCPlayerWrapper` 中字幕位置的 `scaleFactor` 改为：

```swift
scaleFactor = self.mediaView.anxScreenScale
```

- [ ] **Step 4: 把新文件加入 iOS/tvOS 工程**

```bash
ruby scripts/xcode_project.rb ios --dry-run Share/CocoaShare/View/Layout/UIView+Screen.swift
ruby scripts/xcode_project.rb ios add Share/CocoaShare/View/Layout/UIView+Screen.swift
ruby scripts/xcode_project.rb tvos --dry-run Share/CocoaShare/View/Layout/UIView+Screen.swift
ruby scripts/xcode_project.rb tvos add Share/CocoaShare/View/Layout/UIView+Screen.swift
```

- [ ] **Step 5: 构建 iOS/tvOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build
```

Expected: 两个构建都成功。

- [ ] **Step 6: 检查不再使用 window.screen**

```bash
grep -R "window?.screen\|window\.screen" iOS/AniXPlayer Share/CocoaShare --include="*.swift"
```

Expected: 无输出（注释除外）。

- [ ] **Step 7: 提交**

```bash
git add Share/CocoaShare/View/Layout/UIView+Screen.swift \
  Share/CocoaShare/MediaPlayer/Wrapper/MPV/MPVPlayerWrapper.swift \
  Share/CocoaShare/MediaPlayer/Wrapper/VLCPlayerWrapper.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj tvOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "refactor(ui): 统一从窗口场景读取屏幕信息"
```

---

### Task 2: TagFlowLayout 纯布局引擎

**Files:**
- Create: `Share/CocoaShare/View/TagFlow/TagFlowLayout.swift`
- Create: `scripts/tests/tag_flow_layout_test.swift`

**Interfaces:**
- Produces:

```swift
struct TagFlowLayout {
    struct Metrics {
        var horizontalSpacing: CGFloat
        var verticalSpacing: CGFloat
    }

    enum LayoutDirection {
        case leftToRight
        case rightToLeft
    }

    struct Result {
        var frames: [CGRect]
        var contentHeight: CGFloat
    }

    static func layout(
        sizes: [CGSize],
        in width: CGFloat,
        metrics: Metrics,
        layoutDirection: LayoutDirection = .leftToRight
    ) -> Result
}
```

- [ ] **Step 1: 写失败测试脚本**

创建 `scripts/tests/tag_flow_layout_test.swift`：

```swift
import CoreGraphics
import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else {
        fatalError("FAIL: \(message)")
    }
}

func checkFrame(_ frame: CGRect, x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat, _ message: String) {
    check(abs(frame.origin.x - x) < 0.001, "\(message) x: \(frame.origin.x) != \(x)")
    check(abs(frame.origin.y - y) < 0.001, "\(message) y: \(frame.origin.y) != \(y)")
    check(abs(frame.width - width) < 0.001, "\(message) width: \(frame.width) != \(width)")
    check(abs(frame.height - height) < 0.001, "\(message) height: \(frame.height) != \(height)")
}

@main
struct TagFlowLayoutTests {
    static func main() {
        let metrics = TagFlowLayout.Metrics(horizontalSpacing: 8, verticalSpacing: 6)

        let oneRow = TagFlowLayout.layout(
    sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
    in: 200,
    metrics: metrics
)
check(oneRow.frames.count == 2, "one row count")
checkFrame(oneRow.frames[0], x: 0, y: 0, width: 100, height: 20, "row 1 item 1")
checkFrame(oneRow.frames[1], x: 108, y: 0, width: 80, height: 24, "row 1 item 2")
check(abs(oneRow.contentHeight - 24) < 0.001, "one row height")

let twoRows = TagFlowLayout.layout(
    sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
    in: 150,
    metrics: metrics
)
checkFrame(twoRows.frames[0], x: 0, y: 0, width: 100, height: 20, "row 2 item 1")
checkFrame(twoRows.frames[1], x: 0, y: 26, width: 80, height: 24, "row 2 item 2")
check(abs(twoRows.contentHeight - 50) < 0.001, "two row height")

let overWide = TagFlowLayout.layout(
    sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
    in: 50,
    metrics: metrics
)
checkFrame(overWide.frames[0], x: 0, y: 0, width: 100, height: 20, "overwide item 1")
checkFrame(overWide.frames[1], x: 0, y: 26, width: 80, height: 24, "overwide item 2")

let rtl = TagFlowLayout.layout(
    sizes: [CGSize(width: 100, height: 20), CGSize(width: 80, height: 24)],
    in: 200,
    metrics: metrics,
    layoutDirection: .rightToLeft
)
checkFrame(rtl.frames[0], x: 100, y: 0, width: 100, height: 20, "rtl item 1")
checkFrame(rtl.frames[1], x: 12, y: 0, width: 80, height: 24, "rtl item 2")

let varyingHeights = TagFlowLayout.layout(
    sizes: [CGSize(width: 50, height: 20), CGSize(width: 60, height: 40)],
    in: 200,
    metrics: metrics
)
checkFrame(varyingHeights.frames[0], x: 0, y: 0, width: 50, height: 20, "varying item 1")
checkFrame(varyingHeights.frames[1], x: 58, y: 0, width: 60, height: 40, "varying item 2")
check(abs(varyingHeights.contentHeight - 40) < 0.001, "varying row height")

let empty = TagFlowLayout.layout(sizes: [], in: 200, metrics: metrics)
check(empty.frames.isEmpty && empty.contentHeight == 0, "empty")
let zeroWidth = TagFlowLayout.layout(sizes: [CGSize(width: 10, height: 10)], in: 0, metrics: metrics)
check(zeroWidth.frames.isEmpty && zeroWidth.contentHeight == 0, "zero width")

        print("TagFlowLayout tests passed")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
xcrun swiftc Share/CocoaShare/View/TagFlow/TagFlowLayout.swift scripts/tests/tag_flow_layout_test.swift -o /tmp/tag_flow_layout_test
```

Expected: 编译失败（`TagFlowLayout.swift` 不存在，或提示 `cannot find 'TagFlowLayout'`）。

- [ ] **Step 3: 实现 TagFlowLayout**

实现签名与上面的 `Interfaces` 一致，算法：

```swift
guard width > 0, !sizes.isEmpty else {
    return Result(frames: [], contentHeight: 0)
}

var frames: [CGRect] = []
frames.reserveCapacity(sizes.count)
var x: CGFloat = 0
var y: CGFloat = 0
var rowHeight: CGFloat = 0

for size in sizes {
    let itemWidth = max(size.width, 0)
    let itemHeight = max(size.height, 0)
    if x > 0, x + itemWidth > width {
        x = 0
        y += rowHeight + metrics.verticalSpacing
        rowHeight = 0
    }
    let originX: CGFloat
    switch layoutDirection {
    case .leftToRight: originX = x
    case .rightToLeft: originX = width - x - itemWidth
    }
    frames.append(CGRect(x: originX, y: y, width: itemWidth, height: itemHeight))
    x += itemWidth + metrics.horizontalSpacing
    rowHeight = max(rowHeight, itemHeight)
}

return Result(frames: frames, contentHeight: y + rowHeight)
```

- [ ] **Step 4: 运行测试确认通过**

```bash
xcrun swiftc Share/CocoaShare/View/TagFlow/TagFlowLayout.swift scripts/tests/tag_flow_layout_test.swift -o /tmp/tag_flow_layout_test
/tmp/tag_flow_layout_test
```

Expected: 输出 `TagFlowLayout tests passed`，退出码 0。

- [ ] **Step 5: 把引擎加入 iOS/tvOS 工程**

```bash
ruby scripts/xcode_project.rb ios add Share/CocoaShare/View/TagFlow/TagFlowLayout.swift
ruby scripts/xcode_project.rb tvos add Share/CocoaShare/View/TagFlow/TagFlowLayout.swift
```

- [ ] **Step 6: 提交**

```bash
git add Share/CocoaShare/View/TagFlow/TagFlowLayout.swift scripts/tests/tag_flow_layout_test.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj tvOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "feat(ui): 添加标签流式布局引擎"
```

---

### Task 3: TagFlowView 共用视图

**Files:**
- Create: `Share/CocoaShare/View/TagFlow/TagFlowView.swift`

**Interfaces:**
- Consumes: `TagFlowLayout`。
- Produces:

```swift
final class TagFlowButton: UIButton {
    var bangumiTag: BangumiTag?
}

final class TagFlowView: UIView {
    struct Metrics {
        var horizontalSpacing: CGFloat
        var verticalSpacing: CGFloat
    }

    var metrics: Metrics { get set }
    var onTagTap: ((BangumiTag) -> Void)?
    var configureButton: ((TagFlowButton, BangumiTag) -> Void)?

    func update(tags: [BangumiTag])
    func heightThatFits(width: CGFloat) -> CGFloat
}
```

- [ ] **Step 1: 实现 TagFlowButton 与 TagFlowView**

要求：

- `update(tags:)` 只在数据变化时创建 `TagFlowButton`，不重建已有按钮；`tags` 为空时移除所有按钮并把高度归零。
- 用 `tags.map(\.name)` 与当前 tags 比较；相同则直接 return，避免 cell 复用时重复创建按钮。
- 每个按钮设置 `bangumiTag`，通过 `configureButton` 配置标题、字体、颜色、边距、圆角。
- 点击事件：

```swift
#if os(tvOS)
button.addTarget(self, action: #selector(onTap(_:)), for: .primaryActionTriggered)
#else
button.addTarget(self, action: #selector(onTap(_:)), for: .touchUpInside)
#endif
```

- `layoutSubviews` 用 `TagFlowLayout.layout(sizes:in:metrics:layoutDirection:)`；`layoutDirection` 取 `effectiveUserInterfaceLayoutDirection`。
- `heightThatFits(width:)` 用同一组按钮尺寸和同一个引擎，返回 `contentHeight`。
- `intrinsicContentSize` 返回 `CGSize(width: UIView.noIntrinsicMetric, height: lastContentHeight)`。
- 宽度变化导致高度变化时调用 `invalidateIntrinsicContentSize()`。
- iOS 17+ 注册 `UITraitContentSizeCategory`：

```swift
if #available(iOS 17.0, tvOS 17.0, *) {
    registerForTraitChanges([UITraitPreferredContentSizeCategory.self]) { (self: TagFlowView, _) in
        self.setNeedsLayout()
        self.invalidateIntrinsicContentSize()
    }
}
```

iOS 15/16 用 `traitCollectionDidChange` 做同样的事；tvOS 17.6 已满足 availability。
- tvOS：

```swift
#if os(tvOS)
override var canBecomeFocused: Bool { false }
override var preferredFocusEnvironments: [UIFocusEnvironment] { buttons }
#endif
```

- [ ] **Step 2: 加入 iOS/tvOS 工程**

```bash
ruby scripts/xcode_project.rb ios add Share/CocoaShare/View/TagFlow/TagFlowView.swift
ruby scripts/xcode_project.rb tvos add Share/CocoaShare/View/TagFlow/TagFlowView.swift
```

- [ ] **Step 3: 构建 iOS/tvOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build
```

Expected: 两个构建都成功。

- [ ] **Step 4: 提交**

```bash
git add Share/CocoaShare/View/TagFlow/TagFlowView.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj tvOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "feat(ui): 添加可复用标签流式视图"
```

---

### Task 4: iOS 标签 cell 重构

**Files:**
- Modify: `iOS/AniXPlayer/Bangumi/View/TagListTableViewCell.swift`
- Modify: `iOS/AniXPlayer/Bangumi/BangumiDetailViewController.swift:82-91`

**Interfaces:**
- Consumes: `TagFlowView`。
- Produces: `TagListTableViewCell.update(tags: [BangumiTag])`；`didTouchTagButton: ((BangumiTag) -> Void)?` 保持不变。

- [ ] **Step 1: 重写 iOS TagListTableViewCell**

要求：

- 删除 `flowStackView`、`fallbackContentWidth`、`lastLayoutWidth`、`rebuildTagRows()`、`createRowStack()`、`createTagButton()`、`update(tags:width:)`。
- 新增 `private let flowView = TagFlowView()` 和命名设计常量：

```swift
private enum Layout {
    static let contentInsets = NSDirectionalEdgeInsets(top: 10, leading: 15, bottom: 10, trailing: 15)
    static let spacing: CGFloat = 8
}
```

- `init` 中：

```swift
contentView.layoutMargins = Layout.contentInsets
contentView.addSubview(flowView)
flowView.snp.makeConstraints { make in
    make.edges.equalTo(contentView.layoutMarginsGuide)
}
flowView.metrics = .init(horizontalSpacing: Layout.spacing, verticalSpacing: Layout.spacing)
flowView.configureButton = { button, tag in
    button.setTitle(tag.name, for: .normal)
    button.titleLabel?.font = .ddp_small
    button.setTitleColor(.mainColor, for: .normal)
    button.backgroundColor = UIColor.mainColor.withAlphaComponent(0.12)
    button.layer.borderColor = UIColor.mainColor.withAlphaComponent(0.25).cgColor
    button.layer.borderWidth = 0.5
    button.layer.cornerRadius = 12
    button.layer.masksToBounds = true
    button.contentEdgeInsets = UIEdgeInsets(top: 4, left: 10, bottom: 4, right: 10)
}
flowView.onTagTap = { [weak self] tag in
    self?.didTouchTagButton?(tag)
}
```

- `update(tags:)`：

```swift
func update(tags: [BangumiTag]) {
    flowView.update(tags: tags.sorted { $0.count > $1.count })
}
```

- 覆写 `systemLayoutSizeFitting`：

```swift
override func systemLayoutSizeFitting(
    _ targetSize: CGSize,
    withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
    verticalFittingPriority: UILayoutPriority
) -> CGSize {
    guard targetSize.width > 0, targetSize.width < .greatestFiniteMagnitude else {
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
    let margins = contentView.layoutMargins
    let contentWidth = targetSize.width - margins.leading - margins.trailing
    let height = flowView.heightThatFits(width: contentWidth) + margins.top + margins.bottom
    return CGSize(width: targetSize.width, height: height)
}
```

- [ ] **Step 2: 更新 BangumiDetailViewController 调用**

在 `.tags` 分支中，无论 tags 是否为空都更新 cell：

```swift
let tags = self.detail?.tags ?? []
cell.update(tags: tags)
cell.didTouchTagButton = { [weak self] tag in
    guard let self = self else { return }
    let vc = TagSearchResultViewController(tag: tag.name)
    self.navigationController?.pushViewController(vc, animated: true)
}
```

在 `BangumiDetailViewController` 中增加 table 宽度变化后的高度刷新：

```swift
private var lastTagTableWidth: CGFloat = 0

override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let width = tableView.bounds.width
    guard width > 0, width != lastTagTableWidth else { return }
    lastTagTableWidth = width
    tableView.beginUpdates()
    tableView.endUpdates()
}
```

如果类中已有 `viewDidLayoutSubviews`，把这段逻辑合并进去，不要新增第二个 override。

- [ ] **Step 3: 构建 iOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 4: 手动验证**

在 iPhone Duo 模拟器：

1. 打开任意番剧详情，滚动到标签 cell。
2. 在 Device Hub 依次切换 open / closed / folded / 旋转。
3. 期望：标签按当前宽度换行；没有重叠/裁切；cell 高度随宽度变化；点击任意标签进入对应搜索页。
4. 用长标签名和较大 Dynamic Type 再检查一次；期望按钮不超出 cell，必要时单行截断。

- [ ] **Step 5: 提交**

```bash
git add iOS/AniXPlayer/Bangumi/View/TagListTableViewCell.swift \
  iOS/AniXPlayer/Bangumi/BangumiDetailViewController.swift
git commit -m "refactor(bangumi): 标签列表改用 TagFlowView"
```

---

### Task 5: tvOS 标签 cell 重构

**Files:**
- Modify: `tvOS/AniXPlayer/BangumiDetail/View/TagListTableViewCell.swift`
- Modify: `tvOS/AniXPlayer/BangumiDetail/BangumiDetailViewController.swift:148`

**Interfaces:**
- Consumes: `TagFlowView`。
- Produces: `TagListTableViewCell.update(tags: [BangumiTag])`。

- [ ] **Step 1: 重写 tvOS TagListTableViewCell**

要求：

- 删除 `flowStackView`、`rebuild` 逻辑和 `UIScreen.main.bounds.width - 120`。
- 使用 `TagFlowView`，`contentView` 边距保持原设计的 16/60：

```swift
private static let horizontalInset: CGFloat = 60
private static let verticalInset: CGFloat = 16

contentView.addSubview(flowView)
flowView.snp.makeConstraints { make in
    make.top.equalToSuperview().offset(Self.verticalInset)
    make.leading.equalToSuperview().offset(Self.horizontalInset)
    make.trailing.equalToSuperview().offset(-Self.horizontalInset)
    make.bottom.equalToSuperview().offset(-Self.verticalInset)
}
flowView.metrics = .init(horizontalSpacing: 12, verticalSpacing: 12)
```

- `configureButton` 使用 tvOS 样式：`.ddp_small()`、cornerRadius 16、borderWidth 1、contentEdgeInsets 6/16/6/16、`primaryActionTriggered` 由 `TagFlowView` 内部处理。
- `update(tags:)` 只调用 `flowView.update(tags: tags.sorted { $0.count > $1.count })`。
- `preferredFocusEnvironments` 返回 `[flowView]`；`canBecomeFocused` 保持 false。
- 覆写 `systemLayoutSizeFitting`，保证首次布局前高度正确：

```swift
override func systemLayoutSizeFitting(
    _ targetSize: CGSize,
    withHorizontalFittingPriority horizontalFittingPriority: UILayoutPriority,
    verticalFittingPriority: UILayoutPriority
) -> CGSize {
    guard targetSize.width > 0, targetSize.width < .greatestFiniteMagnitude else {
        return super.systemLayoutSizeFitting(
            targetSize,
            withHorizontalFittingPriority: horizontalFittingPriority,
            verticalFittingPriority: verticalFittingPriority
        )
    }
    let contentWidth = targetSize.width - Self.horizontalInset * 2
    let height = flowView.heightThatFits(width: contentWidth) + Self.verticalInset * 2
    return CGSize(width: targetSize.width, height: height)
}
```

- [ ] **Step 2: 更新 tvOS BangumiDetailViewController 调用**

`cell.update(tags: tags)`（如果原来是同名签名则保持不变；如果还传宽度则删除宽度参数）。

- [ ] **Step 3: 构建 tvOS**

```bash
xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build
```

Expected: 构建成功。

- [ ] **Step 4: 手动验证 tvOS focus**

在 tvOS 模拟器/Apple TV：

1. 进入番剧详情，滚动到标签 cell。
2. 用遥控器方向键在标签之间移动焦点。
3. 期望：焦点顺序正确；按确认键触发对应标签搜索；没有按钮被裁切。

- [ ] **Step 5: 提交**

```bash
git add tvOS/AniXPlayer/BangumiDetail/View/TagListTableViewCell.swift \
  tvOS/AniXPlayer/BangumiDetail/BangumiDetailViewController.swift
git commit -m "refactor(tvos): 标签列表改用 TagFlowView"
```

---

### Task 6: 统一方向策略

**Files:**
- Modify: `iOS/AniXPlayer/Vendor/Base/ViewController/NavigationController.swift`
- Modify: `iOS/AniXPlayer/Main/MediaLib/MediaLibNavigationController.swift`
- Modify: `iOS/AniXPlayer/Main/MediaLib/MediaLibViewController.swift`
- Modify: `iOS/AniXPlayer/Player/PlayerNavigationController.swift`
- Modify: `iOS/AniXPlayer/Player/PlayerViewController.swift:301-311, 483-487`
- Delete (if unused): `iOS/AniXPlayer/Helper/UIDevice+Helper.swift`

**Interfaces:**
- Produces: 基类 `NavigationController` 不再锁方向；`PlayerNavigationController`/`PlayerViewController` 统一横屏；`PlayerViewController.adaptivePresentationStyle` 使用 size class。

- [ ] **Step 1: 移除基类全局横屏锁**

删除 `NavigationController` 中 `shouldAutorotate`、`supportedInterfaceOrientations`、`preferredInterfaceOrientationForPresentation` 三个 override。

- [ ] **Step 2: 移除 MediaLib 的 idiom 方向锁**

删除 `MediaLibNavigationController` 和 `MediaLibViewController` 中基于 `UIDevice.current.isPad` 的 `shouldAutorotate`/`supportedInterfaceOrientations`/`preferredInterfaceOrientationForPresentation` override。

- [ ] **Step 3: 在 Player 容器统一横屏**

在 `PlayerNavigationController` 增加：

```swift
override var shouldAutorotate: Bool { true }
override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

@available(iOS 26.0, *)
override var prefersInterfaceOrientationLocked: Bool { true }
```

`PlayerViewController` 保留现有 `.landscape` override；在 iOS 26+ 同样增加 `prefersInterfaceOrientationLocked = true`。

- [ ] **Step 4: 修正 popover 判断**

`PlayerViewController.adaptivePresentationStyle` 改为：

```swift
func adaptivePresentationStyle(for controller: UIPresentationController, traitCollection: UITraitCollection) -> UIModalPresentationStyle {
    return traitCollection.horizontalSizeClass == .regular ? .popover : .none
}
```

- [ ] **Step 5: 清理 idiom helper**

```bash
grep -R "isaPad\|isPad" iOS/AniXPlayer --include="*.swift" | grep -v "Helper/UIDevice+Helper.swift"
```

Expected: 无输出（排除 helper 自身定义）。若无输出，删除 `UIDevice+Helper.swift`：

```bash
ruby scripts/xcode_project.rb ios remove iOS/AniXPlayer/Helper/UIDevice+Helper.swift
rm iOS/AniXPlayer/Helper/UIDevice+Helper.swift
```

如果还有合法引用，保留文件并在提交说明中解释。

- [ ] **Step 6: 构建 iOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 7: 手动验证**

1. iPhone 模拟器：主页、我的、媒体库在竖屏/横屏切换，布局不崩。
2. 从竖屏主页进入播放器：外屏应旋转到横屏。
3. Duo 外屏：播放器保持横屏，退出播放器返回主页后方向恢复。

- [ ] **Step 8: 提交**

```bash
git add iOS/AniXPlayer/Vendor/Base/ViewController/NavigationController.swift \
  iOS/AniXPlayer/Main/MediaLib/MediaLibNavigationController.swift \
  iOS/AniXPlayer/Main/MediaLib/MediaLibViewController.swift \
  iOS/AniXPlayer/Player/PlayerNavigationController.swift \
  iOS/AniXPlayer/Player/PlayerViewController.swift \
  iOS/AniXPlayer/Helper/UIDevice+Helper.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "refactor(ui): 统一 iPhone Duo 方向策略"
```

---

### Task 6B: 播放器 modal 页面适配

**Files:**
- Create: `iOS/AniXPlayer/Player/PlayerModalNavigationController.swift`
- Modify: `iOS/AniXPlayer/Player/PlayerViewController.swift:441-456, 731-790`
- Modify: `iOS/AniXPlayer/Player/Setting/PlayerSettingViewController.swift`
- Modify: `iOS/AniXPlayer/Player/PlayerControlAnimater.swift`
- 按需修改：`iOS/AniXPlayer/Player/Setting/MediaSettingViewController.swift`、`DanmakuSettingViewController.swift`、`iOS/AniXPlayer/Player/FilterDanmaku/FilterDanmakuViewController.swift`、`iOS/AniXPlayer/Player/DanmakuList/DanmakuListViewController.swift`、`iOS/AniXPlayer/Player/View/ColorManagementViewController.swift`

**Interfaces:**
- Consumes: `NavigationController`（已解锁）。
- Produces: `PlayerModalNavigationController`，播放器 modal 在外屏横屏；内屏忽略方向锁，页面按宽度自适应。

- [ ] **Step 1: 新增 PlayerModalNavigationController**

```swift
import UIKit

class PlayerModalNavigationController: NavigationController {
    override var shouldAutorotate: Bool { true }
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask { .landscape }
    override var preferredInterfaceOrientationForPresentation: UIInterfaceOrientation { .landscapeLeft }

    @available(iOS 26.0, *)
    override var prefersInterfaceOrientationLocked: Bool { true }
}
```

- [ ] **Step 2: 替换 PlayerViewController 中的 modal 容器**

把 `PlayerViewController` 中 5 处 `NavigationController(rootViewController:)` 替换为 `PlayerModalNavigationController(rootViewController:)`：

- `showFilesVCWithType`
- `filterDanmakuInDanmakuSettingViewController`
- `showDanmakuListInDanmakuSettingViewController`
- `searchDanmakuInDanmakuSettingViewController`
- `changeSubtitleFontInMediaSettingViewController`

- [ ] **Step 3: 加入工程**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Player/PlayerModalNavigationController.swift
```

- [ ] **Step 4: PlayerSettingViewController 布局检查**

保留 `PlayerSettingViewController` 自己的 `.landscape` / `.landscapeLeft` override（它直接由 `PlayerViewController` present，不在 `PlayerNavigationController` 里）。检查 `segmentedControl` 和 `selectedVC.view` 在窄宽度下的布局，不写死宽度。

- [ ] **Step 5: 播放器设置子页面检查**

`MediaSettingViewController`、`DanmakuSettingViewController`、`FilterDanmakuViewController`、`DanmakuListViewController` 的 table view 已 pin 到 `safeAreaLayoutGuide`，确认没有固定 row height 导致裁切；`preferredContentSize = CGSize(width: 300, height: 350)` 的 popover 在 compact 下会走 sheet，保持现状。

- [ ] **Step 6: 其他页面检查**

`ColorManagementViewController` 确认 collection/table 内容在窄宽度下可滚动；如果页面确实需要横屏专属布局，把它记录为已知限制，不在本轮强行改造。

- [ ] **Step 7: PlayerControlAnimater 宽度**

`PlayerControlAnimater` 的侧边面板宽度目前是 `containerView.frame.width * 0.5`；在窄宽度下加一个合理的最小值/上限，使用 `containerView.bounds.width` 和 size class，不要用屏幕宽度。

- [ ] **Step 8: 构建 iOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 9: 手动验证**

在 Duo 模拟器：

1. 外屏：打开播放器，再打开设置、弹幕列表、字幕、选集、投屏；确认 modal 保持横屏。
2. 内屏竖屏：重复上述操作；确认页面可用、控件不被裁切、列表可滚动。
3. 自定义侧边面板在窄宽度下不窄于可操作宽度。

- [ ] **Step 10: 提交**

```bash
git add iOS/AniXPlayer/Player/PlayerModalNavigationController.swift \
  iOS/AniXPlayer/Player/PlayerViewController.swift \
  iOS/AniXPlayer/Player/Setting/PlayerSettingViewController.swift \
  iOS/AniXPlayer/Player/Setting/MediaSettingViewController.swift \
  iOS/AniXPlayer/Player/Setting/DanmakuSettingViewController.swift \
  iOS/AniXPlayer/Player/FilterDanmaku/FilterDanmakuViewController.swift \
  iOS/AniXPlayer/Player/DanmakuList/DanmakuListViewController.swift \
  iOS/AniXPlayer/Player/View/ColorManagementViewController.swift \
  iOS/AniXPlayer/Player/PlayerControlAnimater.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "refactor(player): 适配播放器 modal 页面布局"
```

---

### Task 7: 播放器安全区与设计常量

**Files:**
- Create: `iOS/AniXPlayer/Player/View/PlayerUI/PlayerLayoutMetrics.swift`
- Modify: `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIBottomView.swift`
- Modify: `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUITopView.swift`
- Modify: `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIView.swift`
- Modify: `iOS/AniXPlayer/Player/View/PlayerUI/ProgressSlider.swift`

**Interfaces:**
- Produces: `PlayerLayoutMetrics` 常量；播放器控制栏内容约束到 `safeAreaLayoutGuide`。

- [ ] **Step 1: 新增 PlayerLayoutMetrics**

```swift
import UIKit

enum PlayerLayoutMetrics {
    static let barContentInset: CGFloat = 10
    static let playButtonSize: CGFloat = 50
    static let playButtonTopOffset: CGFloat = 20
    static let controlSpacing: CGFloat = 20
    static let danmakuInputHeight: CGFloat = 36
    static let danmakuInputCornerRadius: CGFloat = 18
    static let topBarVerticalPadding: CGFloat = 20
    static let backButtonSize: CGFloat = 30
}
```

- [ ] **Step 2: 修正 Player 顶部/底部控制栏约束**

`PlayerUIBottomView`：

- `containerView.leading/trailing` 改为 `self.safeAreaLayoutGuide`。
- `containerView.bottom` 保持 `self.safeAreaLayoutGuide.snp.bottom`。
- 固定值替换为 `PlayerLayoutMetrics` 常量。
- `bgView` 保持全宽。

`PlayerUITopView`：

- `containerView.top` 改为 `self.safeAreaLayoutGuide.snp.top`。
- `containerView.leading/trailing` 改为 `self.safeAreaLayoutGuide`。
- `backButton` 的 20/30 替换为 `PlayerLayoutMetrics` 常量。

`PlayerUIView`：

- 保留 `preservesSuperviewLayoutMargins`，但不要用它替代播放器控制栏的 safe area。
- 检查 `topView`/`bottomView` 仍约束到 superview 四边，由内部 safe area 处理内容。

- [ ] **Step 3: ProgressSlider 使用 iOS 17 trait registration**

在 `initializeLayers` 或初始化方法中：

```swift
if #available(iOS 17.0, *) {
    registerForTraitChanges([UITraitDisplayScale.self]) { (self: ProgressSlider, _) in
        self.updateContentsScale()
    }
}
```

`traitCollectionDidChange` 仅在 iOS 15/16 执行：

```swift
override public func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #available(iOS 17.0, *) { return }
    if previousTraitCollection?.displayScale != traitCollection.displayScale {
        updateContentsScale()
    }
}
```

- [ ] **Step 4: 加入 iOS 工程并构建**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Player/View/PlayerUI/PlayerLayoutMetrics.swift
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 5: 手动验证非对称 safe area**

1. iPhone 带 notch 的横屏播放：控制栏不被 notch 遮挡。
2. Duo 内屏竖屏播放：视频保持 16:9 letterbox，不拉伸/裁切。
3. Duo 内屏/外屏播放：顶部/底部控制栏在 safe area 内。
4. Duo 竖排 bar 场景：左右两侧至少一侧不被遮挡；控件可点。
5. 检查 `SnapshotPreviewView` 仍位于 bottom bar 上方，不被裁切。

- [ ] **Step 6: 提交**

```bash
git add iOS/AniXPlayer/Player/View/PlayerUI/PlayerLayoutMetrics.swift \
  iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIBottomView.swift \
  iOS/AniXPlayer/Player/View/PlayerUI/PlayerUITopView.swift \
  iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIView.swift \
  iOS/AniXPlayer/Player/View/PlayerUI/ProgressSlider.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "fix(player): 播放器控制栏使用安全区和统一间距"
```

---

### Task 8: 列表滚动容器与首页横滑

**Files:**
- Modify: `iOS/AniXPlayer/Files/FileBrowserViewController.swift:220-224`
- Modify: `iOS/AniXPlayer/HomePage/Banner/HomePageBannerTableViewCell.swift:157-165`
- Modify: `iOS/AniXPlayer/HomePage/Banner/HomePageBannerItemCell.swift:15-19`
- Modify: `iOS/AniXPlayer/HomePage/Function/HomePageFunctionTableViewCell.swift:46-60`

- [ ] **Step 1: 修正 FileBrowser table view**

把 table view 约束改回填满 safe area：

```swift
self.tableView.snp.makeConstraints { (make) in
    make.edges.equalTo(self.view.safeAreaLayoutGuide)
}
```

不要给 table view 的 leading/trailing 加 layout margins。

- [ ] **Step 2: 确认 Banner collection view 使用 layout margins**

`HomePageBannerTableViewCell` 的 collection view 保持：

```swift
collectionView.snp.makeConstraints { make in
    make.top.bottom.equalToSuperview()
    make.leading.trailing.equalTo(contentView.layoutMarginsGuide)
}
pageControl.snp.makeConstraints { make in
    make.bottom.equalToSuperview()
    make.centerX.equalTo(collectionView)
}
```

如果当前代码还是 `edges.equalToSuperview()`，按上面改。不要给 cell 加设备判断。

- [ ] **Step 3: 保留 banner 的装饰性 fill，并加注释**

`HomePageBannerItemCell` 保持 `contentMode = .scaleAspectFill`，在 `setupUI` 上方加一行说明：

```swift
// 横幅是装饰性背景，标题/描述是独立 overlay；Duo 宽屏下允许裁切两侧，不承载关键信息。
```

如果手动验证发现主体被裁切，改用 `.scaleAspectFit` 或在图片 URL 层设置 focal point；不要用设备型号判断。

- [ ] **Step 4: 去掉首页功能区的错误分页**

`HomePageFunctionTableViewCell` 中把：

```swift
collectionView.isPagingEnabled = true
```

改为：

```swift
collectionView.isPagingEnabled = false
```

保留 100pt item 宽度作为设计常量；宽屏下所有 item 自然排开，窄屏下可自由横向滚动。

- [ ] **Step 5: 构建 iOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 6: 手动验证**

1. iPhone compact：文件浏览器列表左右贴边，分隔线正常。
2. Duo 内屏 regular：文件浏览器不被额外缩进；首页 banner 不出现关键内容被裁切；功能入口横滑不出现半页。
3. iPad：列表和首页布局与现有设计一致。

- [ ] **Step 7: 提交**

```bash
git add iOS/AniXPlayer/Files/FileBrowserViewController.swift \
  iOS/AniXPlayer/HomePage/Banner/HomePageBannerTableViewCell.swift \
  iOS/AniXPlayer/HomePage/Banner/HomePageBannerItemCell.swift \
  iOS/AniXPlayer/HomePage/Function/HomePageFunctionTableViewCell.swift
git commit -m "fix(ui): 修正列表滚动容器和首页横滑布局"
```

---

### Task 9: 主界面 tab sidebar

**Files:**
- Modify: `iOS/AniXPlayer/Main/MainViewController.swift`

**Interfaces:**
- Consumes: iOS 27 `UITabBarControllerSidebar.preferredPlacement`。
- Produces: regular width 下 sidebar；compact 下 automatic。

- [ ] **Step 1: 增加 sidebar placement 更新**

在 `MainViewController` 中：

```swift
private func updateSidebarPlacement() {
    if #available(iOS 27.0, *) {
        sidebar.preferredPlacement = traitCollection.horizontalSizeClass == .regular ? .sidebar : .automatic
    }
}
```

在 `viewDidLoad` 末尾调用一次。

- [ ] **Step 2: 监听 size class 变化**

iOS 17+：

```swift
if #available(iOS 17.0, *) {
    registerForTraitChanges([UITraitHorizontalSizeClass.self]) { (self: MainViewController, _) in
        self.updateSidebarPlacement()
    }
}
```

iOS 15/16 用 `traitCollectionDidChange`：

```swift
override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
    super.traitCollectionDidChange(previousTraitCollection)
    if #available(iOS 17.0, *) { return }
    if previousTraitCollection?.horizontalSizeClass != traitCollection.horizontalSizeClass {
        updateSidebarPlacement()
    }
}
```

- [ ] **Step 3: 构建 iOS**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 4: 手动验证**

1. Duo 内屏 regular：tab bar 以 sidebar 形式显示；三个 tab 可切换；内容不被 sidebar 遮挡。
2. Duo 外屏 compact：底部 tab bar；切换正常。
3. iPad 竖屏/横屏：sidebar 显示；popover/sheet 行为正常；导航栈正常。
4. iPhone 普通尺寸：保持底部 tab bar。

- [ ] **Step 5: 提交**

```bash
git add iOS/AniXPlayer/Main/MainViewController.swift
git commit -m "feat(ui): 支持 iPhone Duo 和 iPad 侧边栏标签"
```

---

### Task 10: 播放器 Duo reserved region

**Files:**
- Create: `iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift`
- Create: `scripts/tests/player_reserved_region_layout_test.swift`
- Modify: `iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIView.swift`

**Interfaces:**
- Produces:

```swift
struct PlayerReservedRegionLayout {
    struct Context {
        var bounds: CGRect
        var divisionRegions: [CGRect]
        var occlusionRegions: [CGRect]
        var topBarHeight: CGFloat
        var bottomBarHeight: CGFloat
        var gap: CGFloat
    }

    struct Result: Equatable {
        var topBarOffset: CGFloat
        var bottomBarOffset: CGFloat
        var leadingInset: CGFloat
        var trailingInset: CGFloat
    }

    static func layout(context: Context) -> Result
}
```

- [ ] **Step 1: 写失败测试脚本**

创建 `scripts/tests/player_reserved_region_layout_test.swift`：

```swift
import CoreGraphics
import Foundation

func check(_ condition: Bool, _ message: String) {
    guard condition else { fatalError("FAIL: \(message)") }
}

func makeContext(
    bounds: CGRect = CGRect(x: 0, y: 0, width: 800, height: 400),
    division: [CGRect] = [],
    occlusion: [CGRect] = [],
    topBarHeight: CGFloat = 80,
    bottomBarHeight: CGFloat = 80,
    gap: CGFloat = 0
) -> PlayerReservedRegionLayout.Context {
    .init(
        bounds: bounds,
        divisionRegions: division,
        occlusionRegions: occlusion,
        topBarHeight: topBarHeight,
        bottomBarHeight: bottomBarHeight,
        gap: gap
    )
}

@main
struct PlayerReservedRegionLayoutTests {
    static func main() {
        let none = PlayerReservedRegionLayout.layout(context: makeContext())
        check(none == .init(topBarOffset: 0, bottomBarOffset: 0, leadingInset: 0, trailingInset: 0), "none")

let foldLeft = PlayerReservedRegionLayout.layout(
    context: makeContext(division: [CGRect(x: 100, y: 0, width: 20, height: 400)])
)
check(foldLeft.leadingInset == 120, "fold left leading: \(foldLeft.leadingInset)")
check(foldLeft.trailingInset == 0, "fold left trailing")

let foldRight = PlayerReservedRegionLayout.layout(
    context: makeContext(division: [CGRect(x: 680, y: 0, width: 20, height: 400)])
)
check(foldRight.trailingInset == 120, "fold right trailing: \(foldRight.trailingInset)")
check(foldRight.leadingInset == 0, "fold right leading")

let foldTop = PlayerReservedRegionLayout.layout(
    context: makeContext(division: [CGRect(x: 0, y: 100, width: 800, height: 20)])
)
check(foldTop.topBarOffset == 120, "fold top offset: \(foldTop.topBarOffset)")
check(foldTop.bottomBarOffset == 0, "fold top bottom")

let foldBottom = PlayerReservedRegionLayout.layout(
    context: makeContext(division: [CGRect(x: 0, y: 280, width: 800, height: 20)])
)
check(foldBottom.bottomBarOffset == 120, "fold bottom offset: \(foldBottom.bottomBarOffset)")
check(foldBottom.topBarOffset == 0, "fold bottom top")

let cameraTop = PlayerReservedRegionLayout.layout(
    context: makeContext(occlusion: [CGRect(x: 720, y: 0, width: 80, height: 40)])
)
check(cameraTop.topBarOffset == 40, "camera top offset: \(cameraTop.topBarOffset)")

let cameraBottom = PlayerReservedRegionLayout.layout(
    context: makeContext(occlusion: [CGRect(x: 0, y: 360, width: 80, height: 40)])
)
check(cameraBottom.bottomBarOffset == 40, "camera bottom offset: \(cameraBottom.bottomBarOffset)")

let combined = PlayerReservedRegionLayout.layout(
    context: makeContext(
        division: [CGRect(x: 100, y: 0, width: 20, height: 400)],
        occlusion: [CGRect(x: 720, y: 0, width: 80, height: 40)]
    )
)
check(combined.leadingInset == 120, "combined leading")
check(combined.topBarOffset == 40, "combined top")

        print("PlayerReservedRegionLayout tests passed")
    }
}
```

- [ ] **Step 2: 运行测试确认失败**

```bash
xcrun swiftc iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift scripts/tests/player_reserved_region_layout_test.swift -o /tmp/player_reserved_region_layout_test
```

Expected: 编译失败（`PlayerReservedRegionLayout.swift` 不存在，或提示找不到 `PlayerReservedRegionLayout`）。

- [ ] **Step 3: 实现 PlayerReservedRegionLayout**

算法要求：

- `bounds` 为空或尺寸为 0 时返回全 0。
- 对所有 `divisionRegions`：
  - 宽度小于高度（竖向 fold）：fold 在左半区时 `leadingInset = max(leadingInset, fold.maxX + gap)`；否则 `trailingInset = max(trailingInset, bounds.maxX - fold.minX + gap)`。
  - 宽度大于等于高度（横向 fold）：fold 在上半区时 `topBarOffset = max(topBarOffset, fold.maxY + gap)`；否则 `bottomBarOffset = max(bottomBarOffset, bounds.maxY - fold.minY + gap)`。
- 对所有 `occlusionRegions`：
  - 与顶部 bar 矩形相交时 `topBarOffset = max(topBarOffset, region.maxY + gap)`。
  - 与底部 bar 矩形相交时 `bottomBarOffset = max(bottomBarOffset, bounds.maxY - region.minY + gap)`。
- 最后把四个值 clamp 到 `0...bounds.width/height`。
- `Result` 实现 `Equatable`。

- [ ] **Step 4: 运行测试确认通过**

```bash
xcrun swiftc iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift scripts/tests/player_reserved_region_layout_test.swift -o /tmp/player_reserved_region_layout_test
/tmp/player_reserved_region_layout_test
```

Expected: 输出 `PlayerReservedRegionLayout tests passed`。

- [ ] **Step 5: 接入 PlayerUIView**

要求：

- `topView` 初始约束：`make.top.leading.trailing.equalToSuperview()`。
- `bottomView` 初始约束：`make.bottom.leading.trailing.equalToSuperview()`。
- `setupInit` 中 iOS 27.1+ 添加 `UIHingeInteraction`：

```swift
if #available(iOS 27.1, *) {
    let interaction = UIHingeInteraction { [weak self] _, _ in
        self?.setNeedsLayout()
    }
    addInteraction(interaction)
}
```

- 覆写 `layoutSubviews`，在 `super.layoutSubviews()` 后调用私有方法 `updateReservedRegionLayoutIfNeeded()`。
- 私有方法中：

```swift
guard #available(iOS 27.1, *) else { return }

let divisions = reservedRegions(kind: .division).map { $0.frame }
let occlusions = reservedRegions(kind: .occlusion).map { $0.frame }
let context = PlayerReservedRegionLayout.Context(
    bounds: bounds,
    divisionRegions: divisions,
    occlusionRegions: occlusions,
    topBarHeight: max(topView.bounds.height, 1),
    bottomBarHeight: max(bottomView.bounds.height, 1),
    gap: 8
)
let result = PlayerReservedRegionLayout.layout(context: context)
guard result != lastReservedRegionResult else { return }
lastReservedRegionResult = result

topView.snp.updateConstraints { make in
    make.top.equalToSuperview().offset(result.topBarOffset)
    make.leading.equalToSuperview().offset(result.leadingInset)
    make.trailing.equalToSuperview().offset(-result.trailingInset)
}
bottomView.snp.updateConstraints { make in
    make.bottom.equalToSuperview().offset(-result.bottomBarOffset)
    make.leading.equalToSuperview().offset(result.leadingInset)
    make.trailing.equalToSuperview().offset(-result.trailingInset)
}
```

- 增加 `private var lastReservedRegionResult: PlayerReservedRegionLayout.Result?`。
- iOS 27.1 以下直接 return。

- [ ] **Step 6: 加入 iOS 工程并构建**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
```

Expected: 构建成功。

- [ ] **Step 7: 手动验证 fold/camera**

在 iPhone Duo 模拟器：

1. 打开播放器，展开/半折叠设备，观察顶部/底部控制栏是否移动到 fold 的另一侧。
2. 激活内屏 camera（或模拟 camera occlusion），确认控制栏不被遮挡。
3. 竖屏/横屏各检查一次；控件仍可点击。

- [ ] **Step 8: 提交**

```bash
git add iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift \
  iOS/AniXPlayer/Player/View/PlayerUI/PlayerUIView.swift \
  scripts/tests/player_reserved_region_layout_test.swift \
  iOS/AniXPlayer.xcodeproj/project.pbxproj
git commit -m "feat(player): 播放器控制栏适配 Duo 折叠区域"
```

---

### Task 11: 最终验证与清理

**Files:** 无新增；仅修复验证中发现的问题。

- [ ] **Step 1: 运行两个纯布局测试**

```bash
xcrun swiftc Share/CocoaShare/View/TagFlow/TagFlowLayout.swift scripts/tests/tag_flow_layout_test.swift -o /tmp/tag_flow_layout_test
/tmp/tag_flow_layout_test
xcrun swiftc iOS/AniXPlayer/Player/View/PlayerUI/PlayerReservedRegionLayout.swift scripts/tests/player_reserved_region_layout_test.swift -o /tmp/player_reserved_region_layout_test
/tmp/player_reserved_region_layout_test
```

Expected: 两个脚本分别输出 `... tests passed`。

- [ ] **Step 2: 构建三平台**

```bash
xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
xcodebuild -project tvOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=tvOS' build
xcodebuild -project Mac/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'platform=macOS' build
```

Expected: 三个构建都成功。若 Mac scheme 名称不同，用 `xcodebuild -list -project Mac/AniXPlayer.xcodeproj` 确认。

- [ ] **Step 3: 跑官方 App Resizability 检查项**

```bash
grep -R "UIScreen.main" iOS/AniXPlayer Share/CocoaShare --include="*.swift"
grep -R "userInterfaceIdiom\|interfaceOrientation\|statusBarOrientation" iOS/AniXPlayer --include="*.swift"
grep -R "window?.screen\|window\.screen" iOS/AniXPlayer Share/CocoaShare --include="*.swift"
grep -R "UIScreen.main.bounds" iOS tvOS Share --include="*.swift"
```

Expected:

- `UIScreen.main` 在 iOS/Share 的布局代码中无命中；tvOS `focusedView` 例外需在提交说明中记录。
- `userInterfaceIdiom`/`interfaceOrientation` 无布局命中；方向 mask 相关命中可保留。
- `window?.screen`/`window.screen` 无命中。
- `UIScreen.main.bounds` 无命中。

- [ ] **Step 4: iPhone Duo 模拟器全 pose**

在 Device Hub 依次测试：

1. closed / outer display.
2. open / inner display.
3. partially folded / book pose.
4. partially folded / tent pose.
5. rotate each pose.
6. Split View multitasking（如模拟器支持）。

每项检查：主页、番剧详情标签、文件列表、播放器、播放器 modal、tab sidebar、banner、功能入口。

- [ ] **Step 5: iPhone Mirroring 极限尺寸**

在 macOS 27 的 iPhone Mirroring 中把窗口拖到极窄和极宽，检查：

- 主页 banner/功能入口不裁切。
- 番剧标签不重叠。
- 播放器控制栏不被推出屏幕。
- 文件列表不被额外缩进。

- [ ] **Step 6: 提交验证修复（如有）**

```bash
# 只添加验证过程中实际修改的文件，不要用 git add -A
git add <changed-files>
git commit -m "fix(ui): 修正 Duo 适配验证问题"
```

如果没有文件变化，跳过此步。

---

## Self-Review

- Spec coverage：全局布局规则（Task 1/6/6B/7/8/9）、TagFlowView（Task 2-5）、播放器安全区与 reserved region（Task 6/6B/7/10）、主界面 sidebar（Task 9）、全屏媒体（Task 8 验证）、trait/scale（Task 1/7）、测试（Task 2/10/11）均有对应任务。
- 类型一致性：`TagFlowLayout.Metrics`、`TagFlowView.Metrics`、`PlayerReservedRegionLayout.Context/Result` 在后续任务中名称一致。
- Review Focus 的五项分别落在 Task 6/6B（modal）、Task 4（标签折叠）、Task 7（safe area）、Task 9（sidebar）、Task 5（tvOS focus）的验证步骤中。
- 未包含 `UIArrangementViewController` 重构：设计文档已明确作为后续独立变更，本计划只做 reserved region。
