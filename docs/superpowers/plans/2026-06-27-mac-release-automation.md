# Mac 打包自动化实现计划

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 创建一套 shell 脚本，自动化 Mac 应用的打包、公证、DMG 创建、GitHub Release 发布和更新仓库维护流程。

**Architecture:** 7 个独立脚本 + 1 个主编排脚本，放在 `scripts/release/` 下。主脚本按阶段调用子脚本，在 3 个关键节点暂停等待用户确认。子脚本可独立运行，方便失败后重来。

**Tech Stack:** Bash (set -euo pipefail), agvtool, xcodebuild, xcrun notarytool, gh CLI, create-dmg (brew), git

---

## 文件结构

```
scripts/release/
├── release.sh                   # 主编排脚本 (新建)
├── calc_version.sh              # 版本号计算 (新建)
├── update_project_version.sh    # agvtool 更新版本号 (新建)
├── gen_changelog.sh             # git log 生成更新日志 (新建)
├── archive_and_export.sh        # xcodebuild archive + export (新建)
├── notarize.sh                  # notarytool 公证 (新建)
└── publish.sh                   # DMG + Release + git 操作 (新建)

Mac/create-dmg.sh                # 增强，支持指定 DMG 输出文件名 (修改)
```

所有子脚本通过参数和 exit code 通信。`calc_version.sh` 额外输出 `KEY=VALUE` 到 stdout 供主脚本 `source`。

---

### Task 1: 创建目录和 `calc_version.sh`

**Files:**
- Create: `scripts/release/calc_version.sh`

- [ ] **Step 1: 创建目录**

```bash
mkdir -p scripts/release
```

- [ ] **Step 2: 编写 `calc_version.sh`**

```bash
#!/bin/bash
set -euo pipefail

# 从最新 git tag 计算下一个版本号
# 输出格式（可被 source）:
#   NEW_SHORT_VERSION=1.7.0
#   NEW_BUILD=2026062701

LAST_TAG=$(git tag --sort=-creatordate | grep '^v' | head -1)
if [ -z "$LAST_TAG" ]; then
    echo "错误: 未找到任何版本 tag，请先手动创建一个（如 v1.0.0）" >&2
    exit 1
fi

# 解析 last tag: v1.6.2 → major=1, month=6, minor=2
LAST_SHORT="${LAST_TAG#v}"
IFS='.' read -r MAJOR LAST_MONTH LAST_MINOR <<< "$LAST_SHORT"

CURRENT_MONTH=$(date +%-m)
CURRENT_YEAR=$(date +%Y)
TODAY=$(date +%Y%m%d)

# 计算 shortVersion
if [ "$CURRENT_MONTH" -ne "$LAST_MONTH" ]; then
    NEW_MINOR=0
else
    NEW_MINOR=$((LAST_MINOR + 1))
fi
NEW_SHORT_VERSION="${MAJOR}.${CURRENT_MONTH}.${NEW_MINOR}"

# 计算 build: YYYYMMDDXX
# 检查今天已有的 tag 数量来确定 XX
TODAY_COUNT=$(git tag --sort=-creatordate | grep '^v' | head -20 | while read t; do
    git log -1 --format="%ai" "$t" 2>/dev/null || echo ""
done | grep "^${CURRENT_YEAR}-" | wc -l | tr -d ' ')

# 更简单的方式：检查当前 build 号是否以今天日期开头
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" Mac/AniXPlayer.xcodeproj/project.pbxproj | head -1 | sed 's/.*= //;s/;//')
if [[ "$CURRENT_BUILD" == "$TODAY"* ]]; then
    TODAY_SEQ=$((10#${CURRENT_BUILD:8:2} + 1))
else
    TODAY_SEQ=1
fi
NEW_BUILD=$(printf "%s%02d" "$TODAY" "$TODAY_SEQ")

echo "NEW_SHORT_VERSION=$NEW_SHORT_VERSION"
echo "NEW_BUILD=$NEW_BUILD"
```

- [ ] **Step 3: 添加可执行权限并测试**

```bash
chmod +x scripts/release/calc_version.sh
# 测试运行
bash scripts/release/calc_version.sh
# 预期输出示例: NEW_SHORT_VERSION=1.6.3  NEW_BUILD=2026062701
```

