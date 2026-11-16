# macOS 在线观看（Animeko / Kazumi）实现说明

> 状态：阶段 A/B 已完成，阶段 C/D（连续播放、独立媒体嗅探、源置顶）已完成；2026-11-16
> 范围：macOS；iOS/tvOS 不变。
> 原则：App 不内置第三方站点；源配置由用户自行配置/导入，默认使用可修改的远端地址。

## 1. 用户流程

1. 侧边栏「在线观看」。
2. 输入关键词，选择「全部源 / Animeko / Kazumi」，搜索。
3. 左侧显示跨源搜索结果（来源 + 作品名 + 域名）；置顶源的结果排在最前并带「★ 置顶」标记；选择作品后右侧解析剧集。
4. 点击「播放」：
   - 先过 `EntitlementGate` 的 `.onlinePlayback` 会员门禁；
   - HTTP + 规则解析视频地址；
   - 用 Range 请求验证 200/206，避免 401/403 地址交给播放器后黑屏；
   - 主线路失败时自动尝试同集的其他线路；
   - 成功后用 `OnlineEpisodeFile` 交给现有播放器窗口，注入 Referer/UA/Cookie；
   - 「连续播放」默认开启：解析当前集后再预取后续 2 集；后续集失败会跳过并继续更后面的剧集；
   - 播放器播放列表按剧集顺序加载，默认播放模式（自动播放不循环）下会自动进入下一集；
   - 播放中接近队尾时，`OnlinePlaybackSession` 会在后台继续解析并追加后续剧集，不需要重新打开播放器。
5. 解析失败弹出错误，可「重试当前集」或「在浏览器打开」剧集页。
6. 「源管理」可修改 Animeko/Kazumi 地址、恢复默认、清空缓存、启用/禁用单个源，并用星标置顶常用源（持久化到本机）。
7. 「功能 → 媒体嗅探…」或在线页「媒体嗅探」按钮打开独立 WKWebView 嗅探窗口：可浏览/登录网页，查看候选视频，复制地址、在浏览器打开或直接播放。

搜索免费；播放需要会员；媒体嗅探窗口需要 `.mediaSniffer` 会员门禁。静态截图等其他既有免费功能不受影响。

## 2. 代码结构

| 文件 | 职责 |
|---|---|
| `Features/Online/OnlineSourceModels.swift` | 源、作品、剧集、播放匹配、错误 |
| `Features/Online/OnlineSourceStore.swift` | Animeko `css1.json` / Kazumi `index.json + rules` 下载、7 天缓存、原子写、源优先级、启用状态 |
| `Features/Online/OnlineHTTPClient.swift` | 超时/大小限制、请求头、UTF-8/GB18030/Big5 解码 |
| `Features/Online/OnlineHTMLSupport.swift` | Foundation HTML tidy、XPath、CSS→XPath、URL 绝对化 |
| `Features/Online/OnlineMediaResolver.swift` | 搜索、剧集、视频正则、嵌套 URL、Kazumi 默认视频正则 |
| `Features/Online/OnlinePlaybackService.swift` | 多源并行搜索、源失败隔离、播放准备、备用线路、流验证、连续播放预取 |
| `Features/Online/OnlinePlaybackSession.swift` | 连续播放队列：播放器媒体变化时后台追加后续剧集 |
| `Features/Online/OnlineStreamSniffer.swift` | 离屏 WKWebView + JS hook 嗅探（fetch/XHR/setAttribute/video/iframe/performance/内联脚本）；共享判定逻辑 |
| `Features/Online/OnlineSnifferWindowController.swift` | 独立可视嗅探窗口：地址栏、导航、候选列表、复制/浏览器打开/播放 |
| `Features/Online/OnlineEpisodeFile.swift` | 稳定虚拟 URL、真实 streamURL、请求头、虚拟文件弹幕匹配 |
| `Features/WelcomeShell/WelcomeOnlineViewController.swift` | 在线观看页面、连续播放开关、源置顶与源管理 sheet |

## 3. 源配置与缓存

缓存目录：

```
~/Library/Application Support/AniXPlayer/OnlineSources/
  animeko/css1.json
  kazumi/index.json
  kazumi/rules/<name>.json
```

- Animeko：解析 `exportedMediaSourceDataList.mediaSources`，兼容顶层 `mediaSources`。
- Kazumi：`index.json` 版本对比，只下载变化规则；删除远端已移除的规则；跳过 POST / API 模式（与 Windows 版一致）。
- 7 天 TTL；强制刷新会重新下载；单源失败保留旧缓存。
- 默认地址：
  - Animeko：`https://sub.creamycake.org/v1/css1.json`
  - Kazumi：`https://raw.githubusercontent.com/Predidit/KazumiRules/main`
