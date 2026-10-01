# iOS 打赏与支持者解锁 实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 在 iOS 版加入可重复的消耗型打赏，以及一次购买后永久解锁专属图标/徽章的非消耗型"支持者"商品，全部基于 StoreKit 2，无自建服务器、无 iCloud。

**Architecture:** iOS 15+ 使用 StoreKit 2。`SupporterManager` 负责商品加载、购买、`Transaction.updates` 监听与权益判定；`SupporterConfig` 配置商品 ID（未配置则整功能隐藏）；设置页新增入口进入 `SupporterViewController`；`SupporterIconManager` 负责备用 App 图标切换。

**Tech Stack:** Swift、UIKit、SnapKit、RxSwift、StoreKit 2、String Catalog（`Localizable.xcstrings`）。

**Spec:** `docs/superpowers/specs/2026-10-02-ios-supporter-design.md`（实现者需同时阅读该 spec）

## Global Constraints

- 功能**仅 iOS 15+**；低版本与 Mac/tvOS 不展示入口，但共享代码必须能编译。
- 只用 **StoreKit 2**，不做 StoreKit 1 回退。
- **不使用自建服务器，不读取/写入 iCloud**。
- 商品 ID 与价格**不硬编码**；价格一律来自 StoreKit 本地化结果。
- 解锁只由**非消耗型** `supporter` 商品决定；消耗型购买**不解锁**。
- 新增文件必须用 `ruby scripts/xcode_project.rb ios add <相对路径>` 加入工程；**禁止手改 pbxproj**。
- 代码注释与用户可见文案使用中文；`NSLocalizedString` 的 key 为中文。
- 项目**没有单元测试 target**：本计划每个任务的自动校验为 `xcodebuild ... build` 成功；StoreKit 行为通过 `Supporter.storekit` 本地配置 + 手动清单验证（详见各任务）。
- iOS 构建命令：
  ```bash
  xcodebuild -workspace iOS/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'generic/platform=iOS' build
  ```

## Review Focus

以下行为 spec 隐含但本项目无自动化测试覆盖，最容易被实现疏漏；每条在对应任务的验证步骤中手动确认：

1. **未配置商品**（`SupporterConfig.isConfigured == false`）时，"支持开发者"入口必须完全不出现，而不是出现后点击报错。
2. **消耗型购买不得解锁**图标/徽章——只有非消耗型 `supporter` 购买后才解锁。
3. **退款/撤销**后 `revocationDate != nil`，权益应重新变为未解锁。
4. App 启动时若存在**未完成交易**，必须 `finish()`，否则 StoreKit 会反复提示。
5. 新增 `GlobalSettingType.supporter` 后，**Mac target 必须仍能编译**（穷尽 `switch`）。

---

### Task 1: 商品配置与本地 StoreKit 测试环境

**Files:**
- Create: `iOS/AniXPlayer/Supporter/SupporterConfig.swift`
- Create: `iOS/AniXPlayer/Resource/Supporter.storekit`
- Modify: `iOS/AniXPlayer.xcodeproj/xcshareddata/xcschemes/AniXPlayer.xcscheme`（通过 Xcode GUI 配置，不手改 XML）

**Interfaces:**
- Produces:
  - `enum SupporterConfig`
    - `static let supporterProductID: String`（非消耗型，默认空）
    - `static let tipProductIDs: [String]`（消耗型，默认空）
    - `static var allProductIDs: [String]`
    - `static var isConfigured: Bool`

- [ ] **Step 1: 创建 `SupporterConfig.swift`**

内容（默认留空 → 功能隐藏；fork 用户填自己的商品 ID）：

```swift
import Foundation

/// 内购商品配置。留空则隐藏"支持开发者"入口。
/// fork 后请填写自己在 App Store Connect 创建的商品 ID。
enum SupporterConfig {
    /// 非消耗型：购买后永久解锁专属图标与徽章（App Store 账号可恢复）
    static let supporterProductID = ""

    /// 消耗型：可重复打赏，不解锁任何回报
    static let tipProductIDs: [String] = []

    static var allProductIDs: [String] {
        var ids: [String] = []
        if !supporterProductID.isEmpty { ids.append(supporterProductID) }
        ids.append(contentsOf: tipProductIDs)
        return ids
    }

    /// 是否已配置商品；未配置时整个入口隐藏
    static var isConfigured: Bool {
        !supporterProductID.isEmpty && !tipProductIDs.isEmpty
    }
}
```