- [ ] **Step 4: Commit**

```bash
git add scripts/release/calc_version.sh
git commit -m "feat(release): 添加 calc_version.sh 版本号计算脚本"
```

---

### Task 2: `update_project_version.sh`

**Files:**
- Create: `scripts/release/update_project_version.sh`

- [ ] **Step 1: 编写脚本**

```bash
#!/bin/bash
set -euo pipefail

# 使用 agvtool 更新 Xcode 工程版本号
# 用法: update_project_version.sh <platform> <short_version> <build>

PLATFORM="$1"
SHORT_VERSION="$2"
BUILD="$3"

if [ -z "$PLATFORM" ] || [ -z "$SHORT_VERSION" ] || [ -z "$BUILD" ]; then
    echo "用法: $0 <mac|ios|tvos> <shortVersion> <build>"
    exit 1
fi

# 映射 platform 到目录名
case "$PLATFORM" in
    mac)  PLATFORM_DIR="Mac" ;;
    ios)  PLATFORM_DIR="iOS" ;;
    tvos) PLATFORM_DIR="tvOS" ;;
    *)    echo "错误: 无效平台 '$PLATFORM'，支持 mac/ios/tvos" >&2; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
cd "$REPO_ROOT/$PLATFORM_DIR"

# 备份 pbxproj
cp "AniXPlayer.xcodeproj/project.pbxproj" "AniXPlayer.xcodeproj/project.pbxproj.bak"
echo "已备份 project.pbxproj → project.pbxproj.bak"

# 更新版本号
echo "更新 MARKETING_VERSION → $SHORT_VERSION"
agvtool new-marketing-version "$SHORT_VERSION"

echo "更新 CURRENT_PROJECT_VERSION → $BUILD"
agvtool new-version -all "$BUILD"

echo "版本号更新完成"
```

- [ ] **Step 2: 添加可执行权限**

```bash
chmod +x scripts/release/update_project_version.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release/update_project_version.sh
git commit -m "feat(release): 添加 update_project_version.sh 版本号更新脚本"
```

---

### Task 3: `gen_changelog.sh`

**Files:**
- Create: `scripts/release/gen_changelog.sh`

- [ ] **Step 1: 编写脚本**

```bash
#!/bin/bash
set -euo pipefail

# 从上次 tag 到 HEAD 生成更新日志
# 用法: gen_changelog.sh <last_tag> [output_file]
# 默认输出到 /tmp/release_changelog.txt

LAST_TAG="${1:-}"
OUTPUT_FILE="${2:-/tmp/release_changelog.txt}"

if [ -z "$LAST_TAG" ]; then
    echo "用法: $0 <last_tag> [output_file]" >&2
    echo "示例: $0 v1.6.2" >&2
    exit 1
fi

echo "生成更新日志: $LAST_TAG..HEAD"

# 生成日志
git log "${LAST_TAG}..HEAD" --pretty=format:"- %s" --no-merges > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "警告: $LAST_TAG..HEAD 之间没有新的 commit" >&2
    echo "(空)" > "$OUTPUT_FILE"
fi

echo "更新日志已写入: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
```

- [ ] **Step 2: 添加可执行权限**

```bash
chmod +x scripts/release/gen_changelog.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release/gen_changelog.sh
git commit -m "feat(release): 添加 gen_changelog.sh 更新日志生成脚本"
```

---

### Task 4: `archive_and_export.sh`

**Files:**
- Create: `scripts/release/archive_and_export.sh`

- [ ] **Step 1: 编写脚本**

