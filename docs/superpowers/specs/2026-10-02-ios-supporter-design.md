# iOS 打赏与支持者解锁方案设计

## 概述

为 iOS 版 AniXPlayer 增加"自愿打赏 + 支持者视觉回报"功能，类似"请我喝奶茶"：用户可随时、可重复打赏；购买一次"支持者"后，永久解锁支持者专属 App 图标与徽章，且可跨设备恢复。

本方案**不依赖自建服务器，也不依赖 iCloud**：购买与恢复完全由 Apple StoreKit / App Store 账号承载。

范围：**仅 iOS，最低 iOS 15**。tvOS / macOS 暂不做（macOS 直发无法使用 Apple 内购）。

## 背景与约束

| 约束 | 说明 |
|------|------|
| App 分发 | iOS 走 App Store，可使用 StoreKit 内购 |
| 开源项目 | 商品 ID / 开关需可配置（仿 `AppKey.swift`），fork 用户可自行替换 |
| 无自建后端、无 iCloud | 不引入服务端，也不使用 iCloud KVS；解锁可恢复性由 Apple 账号保证 |
| 审核 | 打赏必须走 IAP（3.1.1）；消耗型打赏被 Apple 明确允许 |
| 部署目标 | 工程整体 iOS 12，但**本功能仅 iOS 15+ 展示**（用 `#available` 隐藏低版本入口） |

## 关键决策与取舍

StoreKit 下三个诉求天然冲突：

- ① 一直可重复打赏；
- ② 不用 iCloud、不用服务器；
- ③ 跨设备永久恢复解锁。

Apple 对**消耗型**商品不保留"曾购买"记录，因此 ①②③ 无法同时满足。本方案选择 ②③ 优先，用**双轨商品**实现：

| 商品 | 类型 | 作用 | 可重复 | Apple 记得/可恢复 |
|------|------|------|--------|------------------|
| 请我喝奶茶（1~N 档） | 消耗型 | 纯打赏，**不解锁** | ✅ 无限次 | ❌ |
| 成为支持者 | 非消耗型 | 解锁图标 + 徽章 | ❌ 每个 Apple ID 一次 | ✅ 永久、跨设备 |

- **解锁判定** = 用户是否拥有"成为支持者"这个**非消耗型**商品。Apple 账号即"服务器"，无需自建。
- 想反复支持的用户买消耗型；想要图标/徽章的用户买非消耗型。

**金额形式（重要约束）**：Apple IAP **不支持用户任意输入金额**——每个商品在 App Store Connect 固定定价，只能从 Apple 价格点中选择。因此"请我喝奶茶"采用**多档固定金额**（示例：¥6 / ¥18 / ¥48 / ¥98，最终值在 App Store Connect 定），用户在 App 内多选一。不使用"固定单价 + 数量"等复杂形式。

- 备选（未采用）：消耗型 + iCloud KVS 记录（换机不稳）；纯多档非消耗型（无法真正一直打赏）；固定单价 + 数量（近似自定义但复杂）。

## 组件设计

```
iOS/AniXPlayer/Supporter/            # iOS UI 与 StoreKit 封装
├── SupporterManager.swift           # StoreKit 2 封装 + 权益判断 + 状态广播
├── SupporterViewController.swift    # 打赏 / 支持页
├── SupporterConfig.swift.example    # 商品 ID 配置模板（真实文件 gitignore）
└── SupporterIconManager.swift       # 备用图标切换

iOS/AniXPlayer/Assets.xcassets/
└── AppIcon_Supporter.appiconset     # 支持者备用图标（资源由作者提供）
```

### `SupporterManager`（iOS / StoreKit 2）

- 依赖：`StoreKit`。
- 商品：
  - 消耗型打赏档位（`consumable` 商品 ID 列表）；
  - 非消耗型支持者（`supporter` 商品 ID，单个）。