- 写入使用临时文件 + 原子替换；下载限制 8 MB。
- 不内置任何第三方源文件。
- 启用/禁用状态保存在 `UserDefaults`（`online.source.disabled`）。
- 置顶状态保存在 `UserDefaults`（`online.source.pinned`）；搜索时置顶源优先，源管理用星标切换，搜索结果带「★ 置顶」标记。

## 4. 解析能力

### Animeko

- `searchUrl` 的 `{keyword}`；首词/去特殊字符开关。
- `subjectFormatId`：`a`、`indexed`；`jsonpath` 暂不支持（现有源未使用）。
- `channelFormatId`：`index-grouped`、`no-channel`。
- `matchEpisodeSortFromName` 提取 `(?<ep>...)`，过滤导航/广告链接。
- `matchVideoUrl`、`enableNestedUrl`、`matchNestedUrl`、`addHeadersToVideo`、`cookies`。

### Kazumi

- `index.json` + `rules/<name>.json`。
- XPath：`searchList/searchName/searchResult/chapterRoads/chapterResult`；支持相对 XPath 与联合表达式。
- 跳过 `usePost`、`searchMode=api`、`chapterMode=api`。
- 视频地址使用默认正则 `https?://...\.(m3u8|mp4)`；动态页面走 WKWebView 嗅探。

### 视频地址兜底

- 配置正则失败时，按 `.m3u8 > .mp4 > .flv > .mkv` 扫描整页 URL。
- `player_aaaa.url` 支持 base64 + 多次 percent 解码；可跟随一次内嵌播放页。
- 解析出的地址播放前做 Range 验证；401/403 不进入播放器。

## 5. WKWebView 嗅探

### 5.1 自动嗅探

离屏 2×2 窗口 + `WKWebView`，注入 atDocumentStart JS：

- hook `fetch`、`XMLHttpRequest.open`、`Element.setAttribute`；
- 扫描 `video/source/iframe`、`performance.getEntriesByType('resource')`、内联脚本；
- `MutationObserver` + 多次延时扫描；
- 自动 `video.play()`（静音）并点击常见播放按钮；
- 候选按 m3u8/mp4/flv/mkv、播放/视频/流路径、跨域 CDN 加分，广告域名/路径减分；低分候选直接丢弃，避免播放广告；
- 总超时默认 12 秒，首候选后等待 4 秒择优。

局限：

- WKWebView 没有 WebView2 的全量请求拦截，拿不到完整的请求头；只能使用源配置里的 Referer/UA/Cookie。
- `blob:`/MSE/DRM、验证码、强反爬站点无法解析。
- 动态站点成功率取决于站点是否把真实媒体 URL 暴露给 JS/DOM；失败时明确报错，不伪造结果。

### 5.2 独立媒体嗅探窗口

入口：

- 菜单「功能 → 媒体嗅探…」；
- 在线观看页「媒体嗅探」按钮（打开时带入当前作品页）。

门禁与复用：

- 打开窗口前走 `EntitlementGate.shared.require(.member, feature: .mediaSniffer)`；
- 窗口单例复用，不重复创建；
- 与自动嗅探共用 `OnlineStreamSniffer` 的 JS hook 和 `OnlineStreamSnifferSupport` 的 URL 归一化/扩展名判定/打分逻辑。

功能：

- 可见 `WKWebView`（持久化 Cookie，便于手动登录）+ URL 输入框、打开、后退、前进、重新加载、停止；
- 候选列表按匹配度排序，显示分数、类型（fetch/xhr/video/performance/script/player）与来源页域名；
- 复制候选地址、在浏览器打开候选地址、在浏览器打开当前页面；
- 播放候选前做 Range 验证；401/403 或其他失败会弹出明确错误，候选仍保留在列表中；
- 播放时构造 `OnlineEpisodeFile`：`pageURL` 为发现候选的页面，请求头为默认 UA + 页面同源 Referer，显示名使用「页面域名 + 文件名」。

局限：候选来自页面 JS/DOM 能暴露的地址；窗口内的防盗链/登录状态无法完整转成播放器请求头，复杂站点仍可能失败。

## 6. 播放与弹幕

