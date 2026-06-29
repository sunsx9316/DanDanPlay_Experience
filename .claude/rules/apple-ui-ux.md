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

## UITableViewCell / NSTableView / NSOutlineView Cell 规范

**Cell 必须抽取为独立类文件**，禁止在 `cellForRowAt` / `viewFor tableColumn` / `viewFor item` 代理方法中内联构造子视图和约束。

### iOS (UITableViewCell / UICollectionViewCell)

```swift
// 推荐 — 独立 cell 类，子视图在 init 中创建
class MatchsCell: UITableViewCell {
    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        // 子视图创建 + SnapKit 约束
    }
}

// 代理方法只做复用 + 数据配置
func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
    let cell = tableView.dequeueCell(class: MatchsCell.self, indexPath: indexPath)
    cell.label.text = data[indexPath.row]
    return cell
}

// 不推荐 — cellForRowAt 中内联 addSubview + 约束
```

### Mac (NSTableCellView / NSOutlineView)

```swift
// 推荐 — 独立 cell 类，子视图在 init(frame:) 中创建
class ServerHostCellView: NSTableCellView {
    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        // 子视图创建 + SnapKit 约束
    }
}

// 代理方法只做复用 + 数据配置
func outlineView(_ outlineView: NSOutlineView, viewFor ...) -> NSView? {
    let cell = outlineView.makeView(withIdentifier: cellId, owner: nil) as? ServerHostCellView
        ?? ServerHostCellView()
    cell.identifier = cellId
    cell.textField?.stringValue = ...
    return cell
}
```

**规则**：
- Cell 类文件命名：`{Feature}CellView.swift`（Mac）或 `{Feature}Cell.swift`（iOS）
- 子视图和约束始终在 `init` 中完成
- 代理方法只负责取出 cell 并配置数据，不做 view 构建

## 命名规范

- View 文件：`{Feature}View.swift`
- ViewController：`{Feature}ViewController.swift`
- 自定义 View：`{Feature}View.swift` 或 `{Feature}Control.swift`