```bash
#!/bin/bash
set -euo pipefail

# xcodebuild archive + exportArchive
# 用法: archive_and_export.sh <mac|ios|tvos>
# 导出产物路径输出到 stdout

PLATFORM="$1"

if [ -z "$PLATFORM" ]; then
    echo "用法: $0 <mac|ios|tvos>" >&2
    exit 1
fi

case "$PLATFORM" in
    mac)  PLATFORM_DIR="Mac";  EXPORT_METHOD="developer-id" ;;
    ios)  PLATFORM_DIR="iOS";  EXPORT_METHOD="app-store" ;;
    tvos) PLATFORM_DIR="tvOS"; EXPORT_METHOD="app-store" ;;
    *)    echo "错误: 无效平台 '$PLATFORM'" >&2; exit 1 ;;
esac

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
ARCHIVE_PATH="/tmp/AniXPlayer.xcarchive"
EXPORT_PATH="/tmp/export"
EXPORT_PLIST="/tmp/exportOptions.plist"

# 清理旧产物
rm -rf "$ARCHIVE_PATH" "$EXPORT_PATH"

# 动态生成 exportOptionsPlist
/usr/libexec/PlistBuddy -c "Clear dict" "$EXPORT_PLIST" 2>/dev/null || true
cat > "$EXPORT_PLIST" << PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>method</key>
    <string>${EXPORT_METHOD}</string>
    <key>teamID</key>
    <string>94L7P6P9PY</string>
</dict>
</plist>
PLIST

echo "=== Archive ==="
xcodebuild archive \
    -workspace "$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcworkspace" \
    -scheme AniXPlayer \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH" \
    | xcbeautify 2>/dev/null || \
xcodebuild archive \
    -workspace "$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcworkspace" \
    -scheme AniXPlayer \
    -configuration Release \
    -archivePath "$ARCHIVE_PATH"

echo "=== Export ==="
xcodebuild -exportArchive \
    -archivePath "$ARCHIVE_PATH" \
    -exportPath "$EXPORT_PATH" \
    -exportOptionsPlist "$EXPORT_PLIST"

# 输出产物路径
if [ "$PLATFORM" = "mac" ]; then
    APP_PATH="$EXPORT_PATH/AniXPlayer.app"
else
    APP_PATH=$(find "$EXPORT_PATH" -name "*.ipa" | head -1)
fi

echo "产物路径: $APP_PATH"
echo "EXPORTED_APP=$APP_PATH"
```

- [ ] **Step 2: 添加可执行权限**

```bash
chmod +x scripts/release/archive_and_export.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release/archive_and_export.sh
git commit -m "feat(release): 添加 archive_and_export.sh 构建导出脚本"
```

---

### Task 5: `notarize.sh`

**Files:**
- Create: `scripts/release/notarize.sh`

- [ ] **Step 1: 编写脚本**

```bash
#!/bin/bash
set -euo pipefail

# macOS 公证
# 用法: notarize.sh <app_path>

APP_PATH="$1"
KEYCHAIN_PROFILE="AC_PASSWORD"

if [ -z "$APP_PATH" ]; then
    echo "用法: $0 <app_path>" >&2
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到 app: $APP_PATH" >&2
    exit 1
fi

# 检查 Keychain profile
echo "=== 检查公证凭证 ==="
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    echo "错误: Keychain profile '${KEYCHAIN_PROFILE}' 不存在" >&2
    echo "请先配置: xcrun notarytool store-credentials '${KEYCHAIN_PROFILE}'" >&2
    exit 1
fi
echo "凭证 OK"

# 提交公证
echo "=== 提交公证（可能需要 5-15 分钟）==="
xcrun notarytool submit "$APP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# 钉入票据
echo "=== 钉入票据 ==="
xcrun stapler staple "$APP_PATH"

echo "公证完成: $APP_PATH"
```

- [ ] **Step 2: 添加可执行权限**

```bash
chmod +x scripts/release/notarize.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release/notarize.sh
git commit -m "feat(release): 添加 notarize.sh 公证脚本"
```

---

### Task 6: `publish.sh`

**Files:**
- Create: `scripts/release/publish.sh`

- [ ] **Step 1: 编写脚本**