- [ ] **Step 2: 加入 Xcode 工程**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Supporter/SupporterConfig.swift
```

- [ ] **Step 3: 创建 `Supporter.storekit` 本地测试配置**

**推荐用 Xcode GUI 创建**（File → New → File → StoreKit Configuration File，命名 `Supporter.storekit`，保存到 `iOS/AniXPlayer/Resource/`），在编辑器里点击 "+" 添加 1 个非消耗型 + 3 个消耗型商品。GUI 生成的 schema 最稳，避免手写 JSON 版本不兼容。

商品清单（本地测试 ID，可自定）：
- 非消耗型：`com.dandanplay.anixplayer.supporter`（"成为支持者"，如 ¥18）
- 消耗型：`com.dandanplay.anixplayer.tip6` / `.tip18` / `.tip48`（"奶茶"三档）

`.storekit` 不是资源文件，**不要**加入任何 build phase（脚本只会把它加进 group）：

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Resource/Supporter.storekit
```

> 说明：本任务提交的 `SupporterConfig.swift` 商品 ID 保持**空**。上面这些测试 ID 只在**本地手动验证时**临时填入，验证完请改回空再提交；不要提交测试 ID。

若选择手写（不推荐，schema 可能随 Xcode 版本变化），可参考以下内容：

```json
{
  "identifier" : "SUPPORTER_TEST",
  "nonRenewingSubscriptions" : [],
  "products" : [
    { "displayPrice" : "18", "familyShareable" : false, "internalID" : "1", "localizations" : [ { "description" : "解锁支持者专属图标与徽章", "displayName" : "成为支持者", "locale" : "zh_CN" } ], "productID" : "com.dandanplay.anixplayer.supporter", "referenceName" : "Supporter", "type" : "NonConsumable" },
    { "displayPrice" : "6", "familyShareable" : false, "internalID" : "2", "localizations" : [ { "description" : "请开发者喝杯奶茶", "displayName" : "奶茶·小杯", "locale" : "zh_CN" } ], "productID" : "com.dandanplay.anixplayer.tip6", "referenceName" : "Tip6", "type" : "Consumable" },
    { "displayPrice" : "18", "familyShareable" : false, "internalID" : "3", "localizations" : [ { "description" : "请开发者喝杯奶茶", "displayName" : "奶茶·中杯", "locale" : "zh_CN" } ], "productID" : "com.dandanplay.anixplayer.tip18", "referenceName" : "Tip18", "type" : "Consumable" },
    { "displayPrice" : "48", "familyShareable" : false, "internalID" : "4", "localizations" : [ { "description" : "请开发者喝杯奶茶", "displayName" : "奶茶·大杯", "locale" : "zh_CN" } ], "productID" : "com.dandanplay.anixplayer.tip48", "referenceName" : "Tip48", "type" : "Consumable" }
  ],
  "settings" : { "_locale" : "zh_CN", "_storeKitErrors" : [] },
  "subscriptionGroups" : [],
  "version" : { "major" : 3, "minor" : 0 }
}
```

- [ ] **Step 4: 在 Xcode GUI 将 StoreKit 配置挂到 Run scheme**

Xcode → Product → Scheme → Edit Scheme → Run → Options → StoreKit Configuration → 选择 `Supporter.storekit`。此设置写入 `.xcscheme`，请通过 GUI 完成。

- [ ] **Step 5: 构建验证**

Run: 上面的 iOS 构建命令
Expected: `BUILD SUCCEEDED`

- [ ] **Step 6: Commit**

```bash
git add iOS/AniXPlayer/Supporter/SupporterConfig.swift iOS/AniXPlayer/Resource/Supporter.storekit iOS/AniXPlayer.xcodeproj
git commit -m "feat(supporter): 添加内购商品配置与本地 StoreKit 测试配置"
```

---

### Task 2: `SupporterManager`（商品加载 / 购买 / 权益 / updates）

**Files:**
- Create: `iOS/AniXPlayer/Supporter/SupporterManager.swift`

