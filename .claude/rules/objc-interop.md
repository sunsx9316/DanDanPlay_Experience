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