```bash
#!/bin/bash
set -euo pipefail

# 发布：DMG + GitHub Release + git tag + 更新仓库
# 用法: publish.sh <platform> <app_path> <short_version> <build> <changelog_file>

PLATFORM="$1"
APP_PATH="$2"
SHORT_VERSION="$3"
BUILD="$4"
CHANGELOG_FILE="$5"

if [ -z "$PLATFORM" ] || [ -z "$APP_PATH" ] || [ -z "$SHORT_VERSION" ] || [ -z "$BUILD" ] || [ -z "$CHANGELOG_FILE" ]; then
    echo "用法: $0 <mac|ios|tvos> <app_path> <short_version> <build> <changelog_file>" >&2
    exit 1
fi

REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
VERSION_TAG="v${SHORT_VERSION}"

if [ "$PLATFORM" = "mac" ]; then
    # 1. 创建 DMG
    echo "=== 创建 DMG ==="
    DMG_NAME="AniXPlayer-${SHORT_VERSION}-build${BUILD}.dmg"
    "$REPO_ROOT/Mac/create-dmg.sh" "$APP_PATH" "$DMG_NAME"
    DMG_PATH="$(dirname "$APP_PATH")/$DMG_NAME"
    echo "DMG: $DMG_PATH"

    # 2. GitHub Release
    echo "=== 创建 GitHub Release ==="
    gh release create "$VERSION_TAG" \
        --title "$VERSION_TAG" \
        --notes-file "$CHANGELOG_FILE" \
        "$DMG_PATH"

    # 3. Tag + push 主仓库
    echo "=== Tag 主仓库 ==="
    git tag "$VERSION_TAG"
    git push origin "$VERSION_TAG"

    # 4. 更新 check_version.json
    echo "=== 更新 check_version.json ==="
    UPDATE_REPO="${UPDATE_REPO_PATH:-$REPO_ROOT/../dandanplay_mac_update}"
    if [ ! -d "$UPDATE_REPO/.git" ]; then
        echo "错误: 更新仓库不存在: $UPDATE_REPO" >&2
        exit 1
    fi

    DOWNLOAD_URL="https://github.com/sunsx9316/DanDanPlay_Experience/releases/download/${VERSION_TAG}/${DMG_NAME}"
    DESC=$(cat "$CHANGELOG_FILE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip()))")

    cat > "$UPDATE_REPO/check_version.json" << EOF
{
  "url": "${DOWNLOAD_URL}",
  "version": "${BUILD}",
  "shortVersion": "${SHORT_VERSION}",
  "desc": ${DESC},
  "hash": "",
  "forceUpdate": false
}
EOF

    # 5. 提交 + tag + push 更新仓库
    cd "$UPDATE_REPO"
    git add check_version.json
    git commit -m "[update]更新${SHORT_VERSION}版本"
    git tag "$VERSION_TAG"
    git push origin HEAD
    git push origin "$VERSION_TAG"
    cd "$REPO_ROOT"

    echo "=== 发布完成 ==="
    echo "Release: $(gh release view "$VERSION_TAG" --json url -q '.url')"

elif [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "tvos" ]; then
    # iOS/tvOS: 上传到 App Store Connect
    echo "=== TODO: App Store Connect 上传 ==="
    echo "暂未实现 iOS/tvOS 自动上传，请手动上传 $APP_PATH"
    exit 1
fi
```

- [ ] **Step 2: 添加可执行权限**

```bash
chmod +x scripts/release/publish.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release/publish.sh
git commit -m "feat(release): 添加 publish.sh 发布脚本"
```

---

### Task 7: 增强 `create-dmg.sh` 支持自定义 DMG 名称

**Files:**
- Modify: `Mac/create-dmg.sh`

- [ ] **Step 1: 读取当前文件**

```bash
cat Mac/create-dmg.sh
```

- [ ] **Step 2: 修改脚本，支持第二个可选参数（DMG 输出文件名）**

修改为：

```bash
#!/bin/bash

# 检查是否提供了参数
if [ $# -lt 1 ]; then
    echo "使用方法: $0 <app路径> [dmg名称]"
    exit 1
fi

file_path="$1"
dmg_name="${2:-}"

dir_path=$(dirname "$file_path")
cd "$dir_path" || { echo "无法切换到目录 '$dir_path'"; exit 3; }

if [ -n "$dmg_name" ]; then
    create-dmg --overwrite "$dmg_name" "$file_path"
else
    create-dmg "$file_path"
fi
```

- [ ] **Step 3: Commit**

```bash
git add Mac/create-dmg.sh
git commit -m "feat(release): create-dmg.sh 支持自定义 DMG 文件名"
```

---

### Task 8: `release.sh` 主编排脚本

**Files:**
- Create: `scripts/release/release.sh`

- [ ] **Step 1: 编写主编排脚本**

