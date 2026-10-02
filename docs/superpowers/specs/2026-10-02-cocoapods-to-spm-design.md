# CocoaPods → Swift Package Manager 迁移设计

## 概述

CocoaPods 已进入维护模式（官方 trunk 将于 2026-12-02 只读），且 Firebase 官方宣布 2026-10 起停止向 CocoaPods 发布新版本。本方案将 AniXPlayer 三个平台对 CocoaPods 的唯一依赖 `FirebaseCrashlytics` 迁移到 Swift Package Manager（SPM），并把 CocoaPods 从工程中**彻底移除**。

迁移后：

- iOS / macOS 通过 SPM 依赖 FirebaseCrashlytics（锁定最新稳定版 12.19.2）。
- tvOS 本就没有 Firebase 依赖，仅清理遗留的空 CocoaPods 产物。
- 打开与构建从 `.xcworkspace` 改为 `.xcodeproj`。
- iOS 部署目标统一为 15.0。

范围：iOS / macOS / tvOS 三平台工程文件、发布脚本、Git hooks、文档。

## 背景与约束

| 约束 | 说明 |
|------|------|
| 现状依赖面 | iOS/Mac 的 Podfile 只剩 `FirebaseCrashlytics` 一个 pod，其余依赖（Alamofire、Kingfisher、RxSwift、MPVFramework、VLCFramework、ANXLog 等）全部已是 SPM |
| tvOS | Podfile 全注释，无有效 pod；但仍有本地 `Pods/` 与引用它的 `.xcworkspace` |
| 代码使用量 | 仅 `Share/CocoaShare/Launcher.swift` 的 `FirebaseApp.configure()` + `import FirebaseCore`/`FirebaseCrashlytics`；`Mac/AniXPlayer/AppDelegate.swift` 有一个 `import FirebaseCore`。无任何 `recordError`/`setCustomValue` 等 Crashlytics API 调用 |
| iOS 部署目标 | App target 实际已是 15；项目级默认仍为 12.0 |
| macOS 部署目标 | App target 12.0；项目级默认 11.0 |
| Xcode | 26.6（Swift 6.3.3） |
| pbxproj 规则 | 项目规定「禁止手动编辑 pbxproj」，新增/删除文件用 `scripts/xcode_project.rb`（基于 `xcodeproj` gem） |
| 发布脚本 | `scripts/release/archive_and_export.sh` 目前用 `-workspace`；`release.sh` 有 CocoaPods 预检 |

## 关键决策与取舍

### 1. 依赖方式选择 SPM（而非手动集成 / 自建 specs 仓）

- 项目其余依赖已全部 SPM，纳入同一体系一致性最好。
- Firebase 官方推荐并持续维护 SPM 支持。
- 手动集成 xcframework / 自建 Pods specs 仓成本更高，仅在必须留在 CocoaPods 时才考虑，不采用。

### 2. Firebase 版本锁定 12.19.2（当前最新稳定版）

| Firebase | SPM 最低 iOS | 备注 |
|----------|--------------|------|
| 11.15.0 | iOS 12 / macOS 10.15 / tvOS 13 | iOS 现在用的 pod 版本 |
| **12.19.2** | **iOS 15 / macOS 10.15 / tvOS 15** | **本次采用**，当前最新已发布 tag |
| 13.0.0 | iOS 15 | 仅在 main 分支开发中、尚无发布 tag，不采用 |

- 用精确版本 `12.19.2`，保证可复现、避免解析到未来要求更高工具链的版本。
- `12.19.2` 要求 `swift-tools-version 6.1`（Xcode 16.3+），当前 Xcode 26.6 / Swift 6.3.3 满足。
- 升级到 12.19.2 相比原 12.10.0 不改变平台最低要求（仍 iOS 15 / macOS 10.15 / tvOS 15），无需额外改部署目标。
- products 选择：`FirebaseCrashlytics` 与显式 `FirebaseCore`（代码里有 `import FirebaseCore`）。
- 无需 `-ObjC` 链接标志（那是 FirebaseAnalytics 的要求，Crashlytics 不需要）。

### 3. 删除 `.xcworkspace`，改用 `.xcodeproj`