**Interfaces:**
- Consumes: `SupporterConfig`（Task 1）
- Produces:
  - `@available(iOS 15.0, *) final class SupporterManager`
    - `static let shared: SupporterManager`
    - `let isSupporter: BehaviorSubject<Bool>`（RxSwift）
    - `func start()`
    - `func loadProducts() async -> [Product]`
    - `func purchase(_ product: Product) async throws -> Bool`（true=成功）
    - `func restore() async`

- [ ] **Step 1: 创建 `SupporterManager.swift`**

按下列实现（StoreKit 2 逻辑不在签名中可推断，故给出主体）：

```swift
import Foundation
import StoreKit
import RxSwift

@available(iOS 15.0, *)
final class SupporterManager {
    static let shared = SupporterManager()

    /// 是否已解锁支持者权益（非消耗型 supporter）
    let isSupporter = BehaviorSubject<Bool>(value: false)

    private var updatesTask: Task<Void, Never>?

    private init() {}

    /// App 启动时调用：监听交易并刷新权益
    func start() {
        guard updatesTask == nil else { return }
        updatesTask = Task { [weak self] in
            for await result in Transaction.updates {
                guard let self = self else { return }
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    await self.refreshEntitlements()
                }
            }
        }
        Task { await refreshEntitlements() }
    }

    /// 拉取已配置的商品
    func loadProducts() async -> [Product] {
        do {
            return try await Product.products(for: SupporterConfig.allProductIDs)
        } catch {
            return []
        }
    }

    /// 购买；返回是否成功
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            guard case .verified(let transaction) = verification else { return false }
            await transaction.finish()
            // 只有非消耗型 supporter 影响解锁
            if transaction.productID == SupporterConfig.supporterProductID {
                await refreshEntitlements()
            }
            return true
        case .userCancelled:
            return false
        case .pending:
            return false
        @unknown default:
            return false
        }
    }

    /// 恢复购买：同步 App Store 账号后刷新权益
    func restore() async {
        try? await AppStore.sync()
        await refreshEntitlements()
    }

    /// 权益判定：拥有未撤销的 supporter 非消耗型
    func refreshEntitlements() async {
        var owned = false
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result,
               transaction.productID == SupporterConfig.supporterProductID,
               transaction.revocationDate == nil {
                owned = true
            }
        }
        isSupporter.onNext(owned)
    }
}
```

- [ ] **Step 2: 加入工程并构建**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Supporter/SupporterManager.swift
```
Run: iOS 构建命令
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: Commit**

```bash
git add iOS/AniXPlayer/Supporter/SupporterManager.swift iOS/AniXPlayer.xcodeproj
git commit -m "feat(supporter): 添加 StoreKit 2 商品与权益管理"
```

---

### Task 3: `SupporterViewController`（打赏 / 支持页面）

**Files:**
- Create: `iOS/AniXPlayer/Supporter/SupporterViewController.swift`

**Interfaces:**
- Consumes: `SupporterManager`（Task 2）、`SupporterConfig`（Task 1）
- Produces: `@available(iOS 15.0, *) final class SupporterViewController: ViewController`，无参 `init()`。

页面结构（用 `UIScrollView` + 垂直 `UIStackView`，风格参考 `iOS/AniXPlayer/Setting/SetMainColorViewController.swift`，约束用 SnapKit）：

1. 说明标签（开源、自愿、用途）。
2. **成为支持者**区块：`TitleDetailMoreTableViewCell` 风格的按钮/行，标题来自 `Product.displayName`，副标题为 `Product.displayPrice`；已解锁时显示"已支持"并禁用购买。
3. **请我喝杯奶茶**区块：遍历 `tipProductIDs` 对应的 `Product`，每个一行，标题 `displayName`、副标题 `displayPrice`；点击即购买，成功弹 HUD `"感谢你的支持！"`。
4. **恢复购买**按钮。

关键逻辑：

```swift
import UIKit
import StoreKit
import RxSwift
import SnapKit

@available(iOS 15.0, *)
final class SupporterViewController: ViewController {
    private let manager = SupporterManager.shared
    private let bag = DisposeBag()
    private var supporterProduct: Product?
    private var tipProducts: [Product] = []

