# Apple UI/UX 规范

applyTo: "**/*View.swift"

## SwiftUI vs UIKit 选择原则

| 场景 | 推荐 | 原因 |
|------|------|------|
| 简单列表/表单 | SwiftUI | 开发效率高 |
| 复杂手势/自定义绘制 | UIKit | 更精细的控制 |
| 需要与现有 UIKit 集成 | UIKit | 渐进式迁移 |
| 跨平台需求 | SwiftUI | 共享代码 |

## 视图拆分原则

每个视图文件不超过 300 行，超过则拆分：

```swift
// 推荐 - 拆分职责
struct PlayerView: View {
    var body: some View {
        VStack {
            VideoPlayerView()      // 视频渲染
            ControlBarView()       // 控制栏
            SubtitleOverlayView()  // 字幕
        }
    }
}

// 不推荐 - 大而全的视图
struct PlayerView: View {
    var body: some View {
        // 500 行代码...
    }
}
```

## Combine vs Observation

| 场景 | 推荐 |
|------|------|
| iOS 13+ 兼容 | Combine |
| iOS 17+ 新项目 | Observation |
| 简单状态绑定 | @State / @Binding |

## UIViewController 规范

```swift
class PlayerViewController: UIViewController {

    // MARK: - Lifecycle

    override func viewDidLoad() {
        super.viewDidLoad()
        setupUI()
        setupBindings()
    }

    // MARK: - Private

    private func setupUI() { ... }
    private func setupBindings() { ... }
}
```

## 命名规范

- View 文件：`{Feature}View.swift`
- ViewController：`{Feature}ViewController.swift`
- 自定义 View：`{Feature}View.swift` 或 `{Feature}Control.swift`
