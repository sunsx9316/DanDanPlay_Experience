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

## 约束/Auto Layout 规范

### 使用 SnapKit

所有约束必须使用 SnapKit，**禁止**使用原生 NSLayoutConstraint 写法：

```swift
// 推荐 - SnapKit
iconImageView.snp.makeConstraints { make in
    make.leading.equalToSuperview().offset(15)
    make.centerY.equalToSuperview()
    make.width.height.equalTo(24)
}

// 不推荐 - 原生 Auto Layout
NSLayoutConstraint.activate([
    iv.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 15),
    iv.centerYAnchor.constraint(equalTo: contentView.centerYAnchor),
])
```

> **例外**：从 nib/storyboard 中已存在的约束（IBOutlet 引用），可用于修改 constant，不需要用 SnapKit 重建。

### 禁止在懒加载中写约束

懒加载（`lazy var`）只负责创建 view，**禁止**在其中调用 `addSubview` 或写约束。必须在外部（如 `awakeFromNib`、`init`、`setupUI` 等方法中）先 `addSubview` 后再加约束：

```swift
// 推荐 - 懒加载只创建 view
private lazy var iconImageView: UIImageView = {
    let iv = UIImageView()
    iv.contentMode = .scaleAspectFit
    iv.isHidden = true
    return iv
}()

override func awakeFromNib() {
    super.awakeFromNib()
    contentView.addSubview(iconImageView)
    iconImageView.snp.makeConstraints { make in
        make.leading.equalToSuperview().offset(15)
        make.centerY.equalToSuperview()
        make.width.height.equalTo(24)
    }
}

// 不推荐 - 懒加载中含 addSubview 和约束
private lazy var iconImageView: UIImageView = {
    let iv = UIImageView()
    contentView.addSubview(iv)  // 禁止！
    iv.snp.makeConstraints { ... }  // 禁止！
    return iv
}()
```

## 命名规范

- View 文件：`{Feature}View.swift`
- ViewController：`{Feature}ViewController.swift`
- 自定义 View：`{Feature}View.swift` 或 `{Feature}Control.swift`