    override func viewDidLoad() {
        super.viewDidLoad()
        self.title = NSLocalizedString("支持开发者", comment: "")
        self.setupUI()
        self.bind()
        Task { await self.load() }
    }

    private func load() async {
        let products = await manager.loadProducts()
        self.supporterProduct = products.first { $0.id == SupporterConfig.supporterProductID }
        self.tipProducts = products.filter { SupporterConfig.tipProductIDs.contains($0.id) }
        self.reloadProducts()
    }

    private func bind() {
        manager.isSupporter.subscribe(onNext: { [weak self] _ in
            self?.reloadProducts()
        }).disposed(by: bag)
    }

    private func buy(_ product: Product) {
        Task {
            do {
                let ok = try await manager.purchase(product)
                if ok { self.view.showHUD(NSLocalizedString("感谢你的支持！", comment: "")) }
            } catch {
                self.view.showHUD(NSLocalizedString("购买失败，请稍后再试", comment: ""))
            }
        }
    }

    @objc private func onTouchRestore() {
        Task {
            await manager.restore()
            self.view.showHUD(NSLocalizedString("已恢复购买", comment: ""))
        }
    }
}
```

（`setupUI()` / `load()` / `reloadProducts()` 为私有方法，实现者按上述结构搭建；`view.showHUD(_:)` 为项目现有扩展。）

- [ ] **Step 1: 创建并加入工程**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Supporter/SupporterViewController.swift
```

- [ ] **Step 2: 构建验证**

Run: iOS 构建命令
Expected: `BUILD SUCCEEDED`

- [ ] **Step 3: 手动验证（StoreKit 本地配置）**

临时把 `SupporterConfig` 的商品 ID 改为 Task 1 中的测试 ID，运行 App 后从代码临时入口打开该 VC（入口在 Task 4 接入，可先临时写死）：
- 显示 1 个支持者商品 + 3 个奶茶档位，价格来自 StoreKit；
- 点"请我喝奶茶"→ 成功 HUD，**图标/徽章状态不变**（Review Focus 2）；
- 点"成为支持者"→ 成功 HUD，`isSupporter` 变 true；
- 再从 StoreKit 事务管理器触发退款 → 状态回到未支持（Review Focus 3）。

- [ ] **Step 4: Commit**

```bash
git add iOS/AniXPlayer/Supporter/SupporterViewController.swift iOS/AniXPlayer.xcodeproj
git commit -m "feat(supporter): 添加支持者与打赏页面"
```

---

### Task 4: 设置页入口接入

**Files:**
- Modify: `Share/CocoaShare/Enum.swift`（`GlobalSettingType` 加 `.supporter` + `title`）
- Modify: `Share/CocoaShare/Model/GlobalSetting/GlobalSettingModel.swift`（`subtitle` 补分支 + `allSettingType()` 过滤）
- Modify: `iOS/AniXPlayer/Setting/SettingViewController.swift`（cell + 跳转 + 配置过滤）
- Modify: `Mac/AniXPlayer/Setting/GlobalSettingViewController.swift`（补空分支，保证编译）

**Interfaces:**
- Consumes: `SupporterConfig`、`SupporterViewController`
- Produces: 设置页 `.supporter` 行，点击 push `SupporterViewController`。

- [ ] **Step 1: `Enum.swift` 加 case 与 title**

在 `GlobalSettingType` 增加 `case supporter`，并在 `title` 的 switch 增加：

```swift
case .supporter:
    return NSLocalizedString("支持开发者", comment: "")
```

- [ ] **Step 2: `GlobalSettingModel.subtitle` 补分支**

在 `subtitle(settingType:)` 的 switch 增加（Mac 死分支，仅为穷尽性）：

```swift
case .supporter:
    return NSLocalizedString("感谢你的支持", comment: "")
```

- [ ] **Step 3: `allSettingType()` 按平台与版本过滤**

在 `allSettingType()` 中 `return types` 之前加入：

```swift
#if os(iOS)
if #available(iOS 15.0, *) {
    // iOS 15+ 展示，低版本隐藏
} else {
    types.removeAll { $0 == .supporter }
}
#else
types.removeAll { $0 == .supporter }
#endif
```

- [ ] **Step 4: iOS `SettingViewController` —— dataSource 按配置过滤**

修改 `dataSource`：

