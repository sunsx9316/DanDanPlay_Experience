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
