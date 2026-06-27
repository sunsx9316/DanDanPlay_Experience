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

### Step 1: 计算版本号

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/calc_version.sh
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

### Step 2: 更新工程版本号

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/update_project_version.sh <platform> <shortVersion> <build>
```

### Step 3: 生成更新日志

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
LAST_TAG=$(git tag --sort=-creatordate | grep '^v' | head -1)
bash scripts/release/gen_changelog.sh "$LAST_TAG"
```

把更新日志内容展示给用户。用 **AskUserQuestion** 确认：
- “确认，日志没问题” (Recommended)
- “我来编辑日志内容”

如果用户要编辑，等他修改完 `/tmp/release_changelog.txt` 再确认。

### Step 4: Archive + Export（后台执行）

这一步耗时较长（几分钟到十几分钟），用 `run_in_background` 执行：

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/archive_and_export.sh <platform>
```

等待完成后检查结果，产物路径：`/tmp/export/AniXPlayer.app`（mac）或 `*.ipa`（ios/tvos）。

如果构建失败，展示错误信息，**终止**。

### Step 5: 公证（仅 macOS，后台执行）

公证耗时 5-15 分钟，用 `run_in_background` 执行：

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/notarize.sh /tmp/export/AniXPlayer.app
```

等待完成后检查结果。如果公证失败，展示错误信息，**终止**。

### Step 6: 最终确认 + 发布

展示汇总信息：
- 平台、版本号、Build、产物路径、产物大小
- 更新日志摘要
- 接下来将执行的操作（DMG、GitHub Release、git tag、更新仓库）

用 **AskUserQuestion** 最终确认：
- “确认发布” (Recommended)
- “取消”

确认后执行发布：

```bash
cd /Users/jimhuang/Dev/DanDanPlay_Experience
bash scripts/release/publish.sh <platform> /tmp/export/AniXPlayer.app <shortVersion> <build> /tmp/release_changelog.txt
```

## 注意事项

- 环境前提：`brew install create-dmg` 已完成，notarytool `AC_PASSWORD` 已配置
- macOS 发布会推送到 GitHub Release + Gitee 更新仓库
- iOS / tvOS 发布目前仅完成 Archive + Export 部分，App Store Connect 上传待后续实现
- 如果某步失败，用户可以从失败的那步重来（子脚本可独立运行）