- CocoaPods 移除后 workspace 只剩单个工程，保留无意义。
- 所有 SPM 包均为远程包（无 `XCLocalSwiftPackageReference`），SPM 随 `.xcodeproj` 解析，不依赖 workspace。
- 同步更新 `archive_and_export.sh`、`.claude/rules/build-ios.md`、README、CLAUDE.md 中的 `-workspace` 用法。

### 4. iOS 部署目标提升到 15

- App target 已经是 15，本改动主要是对齐项目级默认值（12.0 → 15.0）与文档。
- 使 Firebase 12.x（要求 iOS 15）可用。

### 5. pbxproj 改动方式：新增一次性迁移脚本 `scripts/migrate_to_spm.rb`

- 用与 `xcode_project.rb` 相同的 `xcodeproj` gem（已验证 1.27.0，支持 `XCRemoteSwiftPackageReference` / `XCSwiftPackageProductDependency`）。
- 脚本按平台执行：添加 Firebase SPM package/product、删除 Pods xcconfig 引用与 `[CP]` build phase、修正 Crashlytics run-script 路径、iOS 项目级部署目标改 15。
- 保持职责分离：日常源文件增删仍用 `scripts/xcode_project.rb`，本脚本只服务这次迁移（可重复执行、幂等），迁移完成后保留作为记录。

### 6. Git hooks 安装改由 `scripts/bootstrap.sh`

- 原触发点是 `Podfile post_install`，迁移后不再存在。
- 新增 `scripts/bootstrap.sh`：首次 clone 后执行一次，内部调用 `scripts/install_hooks.sh`；README 快速开始里说明。
- 保留 `scripts/install_hooks.sh` 本身不变。

## 组件设计

### A. 工程文件改动（iOS / macOS）

对 `iOS/AniXPlayer.xcodeproj` 与 `Mac/AniXPlayer.xcodeproj`：

1. 新增远程 SPM 包
   - repositoryURL：`https://github.com/firebase/firebase-ios-sdk.git`
   - requirement：exact `12.19.2`
2. 给 target `AniXPlayer` 增加 product 依赖
   - `FirebaseCrashlytics`、`FirebaseCore`
   - 加入 target 的 `packageProductDependencies` 与 Frameworks build phase
3. 删除 CocoaPods 注入的 build settings / phase
   - 删除 App target Debug/Release 的 `baseConfigurationReference`（`Pods-AniXPlayer.*.xcconfig`）
   - 删除 `[CP] Check Pods Manifest.lock`、`[CP] Embed Pods Frameworks`、`[CP] Copy Pods Resources` 等 `[CP]` phase
4. 修改 Crashlytics dSYMS 上传 run-script 路径
   - 旧：`"${PODS_ROOT}/FirebaseCrashlytics/run"`
   - 新：`"${BUILD_DIR%Build/*}/SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run"`

业务代码不变。

### B. 工程文件改动（tvOS）

- 删除 `tvOS/AniXPlayer.xcworkspace/`（其中引用了 `Pods/Pods.xcodeproj`）。
- 删除 `tvOS/Podfile` 及本地 `tvOS/Pods/`。
- 无 Firebase，不加 SPM 包。

### C. 删除 CocoaPods 产物

版本控制中删除：

- `iOS/Podfile`、`Mac/Podfile`、`tvOS/Podfile`
- `iOS/AniXPlayer.xcworkspace/`、`Mac/AniXPlayer.xcworkspace/`、`tvOS/AniXPlayer.xcworkspace/`

本地未跟踪删除（不提交）：

- `iOS/Pods/`、`Mac/Pods/`、`tvOS/Pods/`
- `Podfile.lock`

`.gitignore` 清理 CocoaPods 相关条目（`Pods`、`Podfile.lock`）。

### D. 部署目标

- iOS：项目级 `IPHONEOS_DEPLOYMENT_TARGET` 12.0 → 15.0（App target 已为 15，不改）。
- macOS：不变。
- 文档：README「平台支持」iOS 最低版本 12.0 → 15.0；CLAUDE.md 关键约束同步。

### E. 发布脚本

