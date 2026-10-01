# iOS 打赏与支持者解锁方案设计

## 概述

为 iOS 版 AniXPlayer 增加"自愿打赏 + 支持者视觉回报"功能，类似 Buy Me a Coffee：用户可随时、可重复打赏；任意一次打赏成功后，永久解锁支持者专属 App 图标与徽章。

本方案**不依赖自建服务器**，购买与解锁凭证由 Apple StoreKit + iCloud KeyValueStore 承载。

范围：**仅 iOS，最低 iOS 15**。tvOS / macOS 暂不做（macOS 直发无法使用 Apple 内购）。

## 背景与约束

| 约束 | 说明 |
|------|------|
| App 分发 | iOS 走 App Store，可使用 StoreKit 内购 |
| 开源项目 | 商品 ID / 开关需可配置（仿 `AppKey.swift`），fork 用户可自行替换 |
| 无自建后端 | 不引入任何服务端；解锁状态靠本地 + iCloud KVS |
| 审核 | 打赏必须走 IAP（3.1.1）；"打赏"用 IAP 是被 Apple 明确允许的 |
| 部署目标 | 工程整体 iOS 12，但**本功能仅 iOS 15+ 展示**（用 `#available` 隐藏低版本入口） |
| 已有设施 | `Preferences` 已有本地 UserDefaults + iCloud KVS 双后端 `Store`；`ubiquity-kvstore-identifier` entitlement 已存在 |

## 关键决策与取舍

StoreKit 下"可重复打赏"与"永久解锁"存在天然矛盾：

- 可重复购买 ⇒ 商品必须为**消耗型**；
- Apple 能永久记住并跨设备恢复 ⇒ 商品必须为**非消耗型**。

本方案选择：**消耗型商品承载打赏，解锁状态由我们自己持久化**。

| 方案 | 可重复打赏 | 无服务器永久解锁 | 取舍 |
|------|-----------|----------------|------|
| **本方案：消耗型 + iCloud KVS 解锁** | ✅ | ✅（iCloud 可用时） | 不用 iCloud 且不恢复备份时，换新机需重新打赏/手动恢复 |
| 双轨：消耗型 + 非消耗型 supporter | ✅ | ✅（Apple 官方恢复） | 多一个商品，用户需理解两个概念 |
| 纯多档非消耗型 | ❌（每档一次） | ✅ | 无法真正"一直打赏" |

**已知风险**：消耗型商品不会出现在 `Transaction.currentEntitlements` 中，Apple 不保留"曾购买"记录，因此解锁完全依赖我们写入的本地 + iCloud 标记。这是本方案接受的核心代价。若审核要求改用非消耗型，可平滑升级到"双轨"方案，架构无需返工。

## 组件设计

```
iOS/AniXPlayer/Supporter/            # iOS UI 与 StoreKit 封装
├── SupporterManager.swift           # StoreKit 2 封装 + 状态广播
├── SupporterViewController.swift    # 打赏页
├── SupporterConfig.swift.example    # 商品 ID 配置模板（真实文件 gitignore）
└── SupporterIconManager.swift       # 备用图标切换

Share/CocoaShare/Preferences/
└── SupporterStore.swift             # 解锁标记的本地 + iCloud 持久化（纯逻辑）

iOS/AniXPlayer/Assets.xcassets/
└── AppIcon_Supporter.appiconset     # 支持者备用图标（资源由作者提供）
```

### `SupporterStore`（Share / 纯逻辑，无 UI）

- 单键单调标记：`anx_supporter_hasDonated`（Bool，只写 `true`，永不置回）。
- 双层存储：
  - 本地：`UserDefaults`；
  - 云端：`NSUbiquitousKeyValueStore`（仅在 `isCloudAvailable` 为真时读写，复用现有防 `EXC_BREAKPOINT` 保护）。
- **不接入**现有 `Store` 的冲突同步系统（`syncToCloud` / `icloudSyncEnabled`），避免用户关闭"配置同步"或触发冲突解决时误清解锁标记。
- 对外接口：
  - `var isSupporter: Bool` —— `本地 || (云可用 && 云标记)`；
  - `func markDonated()` —— 购买成功后调用，写本地 + 云端；
  - `func restore() async` —— 触发 `synchronize()` 后重读，供"恢复支持状态"按钮使用。

### `SupporterManager`（iOS / StoreKit 2）

- 依赖：`StoreKit`。
- 职责：
  - 拉取商品：`Product.products(for: SupporterConfig.productIDs)`；
  - 发起购买：`product.purchase()`，处理 `.success(VerificationResult)` / `.userCancelled` / `.pending`；
  - 校验：`checkVerified(_:)`，仅接受 `.verified`；
  - 完成交易：`transaction.finish()`；
  - 启动时监听 `Transaction.updates`，兜底处理 App 被杀、购买中断等未完成交易；
  - 状态广播：RxSwift `BehaviorSubject<Bool>`（与既有 `GlobalSettingModel` 风格一致），供设置页与打赏页订阅。
- 购买成功统一走：`finish()` → `SupporterStore.markDonated()` → 广播刷新 UI。
- 商品列表为空（未配置 / 网络失败）时向 UI 暴露"不可用"状态。

### `SupporterIconManager`（iOS）

- 通过 `Info.plist` 的 `CFBundleIcons > CFBundleAlternateIcons` 声明备用图标。
- 切换：`UIApplication.shared.setAlternateIconName(_:)`；先判断 `supportsAlternateIcons`。
- 首次切换时系统会弹一次自带提示，无需自定义。
- 未解锁时图标选项仍展示但置灰，点击引导去购买。

