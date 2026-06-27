# Mac 打包自动化方案设计

## 概述

将当前手动 Mac 打包流程全自动化，支持后续扩展至 iOS / tvOS。

## 当前手动流程

1. 计算新版本号（shortVersion + build）
2. 更新 Xcode 工程版本号
3. Xcode GUI → Archive → Organizer → Export（签名 + 公证）
4. 运行 `create-dmg.sh` 打 DMG
5. 写更新日志
6. 在 GitHub 上创建 Release 并上传 DMG
7. 给主仓库打 tag 推送
8. 更新 `dandanplay_mac_update` 仓库的 `check_version.json`
9. 给更新仓库打 tag 推送

## 版本号规则

- **shortVersion**: `主版本.月份.次版本`，如 `1.6.2`
  - 第一位：每年 +1
  - 中间位：当月月份（目前 6 月为 `6`）
  - 末位：每次打包相对上次 tag `+10`
  - 若月份变更，中间位更新，末位重置为 `0`
- **build**: `YYYYMMDDXX`，如 `2026062701`
  - `YYYYMMDD` 为打包日期
  - `XX` 为当天打包次数（从 01 开始）
  - 通过检查当天已有 git tag 来判断 `XX`

> **注意**: 现有 tags (`v1.6.0` → `v1.6.1` → `v1.6.2`) 按 `+1` 递增，与用户的 `+10` 规则不一致。实现前需确认：自动化后是否从当前版本开始严格按 `+10` 规则（即下一个版本为 `1.6.12`），还是保持历史习惯 `+1`？

## 目录结构

```
scripts/release/
├── release.sh                   # 主编排脚本，接受 platform 参数
├── calc_version.sh              # 计算新版本号
├── update_project_version.sh    # 更新 pbxproj 中的版本号（使用 agvtool）
├── gen_changelog.sh             # 从上次 tag 到 HEAD 生成更新日志
├── archive_and_export.sh        # xcodebuild archive + 动态生成 exportOptionsPlist
├── notarize.sh                  # macOS 公证（xcrun notarytool）
└── publish.sh                   # DMG/Release/Git 操作
```

## 流程与确认点

```
release.sh <mac|ios|tvos>

[预检] clean working tree、分支检查、pod install 检查
    │
calc_version.sh
    │
    ▼
[确认点 1] 展示计算出的 shortVersion + build，等用户确认
    │
    ▼
update_project_version.sh   ←  使用 agvtool 写入版本号
gen_changelog.sh            ←  git log <last_tag>..HEAD --oneline --no-merges
    │
    ▼
[确认点 2] 展示更新日志，等用户确认（可编辑）
    │
    ▼
archive_and_export.sh       ←  xcodebuild archive → 动态生成 exportOptionsPlist → exportArchive
notarize.sh (macOS only)    ←  xcrun notarytool submit + stapler staple
    │
    ▼
[确认点 3] 展示产物路径、版本号、日志，最终确认
    │
    ▼
publish.sh                  ←  一次性执行：
    ├── 打 DMG（macOS）/ 上传 App Store（iOS/tvOS）
    ├── GitHub Release（macOS 需要）
    ├── git tag + push 主仓库
    ├── 更新 check_version.json + 推送（macOS 需要）
    └── git tag + push 更新仓库（macOS 需要）
```

## 各模块详解

### `calc_version.sh`

- 从 `git tag --sort=-creatordate | head -1` 获取最新 tag（如 `v1.6.2`）
- 从上次 tag 解析 `shortVersion`，按规则计算新版本
- 检查当天是否已有打包（`git tag --list "v*" --sort=-creatordate`），决定 build 号的 `XX`
- 版本在一个统一入口计算，后续步骤复用，避免跨天后日期变化
- 输出：`NEW_SHORT_VERSION`、`NEW_BUILD`

### `update_project_version.sh`

- 参数：`<platform> <shortVersion> <build>`
- 使用 Apple 官方 **agvtool** 而非 sed：
  ```bash
  cd {platform}
  agvtool new-marketing-version {shortVersion}
  agvtool new-version -all {build}
  ```
