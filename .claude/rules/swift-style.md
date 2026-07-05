# Swift 编码风格规范

applyTo: "**/*.swift"

## 强制使用 guard

优先使用 `guard` 进行条件检查，减少嵌套层级：

```swift
// 推荐
func process(data: Data?) {
    guard let data = data else { return }
    // ...
}

// 不推荐
func process(data: Data?) {
    if let data = data {
        // ...
    }
}
```

## 禁止强制解包

除非 100% 确定值不为 nil，否则使用安全解包：

```swift
// 推荐
guard let value = optionalValue else { return }

// 不推荐
let value = optionalValue!
```

## 闭包捕获规则

存储闭包的数组/字典必须使用 `[weak self]`：

```swift
// 推荐
let setup = { [weak self] in
    guard let self = self else { return }
    self.mpv?.playback.setSpeed(self.speed)
}
initActions.append(setup)

// 不推荐 - func 嵌套函数会隐式捕获 self
func setup() { ... }
initActions.append(setup)
```

## didSet 与 newValue

- `didSet`：使用 `self.xxx` 读取当前属性值
- `set` 方法：使用 `newValue` 获取新值

```swift
// didSet
var speed: Double = 1.0 {
    didSet {
        let setup = { [weak self] in
            guard let self = self else { return }
            self.mpv?.playback.setSpeed(self.speed)  // 用 self.speed
        }
    }
}

// set
var currentSubtitle: SubtitleProtocol? {
    set {
        let setup = { [weak self] in
            if let sub = newValue as? Subtitle {  // 用 newValue
                self?.mpv?.subtitle.subtitleId = Int64(sub.trackId)
            }
        }
    }
}
```

## 异步编程

优先使用 `async/await`，避免嵌套回调：

```swift
// 推荐
func fetchData() async throws -> Data {
    let (data, _) = try await URLSession.shared.data(from: url)
    return data
}

// 不推荐
func fetchData(completion: @escaping (Data?) -> Void) { ... }
```

## 日志规范

**主工程中使用 `ANX.log` 进行日志输出**，不要使用 `print` 或 `NSLog`：

```swift
// 推荐
ANX.logInfo(.media, "播放开始: \(url)")
ANX.logDebug(.player, "缓冲进度: \(progress)")

// 不推荐
print("播放开始: \(url)")
```

日志分类（如 `.media`、`.player`）定义在 `ANXLog` 模块中，便于过滤和管控。

## 动态枚举优于硬编码

UI 中使用枚举时，遵循 `CaseIterable` + `displayName` 模式，避免写死选项：

```swift
// 推荐 - 动态枚举，扩展性好
enum CoreType: Int, CaseIterable {
    case vlc = 0
    case mpv = 1

    var displayName: String {
        switch self {
        case .vlc: return "VLC"
        case .mpv: return "MPV"
        }
    }
}

// UI 中使用
for coreType in MediaPlayer.CoreType.allCases {
    vc.addAction(.init(title: coreType.displayName, ...))
}

// 不推荐 - 写死选项
vc.addAction(.init(title: "VLC", ...))
vc.addAction(.init(title: "MPV", ...))
```

以后添加新选项只需修改 enum，UI 自动适配。

## 枚举定义顺序

枚举顺序即显示顺序，**不要用排序**，直接调整定义顺序：

```swift
// 推荐 - 调整定义顺序即可
enum GlobalSettingType: CaseIterable {
    case playerCore      // 第一位
    case fastMatch
    case autoLoadCustomDanmaku
    // ...
}

// 不推荐 - 用 sort 算法调整
return all.sorted { a, b in
    if a == .playerCore { return true }
    // ...
}
```

## 禁止魔数

**代码中不得硬编码数字字面量**，应定义为命名常量：

```swift
// 推荐
let pipTimescale: CMTimeScale = 600
let pipCaptureInterval: TimeInterval = 1.0 / 30.0
let pipBufferAlignment = 64
CMTime(seconds: position, preferredTimescale: pipTimescale)

// 不推荐
CMTime(seconds: position, preferredTimescale: 600)
let alignedStride = ((pipStride + 63) / 64) * 64
```

**豁免**：`0`、`1`、`-1`、`nil` 等用于边界检查、数组索引、循环步进的基础值不需要定义为常量。

**规则**：
- 常量名需体现用途（如 `pipTimescale`、`maxRetryCount`），不要用泛化名称（如 `timeScale`、`number`）
- 同一常量在多处使用时，应定义在共享模块或协议文件中，确保跨文件可见

## NSLocalizedString 使用规范

**所有展示类文案必须使用 `NSLocalizedString` 包装，禁止硬编码字符串**：

```swift
// 推荐 - NSLocalizedString 包装
titleLabel.stringValue = NSLocalizedString("发现新版本", comment: "")
btn.title = NSLocalizedString("自动更新", comment: "")

// 不推荐 - 硬编码字符串（即使只有中文）
titleLabel.stringValue = "发现新版本"
btn.title = "自动更新"
```

**使用 `NSLocalizedString` 后必须同步更新 `Localizable.xcstrings`**：

```json
// Localizable.xcstrings 格式
"中文原文" : {
  "localizations" : {
    "en" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "English"
      }
    },
    "zh-Hans" : {
      "stringUnit" : {
        "state" : "translated",
        "value" : "中文原文"
      }
    }
  }
}
```

**规则**：
- key 保留中文原文
- `en` 的 `value` 为英文翻译
- `zh-Hans` 的 `value` 为中文原文
- 每次添加或修改 `NSLocalizedString` 必须同步更新 `Localizable.xcstrings`