### UI / 入口

- `SettingType` 新增 `.supporter` case，设置页出现"支持开发者"行（`TitleDetailMoreTableViewCell` 样式）。
- 点击进入 `SupporterViewController`：
  1. 顶部说明：开源、自愿、用途（如服务器/维护/新功能）；
  2. 打赏档位按钮列表：**价格从 StoreKit 动态获取并本地化**，不硬编码；
  3. 已支持状态展示；
  4. 专享图标选择（解锁后可选，支持"默认 + 支持者图标"多项）；
  5. "恢复支持状态"按钮（消耗型不强制，但本方案的 iCloud 恢复需要它）。
- 支持者徽章：设置页该行副标题显示"已支持"，或在相关页面展示标记。
- 商品不可用时：入口行隐藏，或进入后提示"暂不可用"。
- 本地化：需在 `zh-Hans.lproj` / `en.lproj` 补充相关 `NSLocalizedString` 文案。

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
  └─ SupporterStore 读本地 + (iCloud 可用则读 KVS) → isSupporter
  └─ SupporterManager 拉商品 + 监听 Transaction.updates（清理未完成交易）

用户打赏
  选档 → product.purchase()
    ├─ .success(.verified(tx)) → tx.finish() → SupporterStore.markDonated()
    │                               → 广播 isSupporter=true → UI 解锁图标/徽章
    ├─ .success(.unverified)    → 忽略并不解锁（记录日志）
    ├─ .userCancelled           → 无变化
    └─ .pending                 → 等待 Transaction.updates 后续回调

换机 / 重装
  iCloud KVS 同步 → 启动时读取 → 自动恢复解锁
  或用户点"恢复支持状态" → synchronize() → 重读
```

## 可配置项与开源

- `SupporterConfig`（真实文件 gitignore，提供 `.example`）：
  - 商品 ID 列表（消耗型，多档）；
  - 是否启用本功能的开关。
- 未配置 / 商品 ID 为空 → 功能整体隐藏，无副作用。
- fork 用户需在自己的 App Store Connect 创建商品后填写。

## 边界与错误处理

| 场景 | 行为 |
|------|------|
| 商品加载失败 | 显示重试；多次失败则降级为"暂不可用" |
| 用户取消购买 | 静默返回，不提示错误 |
| 交易 pending（如家长批准 / SCA） | 保持等待，由 `Transaction.updates` 完成后续处理 |
| 未登录 iCloud | 本机解锁可用，UI 提示"登录 iCloud 可跨设备同步" |
| iCloud 关闭同步 / 不可用 | 仅本地解锁；不影响购买 |
| 退款 | 消耗型为一次性流水，**不撤销解锁**（符合"打赏过即赠送"的语义） |
| 重复打赏 | 允许，档位可无限次购买；解锁状态幂等 |
| 非 iOS 15 设备 | 设置页不展示入口 |

## 测试策略

- **本地**：新增 `Supporter.storekit` 配置文件并挂到 iOS scheme，可无沙盒账号测试购买成功 / 取消 / pending / 退款等分支。
- **真机**：沙盒账号验证真实购买与 `Transaction.updates`。
- **用例清单**：
  - 未购买 → 入口可见、图标锁定；
  - 打赏成功 → 立即解锁、重启后仍解锁；
  - 卸载重装（同机、iCloud 可用）→ 自动恢复；
  - 第二台设备（同 iCloud）→ 自动恢复；
  - 未登录 iCloud → 本机解锁，跨设备不恢复；
  - 商品 ID 未配置 → 入口隐藏；
  - 备用图标切换：切换成功、切换回默认、`supportsAlternateIcons=false` 兜底。

## 审核合规

- 使用 IAP，符合 3.1.1；打赏属 Apple 明确允许的 IAP 用途。
- 文案使用"打赏 / 支持"，避免"慈善捐赠"措辞（后者适用非营利规则）。
- 提供"恢复支持状态"入口（本方案 iCloud 恢复所需）。
- 备用图标符合 Apple 图标规范，且功能确实由 IAP 解锁。
- 审核备注需说明：打赏为消耗型纯支持，解锁为开发者赠送的感谢礼。

## App Store Connect 前置（人工）

1. 创建消耗型 IAP 商品（1~N 档），记录商品 ID。
2. 在本地填写 `SupporterConfig.swift`（gitignore）。
3. 提交支持者备用图标资源，并在 `Info.plist` 声明 `CFBundleAlternateIcons`。
4. 配置内购本地化名称 / 描述 / 价格。

## 约束与不做的事（YAGNI）

- 不做：自建服务器、收据服务端校验、公开支持者名单、订阅制、远程配置。
- 不做：tvOS / macOS 版本（后续可复用 `SupporterStore` 与配置）。
- 不做：StoreKit 1 回退（不支持 iOS 12–14，低版本隐藏入口）。
- 新增文件需用 `ruby scripts/xcode_project.rb ios add <路径>` 加入工程，禁止手改 pbxproj。
- 涉及 Share 的新增代码需确认三平台编译（仅 iOS 使用，但需保证不破坏 tvOS/macOS 构建），尤其 `GlobalSettingType` 的跨平台 `switch`。

## 待确认 / 后续

- 支持者备用图标的具体数量与命名（作者提供后确定 `CFBundleAlternateIcons` 键名）。
- 打赏档位数量与价格的最终值（在 App Store Connect 决定，代码不硬编码）。
