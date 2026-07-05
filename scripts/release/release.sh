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
source <("$SCRIPT_DIR/calc_version.sh" "$PLATFORM")
echo "  shortVersion: $NEW_SHORT_VERSION"
echo "  build:        $NEW_BUILD"
echo "  上次 tag:     $(git tag --sort=-creatordate | grep "^${PLATFORM}-v" | head -1)"

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
LAST_TAG=$(git tag --sort=-creatordate | grep "^${PLATFORM}-v" | head -1)
CHANGELOG_FILE="/tmp/release_changelog_${PLATFORM}.txt"
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
VERSION_TAG="${PLATFORM}-v${NEW_SHORT_VERSION}-${NEW_BUILD}"
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