```swift
private var dataSource: [GlobalSettingType] {
    var types = self.model.allSettingType()
    if !SupporterConfig.isConfigured {
        types.removeAll { $0 == .supporter }
    }
    return types
}
```

- [ ] **Step 5: iOS `SettingViewController` —— cellForRowAt 加 `.supporter`**

在 `cellForRowAt` 的 switch 增加：

```swift
case .supporter:
    let cell = tableView.dequeueCell(class: TitleDetailMoreTableViewCell.self, indexPath: indexPath)
    cell.titleLabel.text = type.title
    if #available(iOS 15.0, *) {
        let supported = (try? SupporterManager.shared.isSupporter.value()) == true
        cell.subtitleLabel.text = supported
            ? NSLocalizedString("已支持", comment: "")
            : NSLocalizedString("感谢你的支持", comment: "")
    } else {
        cell.subtitleLabel.text = ""
    }
    return cell
```

- [ ] **Step 6: iOS `SettingViewController` —— didSelectRowAt 跳转**

在 `didSelectRowAt` 的 if/else 链尾增加：

```swift
else if type == .supporter {
    if #available(iOS 15.0, *) {
        let vc = SupporterViewController()
        self.navigationController?.pushViewController(vc, animated: true)
    }
}
```

- [ ] **Step 7: Mac `GlobalSettingViewController` 补空分支**

在 `cellForRowAt` 的 switch 增加（Mac 不展示，仅为穷尽性）：

```swift
case .supporter:
    return nil
```

- [ ] **Step 8: 构建验证（iOS 与 Mac）**

Run: iOS 构建命令
Expected: `BUILD SUCCEEDED`
Run: `xcodebuild -workspace Mac/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Debug -destination 'platform=macOS' build`
Expected: `BUILD SUCCEEDED`（确认共享枚举改动不破坏 Mac，Review Focus 5）

- [ ] **Step 9: 手动验证**

在 `SupporterConfig` 填入测试 ID → 设置页出现"支持开发者"，副标题"感谢你的支持"，点击进入页面；把 `SupporterConfig` 清空 → 入口消失（Review Focus 1）。

- [ ] **Step 10: Commit**

```bash
git add Share/CocoaShare/Enum.swift Share/CocoaShare/Model/GlobalSetting/GlobalSettingModel.swift iOS/AniXPlayer/Setting/SettingViewController.swift Mac/AniXPlayer/Setting/GlobalSettingViewController.swift
git commit -m "feat(supporter): 设置页接入支持开发者入口"
```

---

### Task 5: 支持者专属 App 图标

**Files:**
- Create: `iOS/AniXPlayer/Assets.xcassets/AppIcon_Supporter.appiconset/`（图标 PNG 由作者提供）
- Create: `iOS/AniXPlayer/Supporter/SupporterIconManager.swift`
- Modify: `iOS/AniXPlayer/Supporter/SupporterViewController.swift`（解锁后显示图标选择）
- 配置: iOS target Build Setting `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES = AppIcon_Supporter`（经 Xcode GUI 设置）

**Interfaces:**
- Produces:
  - `enum SupporterIconManager`
    - `static var supportsAlternateIcons: Bool`
    - `static var currentIconName: String?`
    - `static func setIcon(named name: String?, completion: ((Error?) -> Void)? = nil)`

- [ ] **Step 1: 创建备用图标资源**

创建 `AppIcon_Supporter.appiconset`（放入作者提供的 PNG，尺寸同现有 `AppIcon.appiconset` 的 `Contents.json` 列表）。图标集名称固定为 `AppIcon_Supporter`。

- [ ] **Step 2: 在 Xcode GUI 设置备用图标名**

Target → Build Settings → 搜索 `Alternate App Icon`（`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`）→ 填 `AppIcon_Supporter`。Xcode 会据此在构建时生成 `CFBundleAlternateIcons`。

- [ ] **Step 3: 创建 `SupporterIconManager.swift`**

```swift
import UIKit

enum SupporterIconManager {
    /// 备用图标名（与 ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES 一致）
    static let supporterIconName = "AppIcon_Supporter"

    static var supportsAlternateIcons: Bool {
        return UIApplication.shared.supportsAlternateIcons
    }

    static var currentIconName: String? {
        return UIApplication.shared.alternateIconName
    }

    static func setIcon(named name: String?, completion: ((Error?) -> Void)? = nil) {
        guard supportsAlternateIcons else { completion?(nil); return }
        UIApplication.shared.setAlternateIconName(name, completionHandler: completion)
    }
}
```

