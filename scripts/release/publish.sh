#!/bin/bash
set -euo pipefail

# 发布：DMG + GitHub Release + git tag + 更新仓库
# 用法: publish.sh <platform> <app_path> <short_version> <build> <changelog_file>

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
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
    # 1. 创建/使用 DMG
    DMG_NAME="AniXPlayer-${SHORT_VERSION}-build${BUILD}.dmg"
    if [[ "$APP_PATH" == *.dmg ]]; then
        DMG_PATH="$APP_PATH"
        echo "使用已有 DMG: $DMG_PATH"
    else
        echo "=== 创建 DMG ==="
        "$SCRIPT_DIR/create_dmg.sh" "$APP_PATH" "$DMG_NAME"
        DMG_PATH="$(dirname "$APP_PATH")/$DMG_NAME"
        echo "DMG: $DMG_PATH"
    fi

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
        echo "请设置 UPDATE_REPO_PATH 环境变量或克隆到默认路径" >&2
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
    echo "=== 推送更新仓库 ==="
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
    echo "=== App Store Connect 上传 ==="
    echo "iOS/tvOS 自动上传将在后续版本实现，当前请手动上传: $APP_PATH"
    exit 0
fi