```bash
#!/bin/bash
set -euo pipefail

# Mac/iOS/tvOS 打包发布主编排脚本
# 用法: release.sh <mac|ios|tvos>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"
cd "$REPO_ROOT"

PLATFORM="${1:-}"
if [ -z "$PLATFORM" ]; then
    echo "用法: $0 <mac|ios|tvos>"
    exit 1
fi

if [ "$PLATFORM" != "mac" ] && [ "$PLATFORM" != "ios" ] && [ "$PLATFORM" != "tvos" ]; then
    echo "错误: 无效平台 '$PLATFORM'，支持 mac/ios/tvos"
    exit 1
fi

case "$PLATFORM" in
    mac)  PLATFORM_DIR="Mac" ;;
    ios)  PLATFORM_DIR="iOS" ;;
    tvos) PLATFORM_DIR="tvOS" ;;
esac

# ============================================================
# 预检
# ============================================================
echo "========================================"
echo "  AniXPlayer 发布脚本 - $PLATFORM"
echo "========================================"
echo ""

# 1. Working tree clean
if ! git diff --quiet || ! git diff --staged --quiet; then
    echo "错误: working tree 不干净，请先提交或 stash 修改"
    exit 1
fi

# 2. 分支检查
CURRENT_BRANCH=$(git branch --show-current)
if [ "$CURRENT_BRANCH" != "develop" ]; then
    echo "警告: 当前分支为 '$CURRENT_BRANCH'，推荐在 develop 分支发布"
    read -p "继续? [y/N]: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
    fi
fi

# 3. 与远程同步
echo "正在 fetch origin..."
git fetch origin --quiet
LOCAL=$(git rev-parse HEAD)
REMOTE=$(git rev-parse origin/develop 2>/dev/null || echo "")
if [ -n "$REMOTE" ] && [ "$LOCAL" != "$REMOTE" ]; then
    echo "警告: 本地和 origin/develop 不一致"
    echo "  Local:  ${LOCAL:0:8}"
    echo "  Remote: ${REMOTE:0:8}"
    read -p "继续? [y/N]: " confirm
    if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
        exit 1
    fi
fi

# 4. Pod install 检查 (macOS 用 CocoaPods)
if [ "$PLATFORM" = "mac" ]; then
    if [ -f "$PLATFORM_DIR/Podfile.lock" ]; then
        if ! diff "$PLATFORM_DIR/Podfile.lock" "$PLATFORM_DIR/Pods/Manifest.lock" &>/dev/null; then
            echo "Podfile.lock 和 Manifest.lock 不一致，正在运行 pod install..."
            cd "$PLATFORM_DIR"
            pod install
            cd "$REPO_ROOT"
        fi
    fi
fi

echo "预检通过 ✓"
echo ""

# ============================================================
# Step 1: 计算版本号
# ============================================================
echo "--- [1/6] 计算版本号 ---"
source <("$SCRIPT_DIR/calc_version.sh")
echo "  shortVersion: $NEW_SHORT_VERSION"
echo "  build:        $NEW_BUILD"
echo "  上次 tag:     $(git tag --sort=-creatordate | grep '^v' | head -1)"

echo ""
read -p "版本号确认，输入 y 继续，或输入新版本号手动修正 (如 1.7.0): " confirm
if [ "$confirm" = "y" ] || [ "$confirm" = "Y" ]; then
    true
elif [[ "$confirm" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
    NEW_SHORT_VERSION="$confirm"
    echo "已手动修正 shortVersion → $NEW_SHORT_VERSION"
else
    echo "已取消"
    exit 1
fi

# ============================================================
# Step 2: 更新工程版本号
# ============================================================
echo ""
echo "--- [2/6] 更新工程版本号 ---"
"$SCRIPT_DIR/update_project_version.sh" "$PLATFORM" "$NEW_SHORT_VERSION" "$NEW_BUILD"

# ============================================================
# Step 3: 生成更新日志
# ============================================================
echo ""
echo "--- [3/6] 生成更新日志 ---"
LAST_TAG=$(git tag --sort=-creatordate | grep '^v' | head -1)
CHANGELOG_FILE="/tmp/release_changelog.txt"
"$SCRIPT_DIR/gen_changelog.sh" "$LAST_TAG" "$CHANGELOG_FILE"

echo ""
echo "你可以编辑 $CHANGELOG_FILE 来修改更新日志"
read -p "确认更新日志，输入 y 继续: " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消"
    exit 1
fi

# ============================================================
# Step 4: Archive + Export
# ============================================================
echo ""
echo "--- [4/6] 构建 Archive ---"
"$SCRIPT_DIR/archive_and_export.sh" "$PLATFORM"
EXPORTED_APP=$(grep "EXPORTED_APP=" /dev/stdin 2>/dev/null || true)

# 获取产物路径
if [ "$PLATFORM" = "mac" ]; then
    APP_PATH="/tmp/export/AniXPlayer.app"
else
    APP_PATH=$(find /tmp/export -name "*.ipa" | head -1)
fi

if [ ! -e "$APP_PATH" ]; then
    echo "错误: 未找到构建产物" >&2
    exit 1
fi
echo "产物: $APP_PATH"

# ============================================================
# Step 5: 公证 (macOS only)
# ============================================================
if [ "$PLATFORM" = "mac" ]; then
    echo ""
    echo "--- [5/6] 公证 ---"
    "$SCRIPT_DIR/notarize.sh" "$APP_PATH"
fi

# ============================================================
# Step 6: 最终确认 + 发布
# ============================================================
echo ""
echo "========================================"
echo "  最终确认"
echo "========================================"
echo "平台:         $PLATFORM"
echo "版本号:       $NEW_SHORT_VERSION"
echo "Build:        $NEW_BUILD"
echo "产物:         $APP_PATH"
if [ -d "$APP_PATH" ]; then
    APP_SIZE=$(du -sh "$APP_PATH" | cut -f1)
    echo "产物大小:     $APP_SIZE"
fi
echo "更新日志:     $CHANGELOG_FILE"
echo "----------------------------------------"
echo "接下来将执行:"
if [ "$PLATFORM" = "mac" ]; then
    echo "  1. 创建 DMG"
    echo "  2. 创建 GitHub Release 并上传 DMG"
    echo "  3. git tag $VERSION_TAG 并推送到 origin"
    echo "  4. 更新 dandanplay_mac_update/check_version.json"
    echo "  5. 推送更新仓库"
fi
echo ""

read -p "确认执行发布？输入 y 继续: " confirm
if [ "$confirm" != "y" ] && [ "$confirm" != "Y" ]; then
    echo "已取消"
    exit 1
fi

"$SCRIPT_DIR/publish.sh" "$PLATFORM" "$APP_PATH" "$NEW_SHORT_VERSION" "$NEW_BUILD" "$CHANGELOG_FILE"

echo ""
echo "========================================"
echo "  发布完成!"
echo "========================================"
```

