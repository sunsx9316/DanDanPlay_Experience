---
name: release-app
description: 发布 AniXPlayer 新版本，支持 mac / ios / tvos。触发词："发布"、"打包"、"release" + "mac"/"ios"/"tvos"/"app"。
---

# App 发布

## 触发

当用户说“发布 mac”、“打包 ios”、“release app”、“发个新版本”等时触发。

## 平台映射

| 用户说法 | platform | 目录 |
|----------|----------|------|
| mac / macOS | `mac` | `Mac` |
| ios / iPhone | `ios` | `iOS` |
| tvos / Apple TV | `tvos` | `tvOS` |

## 流程

### Step 0: 预检

```bash
# 检查 working tree 是否干净
cd /Users/jimhuang/Dev/DanDanPlay_Experience
git diff --quiet && git diff --staged --quiet || echo "DIRTY"
```

如果是 DIRTY，提示用户先处理，**终止**。

```bash
# 检查分支
git branch --show-current
```

如果不是 `develop`，用 AskUserQuestion 确认是否继续。

```bash
# fetch 并检查是否与远程同步
git fetch origin --quiet
git rev-parse HEAD
git rev-parse origin/develop
```

如果不一致，用 AskUserQuestion 确认是否继续。

```bash
# macOS: 检查 pod install 是否需要
diff Mac/Podfile.lock Mac/Pods/Manifest.lock &>/dev/null || echo "NEED_POD_INSTALL"
```

如需 pod install，自动执行 `cd Mac && pod install`。

### Step 1: 选择发布模式（仅 iOS / tvOS）

iOS / tvOS 有两种发布模式：

| 模式 | 版本号 | Build | 说明 |
|------|--------|-------|------|
| TestFlight | 不变 | 只增 build | 内部测试，同一版本可多次上传 |
| App Store | 更新 | 更新 | 正式发布 |

macOS 跳过此步骤，直接到 Step 2。

用 **AskUserQuestion** 询问：
- "TestFlight（只改 build 号，不改版本号）" (Recommended)
- "App Store 正式发布"

### Step 2: 计算版本号

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
# App Store / macOS 模式
bash scripts/release/calc_version.sh
# TestFlight 模式
bash scripts/release/calc_version.sh --testflight <platform>
```

输出示例：
```
NEW_SHORT_VERSION=1.6.3
NEW_BUILD=2026062701
```

用 **AskUserQuestion** 让用户确认版本号，选项：
- “确认，使用自动计算的版本” (Recommended)
- “我来手动指定版本号”

如果用户选择手动指定，再问他要什么版本号。

### Step 3: 更新工程版本号

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
# App Store / macOS 模式
bash scripts/release/update_project_version.sh <platform> <shortVersion> <build>
# TestFlight 模式
bash scripts/release/update_project_version.sh <platform> --testflight <build>
```

### Step 4: 生成更新日志

**核心原则：更新日志必须只包含当前平台相关的改动。** 例如打包 iOS，日志只列 iOS 相关的功能，不出现 Mac/tvOS 专属内容。

**Tag 规则**: 格式 `<platform>-v{version}-{build}`（如 `ios-v1.6.3-2026070501`），查找上一版本 tag 时用平台前缀。

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
LAST_TAG=$(git tag --sort=-creatordate | grep “^v.*-<platform>” | head -1)
```

**日志内容规则（按优先级排序）**:

1. **只看当前平台相关目录的改动**:
   - `iOS/` + `Share/`（iOS）
   - `tvOS/` + `Share/`（tvOS）
   - `Mac/` + `Share/`（macOS）
   - 不在此范围内的目录（如其他平台的专属目录）的改动**一律忽略**

2. **Share/ 目录改动需二次判断**：Share/ 下的代码三平台共用，但需判断改动是否影响当前平台。与当前平台无关的 Share/ 改动（如仅被其他平台引用的代码）应排除

3. **只看 feat / update 类型提交**，跳过 docs、chore、refactor、style、test、ci、build、opt 等

4. **只保留用户可感知的功能改动**，剔除发布自动化、构建脚本、CI/CD、内部重构等非用户向内容

5. **严格排除其他平台专属功能**：
   - 发布 iOS 时：不含 Mac 专属（菜单栏、窗口管理、DMG 安装等）、tvOS 专属功能
   - 发布 tvOS 时：不含 iOS 专属（PiP、横竖屏旋转等）、Mac 专属功能
   - 发布 Mac 时：不含 iOS 专属（PiP、触控手势等）、tvOS 专属（Focus Engine 等）功能

6. **修复类提交**统一写一句”修复若干已知问题”，不展开

7. **按功能聚合**：播放器、弹幕、媒体服务器、设置等，每个功能 3-5 条要点

**生成方式**: 不用 `gen_changelog.sh`，而是手动分析 git log 后写入 `/tmp/release_changelog_<platform>.txt`。分析时：
- 先用 `git log --oneline <LAST_TAG>..HEAD -- <platform_dir/> Share/` 获取候选提交
- 逐条判断是否与当前平台相关
- 合并同类的 feat/update，剔除平台无关的内容

把更新日志内容展示给用户。用 **AskUserQuestion** 确认：
- “确认，日志没问题” (Recommended)
- “我来编辑日志内容”

如果用户要编辑，等他修改完 `/tmp/release_changelog_<platform>.txt` 再确认。

用户确认后，追加到持久化 changelog：
```bash
cp /tmp/release_changelog_<platform>.txt scripts/release/changelogs/<platform>.txt
```

> changelog 按平台独立维护于 `scripts/release/changelogs/<platform>.txt`。

### Step 5: Archive + Export（后台执行）

这一步耗时较长（几分钟到十几分钟），用 `run_in_background` 执行：

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/archive_and_export.sh <platform>
```