- 职责：
  - 拉取商品：`Product.products(for: allProductIDs)`；
  - 发起购买：`product.purchase()`，处理 `.success(VerificationResult)` / `.userCancelled` / `.pending`；
  - 校验：`checkVerified(_:)`，仅接受 `.verified`；
  - 完成交易：`transaction.finish()`（消耗型与支持者都要 finish）；
  - 权益判定：读取 `Transaction.currentEntitlements`，判断其中是否包含 `supporter` 商品且未退款；
  - 启动时监听 `Transaction.updates`，兜底处理 App 被杀、购买中断、以及后续退款撤销；
  - 恢复：`AppStore.sync()` 后重新读取权益（"恢复购买"按钮）；
  - 状态广播：RxSwift `BehaviorSubject<Bool>`（与既有 `GlobalSettingModel` 风格一致），供设置页与支持页订阅。
- 本地只做**非权威**的 UI 缓存（`UserDefaults` 布尔值），用于启动瞬间立即展示；真实状态始终以 StoreKit 权益为准。

### 权益判定细节

`isSupporter` 为真当且仅当：

1. `Transaction.currentEntitlements` 中存在 productID == `supporter` 的交易；
2. 该交易 `revocationDate == nil`（退款/撤销后应重新锁定）；
3. 若在 App Store Connect 开启家庭共享，则 `ownershipType == .familyShared` 也算拥有。

### UI / 入口

- `GlobalSettingType` 新增 `.supporter` case，设置页出现"支持开发者"行（`TitleDetailMoreTableViewCell` 样式）。
- 点击进入 `SupporterViewController`：
  1. 顶部说明：开源、自愿、用途；
  2. **成为支持者**：非消耗型，一次购买，解锁图标 + 徽章（价格取自 StoreKit 本地化，不硬编码）；
  3. **请我喝杯奶茶**：消耗型**多档固定金额**（如 ¥6/¥18/¥48/¥98），可重复，写明"纯支持，不解锁回报"；
  4. 已支持状态展示；
  5. 专享图标选择（解锁后可选，含"默认 + 支持者图标"）；
  6. **"恢复购买"按钮**（售卖非消耗型，Apple 强制要求）。
- 支持者徽章：设置页该行副标题显示"已支持"，或在相关页面展示标记。
- 商品不可用时：入口行隐藏，或进入后提示"暂不可用"。
- 本地化：需在 `zh-Hans.lproj` / `en.lproj` 补充相关 `NSLocalizedString` 文案。

### `SupporterIconManager`（iOS）

- 通过 `Info.plist` 的 `CFBundleIcons > CFBundleAlternateIcons` 声明备用图标。
- 切换：`UIApplication.shared.setAlternateIconName(_:)`；先判断 `supportsAlternateIcons`。
- 首次切换时系统会弹一次自带提示，无需自定义。
- 未解锁时图标选项仍展示但置灰，点击引导去购买"成为支持者"。

### 跨平台影响（重要）

`GlobalSettingType` 定义在 `Share/CocoaShare/Enum.swift`，是 iOS / Mac / tvOS **共享枚举**，三端设置页都对它做 `switch`。新增 `.supporter` 时需：

1. 在 `GlobalSettingType` 添加 case 与 `title`；
2. 在 `GlobalSettingModel.subtitle(settingType:)` 与新 case 的 `switch` 分支中处理；
3. 在 iOS `SettingViewController`、Mac `GlobalSettingViewController`、tvOS `SettingViewController` 的 `switch` 中补分支（Mac/tvOS 分支可为空实现，仅保证编译）；
4. 在 `GlobalSettingModel.allSettingType()` 中过滤：仅 iOS 且 iOS 15+ 才返回 `.supporter`，其余平台与低版本隐藏。

这样共享枚举不破坏另外两个平台的构建，同时入口严格限制在 iOS 15+。

## 数据流

```
App 启动
  └─ 读本地 UI 缓存（瞬时显示）
  └─ 读 Transaction.currentEntitlements（权威）→ isSupporter
  └─ 监听 Transaction.updates（清理未完成交易 / 处理退款撤销）

用户打赏（消耗型）
  选档 → product.purchase() → .success(.verified(tx)) → tx.finish()
       → 提示"已收到支持"，不改变解锁状态

用户成为支持者（非消耗型）
  purchase() → .success(.verified(tx)) → tx.finish()
             → 重新读取权益 → isSupporter=true → 广播 → UI 解锁图标/徽章

换机 / 重装
  启动读 currentEntitlements → 自动恢复（Apple 账号）
  或点"恢复购买" → AppStore.sync() → 重读权益

退款 / 撤销
  Transaction.updates 收到撤销 → 权益判定为 false → 重新锁定
```

