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

## 目录结构

```
scripts/release/
├── release.sh                   # 主编排脚本，接受 platform 参数
├── calc_version.sh              # 计算新版本号
├── update_project_version.sh    # 更新 pbxproj 中的版本号
├── gen_changelog.sh             # 从上次 tag 到 HEAD 生成更新日志
├── archive_and_export.sh        # xcodebuild archive + exportArchive
├── notarize.sh                  # macOS 公证（xcrun notarytool）
└── publish.sh                   # DMG/Release/Git 操作
```

## 流程与确认点

```
release.sh <mac|ios|tvos>

calc_version.sh
    │
    ▼
[确认点 1] 展示计算出的 shortVersion + build，等用户确认
    │
    ▼
update_project_version.sh   ←  写入 pbxproj
gen_changelog.sh            ←  git log <last_tag>..HEAD --oneline --no-merges
    │
    ▼
[确认点 2] 展示更新日志，等用户确认（可编辑）
    │
    ▼
archive_and_export.sh       ←  xcodebuild archive → exportArchive
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

- 从 `git tag --sort=-creatordate | head -1` 获取最新 tag
- 从上次 tag 解析 `shortVersion`，按规则计算新版本
- 检查当天是否已有打包（查看当天 tag），决定 build 号的 `XX`
- 输出：`NEW_SHORT_VERSION`、`NEW_BUILD`

### `update_project_version.sh`

- 参数：`<platform> <shortVersion> <build>`
- 用 `sed` 替换 `{platform}/AniXPlayer.xcodeproj/project.pbxproj` 中的 `MARKETING_VERSION` 和 `CURRENT_PROJECT_VERSION`
- Debug 和 Release 配置各一处，共 4 次替换

### `gen_changelog.sh`

- `git log <last_tag>..HEAD --pretty=format:"- %s" --no-merges`
- 输出到临时文件，供用户编辑后确认

### `archive_and_export.sh`

- 参数：`<platform> <workspace> <scheme> <archivePath> <exportOptionsPlist>`
- `xcodebuild archive` → `<archivePath>.xcarchive`
- `xcodebuild -exportArchive -exportOptionsPlist <plist>` → `.app`/`.ipa`
- macOS exportOptionsPlist: `method = developer-id`
- iOS/tvOS exportOptionsPlist: `method = app-store`（或 `ad-hoc` 按需）

### `notarize.sh`

- macOS only
- `xcrun notarytool submit <app_path> --keychain-profile "AC_PASSWORD" --wait`
- 通过后 `xcrun stapler staple <app_path>`
- 凭证通过 Keychain profile `AC_PASSWORD` 管理（需提前配置）

### `publish.sh`

- 参数：`<platform> <app_path> <version> <changelog>`
- macOS 分支：
  1. 调用 `Mac/create-dmg.sh` 生成 DMG
  2. `gh release create <tag> --notes <changelog> <dmg>`
  3. `git tag <tag> && git push origin <tag>`
  4. 更新 `dandanplay_mac_update/check_version.json`：`url`（GitHub Release 下载链接）、`version`、`shortVersion`、`desc`
  5. 在更新仓库 `commit` + `tag` + `push`
- iOS/tvOS 分支：
  1. `xcodebuild -exportArchive` 导出 ipa（或 `xcrun altool --upload-app`）
  2. `git tag <tag> && git push origin <tag>`

## 三平台差异

| | macOS | iOS | tvOS |
|---|---|---|---|
| workspace | `Mac/AniXPlayer.xcworkspace` | `iOS/AniXPlayer.xcworkspace` | `tvOS/AniXPlayer.xcworkspace` |
| scheme | `AniXPlayer` | `AniXPlayer` | `AniXPlayer` |
| 产物 | `.app` → `.dmg` | `.ipa` | `.ipa` |
| 签名 | Developer ID | Distribution | Distribution |
| 公证 | 需要 | — | — |
| 分发 | GitHub Release | App Store Connect | App Store Connect |
| 更新仓库 | Gitee | — | — |

## 用户确认

三个确认点由主脚本暂停，等待用户输入：

1. **版本号确认**：展示 `calc_version.sh` 的输出，用户输入 `y` 继续或手动输入修正值
2. **更新日志确认**：展示 `gen_changelog.sh` 输出，用户可以编辑文件后再确认
3. **最终确认**：展示所有产物信息（路径、大小、版本号），输入 `y` 后执行 publish

## 凭证依赖

- **Keychain**: `AC_PASSWORD` profile（用于 notarytool，需用户提前配置 `xcrun notarytool store-credentials`）
- **gh CLI**: 已安装且已登录（用于 GitHub Release）
- **Git SSH**: gitee.com 和 github.com 的 SSH key（用于 push）

## 约束

- macOS 12.0+
- 需在 Mac 工作目录执行
- SPM 依赖由 Xcode 自动管理，脚本无需干预
- CocoaPods 依赖在 `pod install` 后通常无需重复执行，如有需要手动先跑