- agvtool 正确更新 pbxproj 中所有 target 的 Debug + Release 配置，避免 sed 的格式风险
- 修改前自动备份 pbxproj

### `gen_changelog.sh`

- `git log <last_tag>..HEAD --pretty=format:"- %s" --no-merges`
- 输出到临时文件（`/tmp/release_changelog.txt`），供用户编辑后确认

### `archive_and_export.sh`

- 参数：`<platform>`
- **动态生成 exportOptionsPlist**（运行时创建临时文件，无需预提交）：
  - macOS: `method = developer-id`, `teamID = 94L7P6P9PY`
  - iOS: `method = app-store`, `teamID = 94L7P6P9PY`
  - tvOS: `method = app-store`, `teamID = 94L7P6P9PY`
- `xcodebuild archive -workspace {platform}/AniXPlayer.xcworkspace -scheme AniXPlayer -configuration Release -archivePath /tmp/AniXPlayer.xcarchive`
- `xcodebuild -exportArchive -archivePath /tmp/AniXPlayer.xcarchive -exportPath /tmp/export -exportOptionsPlist /tmp/exportOptions.plist`

### `notarize.sh`

- macOS only
- 执行前检查 Keychain profile 是否存在：`xcrun notarytool history --keychain-profile "AC_PASSWORD"`
- `xcrun notarytool submit <app_path> --keychain-profile "AC_PASSWORD" --wait`
- 公证可能耗时 5-15 分钟，使用 `--wait` 等待完成，终端显示提交 ID 和状态
- 通过后 `xcrun stapler staple <app_path>`

### `publish.sh`

- 参数：`<platform> <app_path> <version_tag> <changelog_file>`
- macOS 分支：
  1. 调用 `$REPO_ROOT/Mac/create-dmg.sh <app_path>` 生成 DMG
  2. DMG 命名：`AniXPlayer-{shortVersion}-build{build}.dmg`
  3. `gh release create <tag> --title "<tag>" --notes-file <changelog_file> <dmg>`
  4. `git tag <tag> && git push origin <tag>`
  5. 更新 `$UPDATE_REPO/check_version.json`（更新仓库路径可配置，默认 `../dandanplay_mac_update/`）
  6. 更新仓库 `commit` + `tag` + `push`
- iOS/tvOS 分支：
  1. 用 `xcrun altool --upload-app` 上传至 App Store Connect
  2. `git tag <tag> && git push origin <tag>`

## check_version.json Schema

```json
{
  "url": "https://github.com/sunsx9316/DanDanPlay_Experience/releases/download/v1.7.0/AniXPlayer-1.7.0-build2026062701.dmg",
  "version": "2026062701",
  "shortVersion": "1.7.0",
  "desc": "1. 添加字幕大小调整功能\n2. 修复播放崩溃问题",
  "hash": "",
  "forceUpdate": false
}
```

| 字段 | 来源 | 说明 |
|------|------|------|
| `url` | GitHub Release 上传后返回的下载链接 | DMG 直链 |
| `version` | `calc_version.sh` 输出的 `NEW_BUILD` | build 号 |
| `shortVersion` | `calc_version.sh` 输出的 `NEW_SHORT_VERSION` | 显示版本 |
| `desc` | `gen_changelog.sh` 输出 + 用户编辑 | 更新日志 |
| `hash` | 留空 | Mac 客户端未校验此字段 |
| `forceUpdate` | 固定 `false` | 非强制更新 |

## Git 预检

`release.sh` 在执行任何操作前检查：

1. **working tree clean**: `git diff --quiet && git diff --staged --quiet`，否则拒绝
2. **分支检查**: 必须在 `develop` 分支（或用户指定分支），否则警告
3. **与远程同步**: `git fetch && git diff HEAD..origin/develop --quiet`，否则警告
4. **pod install 同步**: 检查 `Pods/Manifest.lock` 与 `Podfile.lock` 是否一致，不一致则自动运行 `pod install`