## 可配置项与开源

- `SupporterConfig`（真实文件 gitignore，提供 `.example`）：
  - 非消耗型 supporter 的商品 ID；
  - 消耗型打赏档位的商品 ID 列表；
  - 是否启用本功能的开关。
- 未配置 / 商品 ID 为空 → 功能整体隐藏，无副作用。
- fork 用户需在自己的 App Store Connect 创建商品后填写。

## 边界与错误处理

| 场景 | 行为 |
|------|------|
| 商品加载失败 | 显示重试；多次失败则降级为"暂不可用" |
| 用户取消购买 | 静默返回，不提示错误 |
| 交易 pending（如家长批准 / SCA） | 保持等待，由 `Transaction.updates` 完成后续处理 |
| 消耗型购买成功 | 不解锁，仅致谢 |
| 非消耗型购买成功 | 立即解锁，重启/换机后仍在 |
| 退款 / 撤销 | 非消耗型解锁撤销，重新锁定 |
| 重复打赏 | 消耗型允许无限次；支持者已是拥有状态，不再售卖 |
| 非 iOS 15 设备 | 设置页不展示入口 |

## 测试策略

- **本地**：新增 `Supporter.storekit` 配置文件并挂到 iOS scheme，覆盖消耗型、非消耗型、取消、pending、退款。StoreKit Testing 可模拟退款。
- **真机**：沙盒账号验证真实购买、`Transaction.updates` 与"恢复购买"。
- **用例清单**：
  - 未购买 → 入口可见、图标锁定；
  - 消耗型打赏 → 致谢、不解锁；
  - 购买支持者 → 立即解锁、重启后仍在；
  - 卸载重装 / 第二台设备（同一 Apple ID）→ "恢复购买"后解锁；
  - 退款 / 撤销 → 重新锁定；
  - 商品 ID 未配置 → 入口隐藏；
  - 备用图标切换：切换成功、切换回默认、`supportsAlternateIcons=false` 兜底。

## 审核合规

- 使用 IAP，符合 3.1.1；消耗型打赏属 Apple 明确允许的 IAP 用途。
- 售卖非消耗型，**必须提供"恢复购买"入口**。
- 文案使用"打赏 / 支持"，避免"慈善捐赠"措辞（后者适用非营利规则）。
- 备用图标符合 Apple 图标规范，且功能确实由 IAP 解锁。
- 审核备注需说明：消耗型为纯打赏，非消耗型为解锁图标/徽章的一次性购买。

## App Store Connect 前置（人工）

1. 创建 **1 个非消耗型**"成为支持者"商品，记录商品 ID。
2. 创建 **1~N 个消耗型**打赏商品，记录商品 ID 列表。
3. 在本地填写 `SupporterConfig.swift`（gitignore）。
4. 提交支持者备用图标资源，并在 `Info.plist` 声明 `CFBundleAlternateIcons`。
5. 配置内购本地化名称 / 描述 / 价格；决定是否开启家庭共享。

## 约束与不做的事（YAGNI）

- 不做：自建服务器、收据服务端校验、**iCloud 同步**、公开支持者名单、订阅制、远程配置。
- 不做：tvOS / macOS 版本（后续可复用 `SupporterConfig` 与 `SupporterManager` 思路）。
- 不做：StoreKit 1 回退（不支持 iOS 12–14，低版本隐藏入口）。
- 新增文件需用 `ruby scripts/xcode_project.rb ios add <路径>` 加入工程，禁止手改 pbxproj。
- 涉及 Share 的改动需确认三平台编译（尤其 `GlobalSettingType` 的跨平台 `switch`），仅 iOS 使用。

## 待确认 / 后续

- 支持者备用图标的具体数量与命名（作者提供后确定 `CFBundleAlternateIcons` 键名）。
- 消耗型打赏的档位数量与价格、非消耗型支持者的价格（在 App Store Connect 决定，代码不硬编码）。
- 是否开启非消耗型的家庭共享。