- `scripts/release/archive_and_export.sh`：`-workspace "$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcworkspace"` → `-project "$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcodeproj"`。
- `scripts/release/release.sh`：删除「4. Pod install 检查」整段（对应 `Podfile.lock` / `Manifest.lock` 比对与 `pod install`）。

### F. Git hooks

- 新增 `scripts/bootstrap.sh`（可执行）：执行 `scripts/install_hooks.sh`；可扩展为以后一次性环境初始化入口。
- README 快速开始新增「首次 clone 后运行 `bash scripts/bootstrap.sh`」。

### G. 文档与规则更新

- `CLAUDE.md`：项目描述去掉 `+ CocoaPods`；构建命令 `.xcworkspace` → `.xcodeproj`；「打开项目用 `.xcworkspace`」「更新 Podfile 后运行 pod install」等约束改写；部署目标 iOS 12.0+ → 15.0+；移除「需运行 pod install」。
- `README.md`：环境要求去掉 CocoaPods；删除 `pod install` 步骤；打开工程改为 `.xcodeproj`；iOS 最低版本 15.0；新增 bootstrap 步骤。
- `.claude/rules/build-ios.md`：命令改为 `-project`，同步 iOS 15 说明。
- `.claude/rules/git-conventions.md`：删除「通过 Podfile 自动安装 hooks」的描述，改为 `scripts/bootstrap.sh`。
- `.claude/skills/release-app/SKILL.md`：删除 macOS `pod install` 检查步骤。

## 数据流 / 构建流程

迁移后构建流程：

1. clone 仓库。
2. `bash scripts/bootstrap.sh`（安装 Git hooks）。
3. 创建 `AppKey.swift`（既有流程不变）。
4. 打开 `iOS/AniXPlayer.xcodeproj`（不再是 workspace）。
5. 首次构建时 Xcode 自动解析并拉取 Firebase SPM 依赖。
6. Crashlytics 通过 run-script 从 SPM checkouts 上传 dSYM。

## 验证

- iOS：
  `xcodebuild -project iOS/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build CODE_SIGNING_ALLOWED=NO`
- macOS：
  `xcodebuild -project Mac/AniXPlayer.xcodeproj -scheme AniXPlayer -configuration Debug -destination 'platform=macOS' build`
- tvOS：
  用对应命令确认删除 Pods 引用后工程仍可解析/构建。
- 静态检查：
  - 三个 `project.pbxproj` 中不再出现 `PODS_ROOT`、`Pods-`、`[CP]`。
  - iOS/Mac 存在 `XCRemoteSwiftPackageReference "firebase-ios-sdk"` 与 `FirebaseCrashlytics` / `FirebaseCore` product。
  - Crashlytics run-script 指向 `SourcePackages/checkouts/firebase-ios-sdk/Crashlytics/run`。
- 脚本：`release.sh` / `archive_and_export.sh` 语法检查（`bash -n`）。

## 风险

| 风险 | 缓解 |
|------|------|
| 首次 SPM 解析需联网拉取 Firebase 依赖链，耗时较长 | 属预期；在验证步骤中显式构建一次完成缓存 |
| pbxproj 脚本化改动可能破坏工程 | 用 `xcodeproj` gem 操作 + `git diff` 检查 + 三平台构建验证 |
| Firebase 12.19.2 与当前工具链兼容性 | 其 manifest 为 swift-tools-version 6.1（Xcode 16.3+），当前 Xcode 26.6 / Swift 6.3.3 满足；平台要求 iOS 15 / macOS 10.15 / tvOS 15 与既有目标兼容；构建验证兜底 |
| 删除 workspace 影响其他脚本/文档引用 | 已系统性排查：`archive_and_export.sh`、`release.sh`、build-ios.md、README、CLAUDE.md、release-app skill |
| Git hooks 不再自动安装 | `scripts/bootstrap.sh` + README 明示 |

## 不做的事（YAGNI）

- 不引入 Firebase 的其它产品（Analytics / Performance 等）。
- 不改动 Crashlytics 业务逻辑或新增 API 调用。
- 不采用尚未发布 tag 的 Firebase 13.x（待其正式发布后再单独评估升级）。
- 不做与本迁移无关的工程重构。