## 三平台差异

| | macOS | iOS | tvOS |
|---|---|---|---|
| workspace | `Mac/AniXPlayer.xcworkspace` | `iOS/AniXPlayer.xcworkspace` | `tvOS/AniXPlayer.xcworkspace` |
| scheme | `AniXPlayer` | `AniXPlayer` | `AniXPlayer` |
| 签名 | Apple Distribution | Apple Distribution | Apple Distribution |
| 产物 | `.app` → `.dmg` | `.ipa` | `.ipa` |
| 公证 | 需要 | — | — |
| 分发 | GitHub Release | App Store Connect | App Store Connect |
| 更新仓库 | Gitee | — | — |

## 用户确认

三个确认点由主脚本暂停，等待用户输入：

1. **版本号确认**：展示 `calc_version.sh` 的输出，用户输入 `y` 继续或手动输入修正值
2. **更新日志确认**：展示 `gen_changelog.sh` 输出，用户可以编辑 `/tmp/release_changelog.txt` 后再确认
3. **最终确认**：展示所有产物信息（路径、大小、版本号、日志摘要），输入 `y` 后执行 publish

## 环境前提

### 一次性配置

| 项目 | 说明 | 命令 |
|------|------|------|
| **create-dmg** | npm 的 `create-dmg` 是 x86_64，arm64 Mac 需重装 | `arch -arm64 npm install -g create-dmg` 或 `brew install create-dmg` |
| **notarytool profile** | 公证凭证存储在 Keychain | `xcrun notarytool store-credentials "AC_PASSWORD" --apple-id <your_id> --team-id 94L7P6P9PY --password <app_specific_password>` |
| **gh CLI 登录** | GitHub 认证 | `gh auth login` |
| **Gitee SSH** | 更新仓库推送 | 确保 `~/.ssh/config` 配置了 `gitee.com` 的密钥 |
| **Apple Distribution 证书** | 签名用（已有） | Keychain 中有 `Apple Distribution: Hongjun Xu (94L7P6P9PY)` |
| **entitlements** | macOS 沙箱权限 | 当前 entitlements 为空，需确认是否需要开启沙箱或关闭（见下方说明） |

### Entitlements 说明

当前 `Mac/AniXPlayer/AniXPlayer.entitlements` 为空（`<dict/>`），但 `ENABLE_APP_SANDBOX = YES`。对于非 App Store 分发的视频播放器应用，有两个选择：

1. **关闭沙箱**（推荐）：`ENABLE_APP_SANDBOX = NO`，删除 entitlements 中不需要的内容。视频播放器需要访问文件系统、网络等，沙箱限制太大。
2. **开启沙箱**：需在 entitlements 中添加 `com.apple.security.app-sandbox`、`com.apple.security.network.client`、`com.apple.security.files.user-selected.read-write` 等权限。

### 运行时依赖

| 工具 | 用途 | 验证 |
|------|------|------|
| `xcodebuild` | 打包 | 系统自带 |
| `xcrun notarytool` | 公证 | macOS 13+ 自带 |
| `agvtool` | 版本号管理 | 系统自带 |
| `gh` | GitHub Release | 已安装 v2.93.0 |
| `create-dmg` | DMG 打包 | 需修复架构问题 |
| `git` | 版本控制 | 系统自带 |

## 错误处理与回滚

- 构建/公证失败 → publish 不执行，清理临时文件，pbxproj 有备份可恢复
- publish 部分失败（如 GitHub Release 成功但 Gitee push 失败）→ 手动清理，脚本提示失败位置
- 确认点 1/2 处可随时 Ctrl+C 退出，未做任何修改（预检之后、改版本之前）

## 约束

- macOS 12.0+
- 需在仓库根目录执行 `scripts/release/release.sh <platform>`
- SPM 依赖由 Xcode 自动管理
- 更新仓库路径默认 `../dandanplay_mac_update/`，可通过环境变量 `UPDATE_REPO_PATH` 覆盖