- `OnlineEpisodeFile`：
  - `url` 为 `anix-online://<md5(source+pageURL)>` 稳定虚拟地址，避免多集共用 `index.m3u8` 时 `fileId` 碰撞；
  - `streamURL` 为真实流地址；
  - `fileName` 为「作品名 + 剧集名.mp4」，用于标题与匹配；
  - `isVirtualFile = true`，`danmakuMatchFileName` 不含扩展名；
  - 请求头通过 `File.httpHeaders` 注入 VLC/MPV。
- `MatchNetworkHandle` 对虚拟文件：
  - 不读取本地哈希；
  - 使用空 MD5 + `fileNameOnly` + 「作品名 + 剧集名」请求 `/match`；
  - 不写空哈希全局缓存，避免串集。
- 连续播放：
  - 「连续播放」开关默认开启，状态保存在 `online.playback.continuous`；
  - 打开播放器前解析当前集 + 后续 2 集（当前集失败直接报错；后续集失败跳过并继续更后面的剧集）；
  - 预取文件按顺序交给播放器播放列表，每个文件保留自己的请求头和「作品名 + 剧集名」弹幕匹配名；
  - `OnlinePlaybackSession` 通过 `PlayerViewController` 的媒体变化 hook 在播放中继续追加，最多每批 2 集；
  - 播放模式为用户全局设置；默认「自动播放（不循环）」下会连续播放，若用户手动设为「无」或「重复当前视频」，则以播放模式为准；
  - 到达剧集列表末尾后正常停止，不伪造地址。
- 局限：预取是串行的，首次播放会等待当前集和最多 2 集后续集解析完成；解析很慢的源会拉长等待时间（有进度文本）。失败跳过有上限（预取阶段最多多扫 3 集，后台每批最多尝试 6 集），避免被整季失败拖住。

## 7. 会员与合规

- 搜索：登录即可。
- 播放：`EntitlementGate.require(.member, feature: .onlinePlayback)`。
- 媒体嗅探窗口：`EntitlementGate.require(.member, feature: .mediaSniffer)`。
- 源管理页面明确提示：源配置只保存在本机；App 不内置第三方站点。
- 源地址可配置；默认地址不随 App 分发配置内容。
- 失败不伪造结果；401/403 提示换源或浏览器打开。
- 置顶/启用状态仅保存在本机，不上传。

## 8. 验收记录（2026-11-16）

- macOS Debug 编译通过（`DERIVED_DATA_PATH=/tmp/anix-dd-online bash scripts/build-mac.sh Debug`，BUILD SUCCEEDED）。
- 本次改动按编译验证；未执行联网/UI 功能测试。
- 2026-11-16 第二批：Kazumi API/POST/JSONPath 边界已补；源管理页会列出未加载规则及原因。
  本地 18 条规则可加载；`mgnacg` 这类缺少详情页模板的规则仍会给明确错误，不伪造结果。
- 既有验收（阶段 A/B）：
  - 应用内加载 28 个源（Animeko 18 / Kazumi 10）。
  - 搜索「葬送的芙莉莲」：31 个结果，28 个源参与，6 个源失败；失败按源隔离。
  - Animeko「稀饭动漫」解析出 56 条剧集（已按标题合并线路），HTTP 直链 401，播放前验证拦截并提示换源。
  - Animeko「叽哔动漫」/「番茄动漫」解析出 `play.xluuss.com` m3u8，Range 验证 200；主线路 `v3.tlkqc.com` TLS 失败时自动切换备用线路，播放器成功播放 24:00 视频。
  - Kazumi `7sefun` 搜索/剧集解析成功；动态播放页 HTTP 解析失败，WKWebView 嗅探能过滤广告但没有拿到真实媒体 URL（站点 JS 加密/播放器较重），返回明确失败。

## 9. 后续

1. Kazumi API/POST 模式规则（JSONPath/请求体/分页）：已完成，规格与结果见
   `2026-11-16-macos-batch-2.md` §4；覆盖 `searchMode/chapterMode = api`、GET/POST、
   delimited/nested 剧集、sourceTemplate 与 episodePage。
2. Animeko JSONPath 搜索。
3. 更完整的请求头转发（本地 GCDWebServer 代理）以覆盖强防盗链源；独立嗅探窗口目前只带默认 UA + Referer，无法复制窗口内的全部请求头。
4. 嗅探成功率与广告过滤继续按真实源站校准；可视窗口可增加候选指纹/过滤规则。
5. 搜索历史独立面板（当前仍使用 `NSSearchField.recentSearches`）。
6. 连续播放的串行预取可改为并发/失败后台重试，减少首次播放等待。
