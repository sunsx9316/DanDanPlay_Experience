# macOS 在线观看（Animeko / Kazumi）实现说明

> 状态：阶段 A/B 已完成，阶段 C 为可用兜底；2026-11-16
> 范围：macOS；iOS/tvOS 不变。
> 原则：App 不内置第三方站点；源配置由用户自行配置/导入，默认使用可修改的远端地址。

## 1. 用户流程

1. 侧边栏「在线观看」。
2. 输入关键词，选择「全部源 / Animeko / Kazumi」，搜索。
3. 左侧显示跨源搜索结果（来源 + 作品名 + 域名）；选择作品后右侧解析剧集。
4. 点击「播放」：
   - 先过 `EntitlementGate` 的 `.onlinePlayback` 会员门禁；
   - HTTP + 规则解析视频地址；
   - 用 Range 请求验证 200/206，避免 401/403 地址交给播放器后黑屏；
   - 主线路失败时自动尝试同集的其他线路；
   - 成功后用 `OnlineEpisodeFile` 交给现有播放器窗口，注入 Referer/UA/Cookie。
5. 解析失败弹出错误，可直接「在浏览器打开」剧集页。
6. 「源管理」可修改 Animeko/Kazumi 地址、恢复默认、清空缓存、启用/禁用单个源。

搜索免费；播放需要会员。静态截图等其他既有免费功能不受影响。

## 2. 代码结构

| 文件 | 职责 |
|---|---|
| `Features/Online/OnlineSourceModels.swift` | 源、作品、剧集、播放匹配、错误 |
| `Features/Online/OnlineSourceStore.swift` | Animeko `css1.json` / Kazumi `index.json + rules` 下载、7 天缓存、原子写、源优先级、启用状态 |
| `Features/Online/OnlineHTTPClient.swift` | 超时/大小限制、请求头、UTF-8/GB18030/Big5 解码 |
| `Features/Online/OnlineHTMLSupport.swift` | Foundation HTML tidy、XPath、CSS→XPath、URL 绝对化 |
| `Features/Online/OnlineMediaResolver.swift` | 搜索、剧集、视频正则、嵌套 URL、Kazumi 默认视频正则 |
| `Features/Online/OnlinePlaybackService.swift` | 多源并行搜索、源失败隔离、播放准备、备用线路、流验证 |
| `Features/Online/OnlineStreamSniffer.swift` | 离屏 WKWebView + JS hook 嗅探（fetch/XHR/setAttribute/video/iframe/performance/内联脚本） |
| `Features/Online/OnlineEpisodeFile.swift` | 稳定虚拟 URL、真实 streamURL、请求头、虚拟文件弹幕匹配 |
| `Features/WelcomeShell/WelcomeOnlineViewController.swift` | 在线观看页面与源管理 sheet |

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
- 独立「媒体嗅探」窗口尚未实现，后续可复用本组件 + `.mediaSniffer` 门禁。

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
- 当前只播放单集；在线播放列表/自动下一集/重新解析尚未实现。

## 7. 会员与合规

- 搜索：登录即可。
- 播放：`EntitlementGate.require(.member, feature: .onlinePlayback)`。
- 源管理页面明确提示：源配置只保存在本机；App 不内置第三方站点。
- 源地址可配置；默认地址不随 App 分发配置内容。
- 失败不伪造结果；401/403 提示换源或浏览器打开。

## 8. 验收记录（2026-11-16）

- macOS Debug 编译通过。
- 应用内加载 28 个源（Animeko 18 / Kazumi 10）。
- 搜索「葬送的芙莉莲」：31 个结果，28 个源参与，6 个源失败；失败按源隔离。
- Animeko「稀饭动漫」解析出 56 条剧集（已按标题合并线路），HTTP 直链 401，播放前验证拦截并提示换源。
- Animeko「叽哔动漫」/「番茄动漫」解析出 `play.xluuss.com` m3u8，Range 验证 200；主线路 `v3.tlkqc.com` TLS 失败时自动切换备用线路，播放器成功播放 24:00 视频。
- Kazumi `7sefun` 搜索/剧集解析成功；动态播放页 HTTP 解析失败，WKWebView 嗅探能过滤广告但没有拿到真实媒体 URL（站点 JS 加密/播放器较重），返回明确失败。

## 9. 后续

1. 独立媒体嗅探窗口（`.mediaSniffer` 门禁），支持手动点击播放/登录。
2. 在线播放列表/自动下一集：保存「剧集页 + 源快照」，切集时重新解析。
3. 源偏好/置底/收藏、搜索历史 UI（当前已记录但未展示）。
4. Kazumi API 模式规则（JSONPath/请求体/分页）。
5. Animeko JSONPath 搜索。
6. 更完整的请求头转发（本地 GCDWebServer 代理）以覆盖强防盗链源。
7. 嗅探成功率与广告过滤继续按真实源站校准。
