# macOS 会员、AI 与内容发现设计

> 状态：已实现并合并 win-porting（2026-11-16）；真实支付/AI 联调待账号与后端。
> 范围：macOS 客户端；iOS/tvOS 行为保持不变。
> 说明：本文只记录稳定架构与边界，不包含内部接口路径、密钥、账号或 Windows 源码。

## 1. 目标

在现有 macOS 播放器之上补齐四条产品能力：

1. 强制登录与纯 Bearer 网络（已合并）。
2. 会员权益、上下文付费墙与购买/兑换入口。
3. 首批 AI 能力：字幕翻译、视频总结；会员补充弹幕。
4. 内容发现与用户数据：排行榜、播放历史、欢迎页。

原则：

- 不回收 macOS 既有免费功能（本地播放、SMB/WebDAV/FTP、Emby/Jellyfin、弹幕匹配/发送）。
- 登录门禁与会员门禁分离；未登录不等于未付费。
- 权益以服务端为准，客户端只做体验门禁；到期/续费不本地加时间。
- 官网直发，不做 Mac App Store / StoreKit。

## 2. 模块边界

### 2.1 网络与会话（已存在）

- `APIClient`：async/await、HTTP 状态码、错误模型、超时。
- `AuthenticatedAPIClient`：注入 Bearer，401 时单飞刷新并只重试一次。
- `SessionStore`：内存 access token + Keychain refresh token，静默恢复、刷新轮换、失效清理。
- 旧 `NetworkManager` 保留给未迁移领域；macOS 启动时关闭请求签名。

新增领域（排行榜、会员、播放历史、AI）一律走 `AuthenticatedAPIClient`，不复制旧回调式网络代码。

### 2.2 会员

```text
Share/CocoaShare/Membership/
  MembershipModels.swift      // 权益、商品、订单、兑换、历史
  MembershipAPI.swift         // 下单/二维码/状态/历史/兑换/介绍
  MembershipStore.swift       // /user/me 缓存（60s）、权益状态、变更通知
  EntitlementGate.swift       // 统一门禁：登录 -> 刷新权益 -> 付费墙
Mac/AniXPlayer/Features/Membership/
  MembershipWindowController.swift
  MembershipViewController.swift
  PaymentQRCodeView.swift
```

规则：

- 业务代码不直接读 `privileges.member`，统一走 `EntitlementGate.require(...)`。
- 支付成功、兑换成功、登录/登出必须强制刷新权益。
- 微信二维码 + 支付宝网页支付；轮询退避 2/5/10 秒，15 分钟超时。
- 关闭支付窗口只停止轮询，不取消服务端订单；文案提示“如已付款请勿重复支付”。
- 金额用整数分/Decimal，日期用绝对时间比较，展示再转本地时区。

### 2.3 AI 字幕翻译

```text
Mac/AniXPlayer/Features/Translation/
  SubtitleDocument.swift      // SRT/ASS 解析与写回
  SubtitleTranslationService.swift
  TranslationWindowController.swift
  TranslationViewController.swift
```

- 只处理已有 SRT/ASS/SSA 文件，不做语音识别与实时字幕。
- ASS 保留 Script Info / Styles / 其他事件；只替换 Dialogue 的可见文本，保留覆盖标签与 `\N` 换行。
- 翻译文本先去重，再按服务类型分批；最多 4 并发；失败批次不丢其他结果；可取消。
- 导出支持译文/原文/双语；源 ASS 可导出 ASS，SRT 可导出 SRT。
- 入口先登录，再走会员门禁；未通过不发请求。

### 2.4 AI 视频总结

```text
Mac/AniXPlayer/Features/Summary/
  SummaryModels.swift
  AISummaryService.swift
  SummaryWindowController.swift
  SummaryViewController.swift
```

- 首期从外挂 SRT/ASS 字幕生成转录条目；无字幕明确提示，不做 Whisper。
- 请求使用长超时（≥120 秒）；结果以 Markdown 展示，可复制。
- 按文件 hash 缓存，避免重复消耗额度；缓存读取前询问用户。
- 登录 + 会员门禁；服务端内容审核/额度错误要有明确文案。

### 2.5 会员补充弹幕

- 不改变非会员的默认加载行为；不自动发额外请求。
- 会员手动触发时，拉取关联/备用弹幕，与现有弹幕按 `(time, mode, color, message)` 去重合并，再交给渲染器。
- 入口放在播放器“弹幕设置”菜单，显示新增条数/无新增/失败。
- 若后端无法明确“补充”的来源与频控，先保留开关与门禁，不扩大请求范围。

### 2.6 内容发现与用户数据

- 排行榜：全站热播/飙升/新番热播，周期/季度筛选，海报网格，关注切换，详情跳转。
- 播放历史：服务端历史列表 + 播放 30 秒后上报；只上报匹配到的剧集，失败退避，不阻塞播放。
- 欢迎页：品牌区、拖拽/打开本地文件、快捷入口、最近播放、能力介绍；离线可用。
- 所有关键控件使用 `AccessibilityID` 常量，供 AX 脚本与未来 XCUITest 复用。

## 3. 门禁流程

```text
用户点击付费功能
  -> 未登录：LoginGate（OAuth）
  -> 已登录：MembershipStore 刷新 /user/me（缓存 60s）
  -> 有权益：继续原操作
  -> 无权益：会员中心（带 feature 上下文）
       -> 支付/兑换成功：刷新权益 -> 返回 true
       -> 取消/失败：返回 false
```

付费墙不阻断播放；用窗口或 sheet，不用模态 Alert 打断。

## 4. 测试策略

| 层 | 内容 | 命令/方式 |
|---|---|---|
| L0 | 模型解码、日期/金额、分批、去重、门禁状态机 | `bash scripts/test-mac.sh` |
| L1 | URLProtocol stub：200/401/403、刷新重试、错误映射 | 同上 |
| L2 | 打开视频 -> 播放 N 秒 -> 进度/弹幕/退出 | `bash scripts/playback-smoke.sh` |
| L3 | 启动页/播放器 AX 可达性 | `bash scripts/mac-ui-smoke.sh` |
| 手工 | 真实登录、真实小额支付、真实 AI 调用 | 发布前验收 |

当前结果（2026-11-16）：99 个单测通过；L2 播放冒烟、AX/CGEvent UI 冒烟通过；macOS Debug/Release、iOS/tvOS Debug 全部 BUILD SUCCEEDED。

XCUITest 暂缓：证书已有，但登录成功路径受验证码阻断，且 macOS 视频/自绘控件断言弱、启动慢。等发布签名/公证流水线时再补。

播放/UI 冒烟通过 `MacAuthBootstrap.start(restoreSession: false)` 跳过 Keychain 会话恢复，因此不会弹钥匙串授权框。手工运行未签名 Debug App 仍可能弹框，这是构建身份频繁变化导致的；需要稳定签名才能彻底避免。

## 5. 未完成与后续

- P6 媒体库（本地扫描、海报墙、哈希匹配、SQLite）。
- P7 下载中心（BT/磁力、边下边播）。
- 支付与 AI 的真实端到端验收依赖账号、额度与后端联调。

已完成（2026-11-16）：

- P3 独立播放器窗口、动画/剧集/标签/高级搜索。
- P4 收藏状态/评分/短评、追番队列详情、弹幕发送 401 刷新。
- P5 Windows 式欢迎页外壳：左侧导航 + 概览 + 公告/未看/时间表/排行榜/继续播放/在线观看。