- [ ] **Step 4: 加入工程并构建**

```bash
ruby scripts/xcode_project.rb ios add iOS/AniXPlayer/Supporter/SupporterIconManager.swift
```
Run: iOS 构建命令
Expected: `BUILD SUCCEEDED`

- [ ] **Step 5: 在 `SupporterViewController` 接入图标选择**

在 `reloadProducts()` 中，当 `isSupporter == true` 且 `SupporterIconManager.supportsAlternateIcons` 时，显示一行"专属图标"：可切换默认/`AppIcon_Supporter`（用 `setIcon(named:)`）；未解锁时该行置灰并提示"成为支持者即可解锁"。

- [ ] **Step 6: 手动验证**

运行 App（StoreKit 本地配置）：未支持时图标行锁定；购买"成为支持者"后切换图标成功、回到默认成功；关闭 App 重开保持所选图标。

- [ ] **Step 7: Commit**

```bash
git add iOS/AniXPlayer/Supporter/SupporterIconManager.swift iOS/AniXPlayer/Supporter/SupporterViewController.swift iOS/AniXPlayer/Assets.xcassets iOS/AniXPlayer.xcodeproj
git commit -m "feat(supporter): 支持者专属 App 图标"
```

---

### Task 6: 启动接入、本地化与收尾

**Files:**
- Modify: `iOS/AniXPlayer/AppDelegate.swift`
- Modify: `iOS/AniXPlayer/Resource/Localizable.xcstrings`（由脚本补全）
- Create: `iOS/AniXPlayer/Supporter/README.md`（App Store Connect 配置说明）

- [ ] **Step 1: AppDelegate 启动 `SupporterManager`**

在 `application(_:didFinishLaunchingWithOptions:)` 中、`return true` 之前加入：

```swift
if #available(iOS 15.0, *) {
    SupporterManager.shared.start()
}
```

- [ ] **Step 2: 补全本地化**

```bash
python3 scripts/add_localization.py ios --sync
```
Expected: 新文案（"支持开发者"、"感谢你的支持"、"已支持"、"请我喝奶茶"、"已恢复购买"、"购买失败，请稍后再试"等）进入 `Localizable.xcstrings`；为英文条目补上英文翻译（zh-Hans 直接用中文 key）。

- [ ] **Step 3: 构建验证**

Run: iOS 构建命令
Expected: `BUILD SUCCEEDED`

- [ ] **Step 4: 编写 `Supporter/README.md`**

内容包含：如何在 App Store Connect 创建 1 个非消耗型 + N 个消耗型商品、把 ID 填入 `SupporterConfig`、家庭共享开关、备用图标 Build Setting 名称。

- [ ] **Step 5: 端到端手动验证（StoreKit 本地配置）**

完整走查 Review Focus 全部 5 条 + spec 测试用例：未购买 / 消耗型打赏不解锁 / 购买支持者解锁 / 重启保持 / 退款重新锁定 / 未配置入口隐藏 / 图标切换。

重点补验第 4 条：在购买流程进行中杀掉 App 再启动，确认未完成交易被 `Transaction.updates` 收尾（`finish()`），不会反复弹窗或卡住。

- [ ] **Step 6: Commit**

```bash
git add iOS/AniXPlayer/AppDelegate.swift iOS/AniXPlayer/Resource/Localizable.xcstrings iOS/AniXPlayer/Supporter/README.md
git commit -m "feat(supporter): 启动接入与本地化收尾"
```

---

## 人工前置（实现之外，需 App Store Connect 操作）

1. 创建 **1 个非消耗型**"成为支持者" + **N 个消耗型**奶茶档位，记录商品 ID。
2. 把商品 ID 填入 `iOS/AniXPlayer/Supporter/SupporterConfig.swift`。
3. 提交支持者备用图标 PNG 并设置 `ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`。
4. 配置内购本地化名称/描述/价格；决定家庭共享。
5. 真机沙盒账号做一次真实购买 + "恢复购买"验证。
