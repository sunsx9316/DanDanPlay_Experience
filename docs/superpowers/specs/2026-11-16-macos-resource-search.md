# macOS 资源搜索（res.dandanplay.net）

日期：2026-11-16
范围：macOS 主窗口「搜索 → 资源搜索」；iOS / tvOS 不受影响。

## 目标

对齐 Windows 版 `SearchResourceControl`：按关键词搜索弹弹play 资源服务器，
展示资源列表，并把磁力链接 / 种子地址送到下载中心。资源搜索免费；实际 BT
下载仍取决于用户配置的 Transmission 和下载中心设置。

## 接口

默认节点：`https://res.dandanplay.net`。可用环境变量
`ANIX_RESOURCE_SEARCH_ENDPOINT` 覆盖（调试/镜像用）。

| 接口 | 用途 |
| --- | --- |
| `GET /list?keyword=...&type=...&subgroup=...&r=...` | 搜索资源 |
| `GET /type` | 分类列表 |
| `GET /subgroup` | 字幕组列表 |

- `r` 为随机数，避免缓存。
- 响应使用 camelCase；缺失字段按空值/0 处理，避免单个损坏条目导致整页失败。
- 资源模型保留 `magnet`、`torrentUrl`、`pageUrl`、`fileSize`、`publishDate` 等字段。
- 下载源优先 `magnet`，缺失时回退 `torrentUrl`。

## 页面

```
资源搜索（标题/副标题）
[关键词输入框 ................] [搜索] [全部分类▾] [全部字幕组▾]
状态：找到 N 条资源 · 结果较多，可加关键词缩小范围
┌──────────────────────────────────────────────────────────────┐
│ 资源名称 | 类型 | 字幕组 | 大小 | 发布时间 | 操作（下载/发布页） │
└──────────────────────────────────────────────────────────────┘
关键词帮助：空格=与，|=或，!=排除
```

- 初始态、加载态、空结果、筛选为空、失败态都有独立提示；失败可重试。
- 分类/字幕组列表异步加载；加载失败时仍可搜索，筛选保持「全部」。
- 分类/字幕组参与服务端搜索；已有关键词时切换筛选会重新请求，
  避免只过滤当前返回的前 200 条。
- 结果表格行高 38pt，标题单行截断并带 tooltip；双击行或点「下载」触发下载。
- 右键菜单：下载 / 复制磁力链接 / 打开发布页。
- 没有可用下载地址时下载按钮禁用并给出提示。
- `hasMore` 为真时状态栏提示「结果较多，可加关键词缩小范围」。
- 输入框支持 NSSearchField 最近搜索记录。

## 下载接线

`MainShellViewController` 收到 `onDownloadResource` 后：

1. 切到「下载」分区；
2. `DownloadViewController.openAddSheet(prefillSource:)` 预填磁力/种子地址；
3. 用户在添加 sheet 中选择保存目录并确认。

BT 内核未配置时，下载中心会显示现有 BT 引导提示，不会直接创建任务。

## 无障碍

`AccessibilityID.ResourceSearch`：

- root / pageTitle / searchField / searchButton / typeFilter / subgroupFilter
- status / table / emptyState / rowPrefix

表格单元格、下载按钮、发布页按钮均暴露 AX 角色与标签。

## 文件

- `Mac/AniXPlayer/Features/ResourceSearch/ResourceSearchModels.swift`
- `Mac/AniXPlayer/Features/ResourceSearch/ResourceSearchService.swift`
- `Mac/AniXPlayer/Features/ResourceSearch/ResourceSearchViewController.swift`
- `Mac/AniXPlayer/Features/MainShell/MainSearchSectionViewController.swift`
- `Mac/AniXPlayerTests/ResourceSearchTests.swift`

## 验证

```bash
DERIVED_DATA_PATH=/tmp/anix-dd-resource-search-tests bash scripts/test-mac.sh Debug
```

- `ResourceSearchTests` 4 个通过：解码/默认值、筛选、下载源回退、服务 URL 与响应解码。
- macOS 全量单测 228 个通过。
- 实际请求「芙莉莲」返回 200 条资源；分类/字幕组显示正常；
  第一条资源下载按钮成功切到下载中心并预填磁力链接。

## 未做 / 边界

- 资源服务器没有公开分页参数；`hasMore` 只做提示，不实现「加载更多」。
- 不做资源站网页抓取，不内置第三方源。
- 不做批量选择下载、RSS 一键订阅、自动下载规则入口；这些属于后续下载中心增强。
- 分类/字幕组接口失败时静默回退，不阻塞关键词搜索。