等待完成后检查结果，产物路径：`/tmp/export/AniXPlayer.app`（mac）或 `*.ipa`（ios/tvos）。

如果构建失败，展示错误信息，**终止**。

**常见错误排查**：

| 错误 | 原因 | 处理 |
|------|------|------|
| `Provisioning profile "xxx" doesn't support the iCloud capability` | Store Provisioning Profile 不含 iCloud entitlement（entitlements 新增 iCloud 后出现） | 用 `-allowProvisioningUpdates` 重试导出：`xcodebuild -exportArchive -archivePath /tmp/AniXPlayer.xcarchive -exportPath /tmp/export -exportOptionsPlist /tmp/exportOptions.plist -allowProvisioningUpdates` |
| `Your session has expired. Please log in.` | Apple ID session 过期 | 在 Xcode → Settings → Accounts 中重新登录 |

### Step 6: 创建 DMG（仅 macOS）

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/create_dmg.sh /tmp/export/AniXPlayer.app
```

产物：`/tmp/export/AniXPlayer.dmg`

DMG 包含：App、Applications 快捷方式、弹弹Play 官网 .webloc，使用列表模式。

### Step 7: 公证 DMG（仅 macOS，后台执行）

公证耗时 5-15 分钟，用 `run_in_background` 执行：

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/notarize.sh /tmp/export/AniXPlayer.dmg
```

`notarize.sh` 支持 `.app`（自动打包为 zip 提交）和 `.dmg`（直接提交），公证成功后自动钉入票据。

等待完成后检查结果。如果公证失败，展示错误信息，**终止**。

### Step 8: 最终确认 + 发布

展示汇总信息：
- 平台、版本号、Build、产物路径、产物大小
- 更新日志摘要
- 接下来将执行的操作（GitHub Release、git tag、更新仓库）

用 **AskUserQuestion** 最终确认：
- “确认发布” (Recommended)
- “取消”

确认后执行发布，引用当前平台的 changelog：

**macOS:**
```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/publish.sh mac /tmp/export/AniXPlayer.dmg <shortVersion> <build> /tmp/release_changelog_mac.txt
```

**iOS / tvOS:**
```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/publish.sh <ios|tvos> /tmp/export/AniXPlayer.ipa <shortVersion> <build> /tmp/release_changelog_<platform>.txt
```

## 注意事项

- macOS 环境前提：notarytool `AC_PASSWORD`、`gh` CLI 已配置，`UPDATE_REPO_PATH`（Gitee 更新仓库）
- iOS / tvOS 环境前提：`APP_SPECIFIC_PASSWORD` 环境变量（建议写入 `~/.zshrc` 持久化）+ `APPLE_ID`（默认 `jimhuang099@gmail.com`）
- **Xcode 17 `altool` keychain 兼容性**：`altool --store-password-in-keychain-item` 在 Xcode 17 中可能无法正确读取 keychain 条目，如果 publish.sh 报 keychain 错误，改用 `@env:APP_SPECIFIC_PASSWORD` 直接上传：
  ```bash
  xcrun altool --validate-app -f /tmp/export/AniXPlayer.ipa -t <ios|tvos> -u jimhuang099@gmail.com -p "@env:APP_SPECIFIC_PASSWORD"
  xcrun altool --upload-app -f /tmp/export/AniXPlayer.ipa -t <ios|tvos> -u jimhuang099@gmail.com -p "@env:APP_SPECIFIC_PASSWORD"
  git tag "<platform>-v<version>-<build>" && git push origin "<platform>-v<version>-<build>"
  ```
- macOS 发布会推送到 GitHub Release + Gitee 更新仓库 + git tag
- iOS / tvOS 发布会上传 `.ipa` 到 App Store Connect + git tag（后续需在 App Store Connect 中完成提审）
- 如果某步失败，用户可以从失败的那步重来（子脚本可独立运行）