**应用语言切换**：
- 如需支持运行时语言切换，应使用 `LocalizedString()` 函数替代 `NSLocalizedString()`
- `LocalizedString()` 会根据 `Preferences.shared.appLanguage` 返回对应语言的翻译
- 不可切换的纯内部字符串（如日志、调试信息）仍使用 `NSLocalizedString()`

## 枚举存储规范

**已定义枚举存储时应使用枚举类型，而非 Int**：

```swift
// 推荐 - 存储枚举类型
@StoreWrapper(defaultValue: .vlc, key: .playerCore)
var playerCore: MediaPlayer.CoreType

// 不推荐 - 存储为 Int
@StoreWrapper(defaultValue: 0, key: .playerCore)
var playerCore: Int
```

**实现方式**：为枚举添加 `Storeable` 扩展（参见 `Store+Extension.swift`）：

```swift
extension MediaPlayer.CoreType: Storeable {
    static func create(from: Int) -> MediaPlayer.CoreType? {
        let rawValue = from
        return MediaPlayer.CoreType(rawValue: rawValue)
    }

    func toValue() -> Int {
        return self.rawValue
    }
}
```

**注意**：如果枚举 rawValue 类型为 `String`，则 `create` 和 `toValue` 的参数类型也要改为 `String`。

## Cell 注册与复用规范

**必须使用项目提供的 Helper 方法**，禁止手写字符串 identifier 和 `as!` 强制转型：

### UITableView

```swift
// 注册
tableView.registerClassCell(class: TitleTableViewCell.self)

// 复用
let cell = tableView.dequeueCell(class: TitleTableViewCell.self, indexPath: indexPath)
// 或
let cell = tableView.dequeueCell(class: TitleTableViewCell.self)

// 不推荐 — 手写 identifier + as! 强转
tableView.register(TitleTableViewCell.self, forCellReuseIdentifier: "TitleTableViewCell")
let cell = tableView.dequeueReusableCell(withIdentifier: "TitleTableViewCell", for: indexPath) as! TitleTableViewCell
```

### UICollectionView

```swift
// 注册
collectionView.registerClassCell(class: HomePageBannerItemCell.self)

// 复用
let cell = collectionView.dequeueCell(class: HomePageBannerItemCell.self, indexPath: indexPath)

// 不推荐 — 手写 identifier + as! 强转
collectionView.register(HomePageBannerItemCell.self, forCellWithReuseIdentifier: "HomePageBannerItemCell")
let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "HomePageBannerItemCell", for: indexPath) as! HomePageBannerItemCell
```

### Mac NSTableView

```swift
// 注册
tableView.registerClassCell(class: LoginHistoryCellView.self)

// 复用
let cell = tableView.dequeueReusableCell(class: LoginHistoryCellView.self)

// 不推荐 — 手写 identifier + if-let 创建
let cellId = NSUserInterfaceItemIdentifier("LoginHistoryCell")
var cell = tableView.makeView(withIdentifier: cellId, owner: nil) as? LoginHistoryCellView
if cell == nil {
    cell = LoginHistoryCellView()
    cell?.identifier = cellId
}
```

### Mac NSCollectionView

```swift
// 注册
collectionView.registerItem(class: TimelineItem.self)

// 复用
let item = collectionView.dequeueItem(class: TimelineItem.self, for: indexPath)

// 不推荐 — 手写 identifier + as! 强转
collectionView.register(TimelineItem.self, forItemWithIdentifier: NSUserInterfaceItemIdentifier("TimelineItem"))
let item = collectionView.makeItem(withIdentifier: NSUserInterfaceItemIdentifier("TimelineItem"), for: indexPath) as! TimelineItem
```

**Helper 位置**：
- iOS: `iOS/AniXPlayer/Helper/UITableView+Helper.swift`、`UICollectionView+Helper.swift`
- Mac: `Mac/AniXPlayer/Base/Helper/NSTableView+Utils.swift`、`Mac/AniXPlayer/Helper/NSCollectionView+Helper.swift`

**规则**：
- ReuseIdentifier 统一用类名，由 Helper 自动处理
- 禁止手写字符串 identifier
- 禁止 `as!` 强制转型 cell
- Mac 的 `dequeueReusableCell` 返回非 `Optional`，直接 `.` 访问成员，不用 `?.`

## ImageView 缩放模式

**必须使用 `setScaling(_:)` 方法**设置缩放模式，使用项目自定义的 `ImageScaling` 枚举。**禁止**直接设置 `imageScaling` 属性：

```swift
// 推荐 — 使用 setScaling
let iv = ImageView()
iv.setScaling(.aspectFit)
iv.setScaling(.aspectFill)
iv.setScaling(.proportionallyDown)
iv.setScaling(.scaleToFill)
iv.setScaling(.none)

// 不推荐 — 直接设置原生 imageScaling
iv.imageScaling = .scaleProportionallyUpOrDown
iv.imageScaling = .scaleAxesIndependently
iv.imageScaling = .scaleNone
iv.imageScaling = .scaleProportionallyDown
```

`ImageScaling` 枚举值与原生 `NSImageScaling` 对应关系：

| ImageScaling | NSImageScaling | 说明 |
|---|---|---|
| `.none` | `.scaleNone` | 不缩放 |
| `.scaleToFill` | `.scaleAxesIndependently` | 拉伸填充 |
| `.aspectFit` | `.scaleProportionallyUpOrDown` | 等比缩放适配 |
| `.aspectFill` | `.scaleNone` + layer `resizeAspectFill` | 等比缩放填满（裁剪） |
| `.proportionallyDown` | `.scaleProportionallyDown` | 仅缩小，不放大 |

**原因**：macOS `NSImageView` 不支持 `scaleAspectFill`，`ImageView` 基类通过 `setScaling(.aspectFill)` 内部用 CALayer 实现，直接设 `imageScaling` 无法使用此模式。
