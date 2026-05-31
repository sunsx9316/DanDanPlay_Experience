# iOS 编译规范

applyTo: "**/iOS/**"

## 优先使用真机编译

**始终优先使用真机设备进行编译**，避免模拟器链接问题。

```bash
# 推荐 - 真机编译
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build

# 不推荐 - 模拟器编译（mars.framework 仅支持真机架构，模拟器链接会失败）
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'platform=iOS Simulator,name=iPhone 17' build
```

## 原因

`ANXLog` 中的 `mars.framework` 只编译了 `arm64` 真机架构，不支持模拟器架构。模拟器编译会报错：

```
ld: building for 'iOS-simulator', but linking in object file
(.../mars.framework/mars[arm64]) built for 'iOS'
```

## 验证语法

如果只是为了检查语法错误（不链接），可以加 `-dry-run` 或只编译不链接：

```bash
xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO
```
