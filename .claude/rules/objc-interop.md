# Objective-C 互操作规范

applyTo: "**/*.{swift,m,h}"

## NS_DESIGNATED_INITIALIZER

所有 Objective-C 类必须显式标记指定初始化器：

```objc
// 推荐
@interface ANXView : UIView

- (instancetype)initWithFrame:(CGRect)frame NS_DESIGNATED_INITIALIZER;
- (instancetype)initWithCoder:(NSCoder *)coder NS_DESIGNATED_INITIALIZER;

@end

// 不推荐 - 缺少指定初始化器标记
- (instancetype)init { ... }
```

## @objc 暴露规则

Swift 类/方法暴露给 Objective-C 时：

```swift
// 推荐 - 显式标注 @objc
@objc class MediaPlayerFactory: NSObject {
    @objc func createPlayer() -> MediaPlayerProtocol { ... }
}

// 不推荐 - 隐式暴露（仅在确实需要时才这样做）
class MediaPlayerFactory { ... }
```

## Nullability 标注

所有 Objective-C 属性和方法参数必须标注 Nullability：

```objc
// 推荐
@property (nonatomic, strong, nullable) NSString *title;
- (void)configureWithTitle:(nonnull NSString *)title;

// 不推荐 - 未标注
@property (nonatomic, strong) NSString *title;
- (void)configureWithTitle:(NSString *)title;
```

## Swift 与 Objective-C 类型映射

| Swift | Objective-C | 说明 |
|-------|-------------|------|
| `String?` | `NSString * _Nullable` | 可空字符串 |
| `String` | `NSString * _Nonnull` | 非空字符串 |
| `[String]` | `NSArray<NSString *> *` | 数组 |
| `Int` | `NSInteger` | 整数 |

## 协议遵循

Swift 协议暴露给 Objective-C 时：

```swift
@objc protocol MediaPlayerDelegate: NSObjectProtocol {
    func mediaPlayerDidChangeState(_ player: MediaPlayerProtocol)
    @objc optional func mediaPlayerDidFinish(_ player: MediaPlayerProtocol)
}
```

## 泛型基类 + ObjC 可选协议方法 dispatch 陷阱

当 Swift 泛型基类遵循 ObjC 协议（如 `UITableViewDataSource`），子类需要覆盖协议的**可选方法**时，必须先在基类显式声明该方法，子类再用 `override` 覆盖。否则 UIKit 通过 `responds(to:)` 可能找不到子类的实现。

```swift
// 推荐 - 基类显式声明，子类 override
class BaseLoginHistoryViewController<F: File>: ViewController, UITableViewDataSource {
    // 必须在基类声明，即使只返回默认值
    func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
}

class SMBLoginHistoryViewController: BaseLoginHistoryViewController<SMBFile> {
    // 子类用 override 覆盖才可靠
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}

// 不推荐 - 基类未声明，子类直接写非 override 方法
class SMBLoginHistoryViewController: BaseLoginHistoryViewController<SMBFile> {
    // UIKit 可能找不到这个实现，导致默认行为（1 个 section）
    func numberOfSections(in tableView: UITableView) -> Int {
        return 2
    }
}
```

**高风险方法：** `numberOfSections(in:)`、`tableView(_:viewForHeaderInSection:)`、`heightForHeaderInSection:`、`heightForFooterInSection:` 等所有 `@objc optional` 的 `UITableViewDataSource`/`Delegate` 方法。