- [ ] **Step 2: 添加可执行权限**

```bash
chmod +x scripts/release/release.sh
```

- [ ] **Step 3: Commit**

```bash
git add scripts/release/release.sh
git commit -m "feat(release): 添加 release.sh 主编排脚本"
```

---

### Task 9: 安装 create-dmg 并验证

- [ ] **Step 1: 安装 brew create-dmg**

```bash
brew install create-dmg
```

- [ ] **Step 2: 验证 create-dmg 可用**

```bash
create-dmg --help 2>&1 | head -3
# 预期: 显示 create-dmg 帮助信息，无架构错误
```

- [ ] **Step 3: 记录到项目文档**

不需要新 commit，这是本地环境配置。

---

## 使用方式

```bash
# 一键发布（从仓库根目录）
scripts/release/release.sh mac

# 流程:
# 1. 预检
# 2. 显示版本号 → 确认
# 3. 更新工程版本号
# 4. 显示更新日志 → 确认（可编辑 /tmp/release_changelog.txt）
# 5. Archive + Export
# 6. 公证（5-15分钟等待）
# 7. 最终确认 → 自动发布
```

## 回滚方式

如果构建失败，pbxproj 备份在 `Mac/AniXPlayer.xcodeproj/project.pbxproj.bak`，恢复即可：

```bash
cp Mac/AniXPlayer.xcodeproj/project.pbxproj.bak Mac/AniXPlayer.xcodeproj/project.pbxproj
```
