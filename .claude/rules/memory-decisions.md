# 内存管理决策

applyTo: "**/*.{swift,m,h}"

## ARC 规则

- 默认为强引用
- 闭包中捕获 self 时使用 `[weak self]` 或 `[unowned self]`
- `[weak self]` 用于可能释放的场景
- `[unowned self]` 用于 self 不会为 nil 的场景（如 deinit）

## 循环引用检测

常见循环引用模式：

### 1. 闭包持有 self

使用 `[weak self]` 后，必须用 `guard let self = self else { return }` 确保持有强引用：

```swift
// 推荐 - weak + guard 配对
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
    guard let self = self else { return }
    self.pollPlaybackState()
}

// 推荐 - 系统回调场景
panel.beginSheetModal(for: window) { [weak self] res in
    guard let self = self else { return }
    self.handleResponse(res)
}

// 不推荐 - 仅用 weak 但不解包
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
    self?.pollPlaybackState()  // 可用，但不符合本项目规范
}

// 不推荐 - 隐式强引用
Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
    self.pollPlaybackState()  // 循环引用！
}
```

**为什么需要 `guard let`？**
- `[weak self]` 允许 self 在闭包执行前被释放
- `guard let self = self else { return }` 确保闭包执行期间 self 有效
- 避免在闭包执行过程中 self 被 dealloc 导致崩溃

### 2. 组合模式（父-子对象）

子对象持有父对象时必须用 `weak`：

```swift
// 推荐 - weak 打破循环
class MPV {
    lazy var audio = AudioAPI(mpv: self)  // MPV → AudioAPI
}
class AudioAPI {
    private weak var player: MPV?  // AudioAPI → MPV (weak 打破)
}

// 不推荐 - 双向强引用
class AudioAPI {
    private let player: MPV  // 循环引用！
}
```

### 3. Delegate 模式

Delegate 必须用 `weak`：

```swift
// 推荐
protocol MPVViewDelegate: AnyObject {
    func mpvViewDidLoadFile(_ view: MPVView)
}

class MPVView {
    weak var delegate: MPVViewDelegate?
}
```

## 第三方库选择

### Auto Layout

| 库 | 适用场景 |
|---|---------|
| SnapKit | 代码布局首选 |
| Masonry | 遗留代码（Obj-C） |
| Apple 原生 | 简单约束 |

**本项目**：iOS 使用 SnapKit，Mac 使用原生 Auto Layout

### SnapKit 示例

```swift
view.addSubview(containerView)
containerView.snp.makeConstraints { make in
    make.edges.equalToSuperview()
}
```

## 内存泄漏排查工具

1. **Instruments Leaks** - 官方内存泄漏检测
2. **Instruments Allocations** - 跟踪对象分配
3. **Debug Memory Graph** - Xcode 可视化引用关系
4. **deinit 断点** - 验证对象是否正确释放
