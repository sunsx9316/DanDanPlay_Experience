#!/bin/bash
set -euo pipefail

# 加载环境变量（GITEE_TOKEN 等）
source ~/.zshrc 2>/dev/null || true

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
VERSION_TAG="${PLATFORM}-v${SHORT_VERSION}-${BUILD}"
# 更新仓库（dandanplay_mac_update）保持旧格式 vX.Y.Z
UPDATE_TAG="v${SHORT_VERSION}"

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

    # 3. Gitee Release（打 tag，DMG 不传——通常超 100MB 限制）
    GITEE_TOKEN="${GITEE_TOKEN:-}"
    if [ -n "$GITEE_TOKEN" ]; then
        UPDATE_REPO="${UPDATE_REPO_PATH:-$REPO_ROOT/../dandanplay_mac_update}"
        GITEE_REMOTE=$(cd "$UPDATE_REPO" && git remote get-url origin 2>/dev/null || echo "")
        GITEE_REPO=$(echo "$GITEE_REMOTE" | sed -E 's|.*[:/]([^/]+/[^/]+)(\.git)?$|\1|')
        GITEE_BRANCH=$(cd "$UPDATE_REPO" && git branch --show-current)

        RELEASE_BODY=$(python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip(), ensure_ascii=False))" < "$CHANGELOG_FILE")

        echo "=== 创建 Gitee Release（仅打 tag，不传 DMG）==="
        GITEE_RELEASE_RESP=$(curl -sS -X POST "https://gitee.com/api/v5/repos/${GITEE_REPO}/releases" \
            -H "Content-Type: application/json" \
            -d "{\"access_token\":\"${GITEE_TOKEN}\",\"tag_name\":\"${UPDATE_TAG}\",\"name\":\"${VERSION_TAG}\",\"body\":${RELEASE_BODY},\"target_commitish\":\"${GITEE_BRANCH}\",\"prerelease\":false}")

        GITEE_RELEASE_ID=$(echo "$GITEE_RELEASE_RESP" | python3 -c "import sys,json; print(json.load(sys.stdin).get('id', ''))")

        if [ -z "$GITEE_RELEASE_ID" ] || [ "$GITEE_RELEASE_ID" = "" ]; then
            echo "警告: 创建 Gitee Release 失败: $GITEE_RELEASE_RESP" >&2
        else
            echo "Gitee Release 创建成功, id=$GITEE_RELEASE_ID"
        fi
    else
        echo "提示: 未设置 GITEE_TOKEN，跳过 Gitee Release"
    fi

    # 4. push 主仓库（版本号 commit + tag）
    echo "=== Push 主仓库 ==="
    CURRENT_BRANCH=$(git branch --show-current)
    git push origin "$CURRENT_BRANCH"
    if git rev-parse "$VERSION_TAG" >/dev/null 2>&1; then
        echo "Tag 已存在，跳过创建"
    else
        git tag "$VERSION_TAG"
    fi
    git push origin "$VERSION_TAG" 2>/dev/null || echo "Tag 可能已存在于远端，跳过 push"

    # 5. 更新 check_version.json
    echo "=== 更新 check_version.json ==="
    UPDATE_REPO="${UPDATE_REPO_PATH:-$REPO_ROOT/../dandanplay_mac_update}"
    if [ ! -d "$UPDATE_REPO/.git" ]; then
        echo "错误: 更新仓库不存在: $UPDATE_REPO" >&2
        echo "请设置 UPDATE_REPO_PATH 环境变量或克隆到默认路径" >&2
        exit 1
    fi

    DOWNLOAD_URL="https://github.com/sunsx9316/DanDanPlay_Experience/releases/download/${VERSION_TAG}/${DMG_NAME}"
    DESC=$(cat "$CHANGELOG_FILE" | python3 -c "import sys,json; print(json.dumps(sys.stdin.read().strip(), ensure_ascii=False))")

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

    # 6. 提交 + tag + push 更新仓库
    echo "=== 推送更新仓库 ==="
    cd "$UPDATE_REPO"
    git add check_version.json
    git commit -m "[update]更新${SHORT_VERSION}版本"
    git tag "$UPDATE_TAG"
    git push origin HEAD
    git push origin "$UPDATE_TAG" 2>/dev/null || echo "更新仓库 Tag 可能已存在，跳过 push"
    cd "$REPO_ROOT"

    echo "=== 发布完成 ==="
    echo "Release: $(gh release view "$VERSION_TAG" --json url -q '.url')"
    echo ""
    echo "=== 更新日志 ==="
    cat "$CHANGELOG_FILE"

elif [ "$PLATFORM" = "ios" ] || [ "$PLATFORM" = "tvos" ]; then
    if [[ "$APP_PATH" != *.ipa ]]; then
        echo "错误: iOS/tvOS 需要 .ipa 文件，收到: $APP_PATH" >&2
        exit 1
    fi

    # App Store Connect 上传凭证（与 Mac 公证共用 Apple ID 和 App 专用密码）
    APPLE_ID="${APPLE_ID:-jimhuang099@gmail.com}"
    ASC_PROFILE="${ASC_PROFILE:-AC_PASSWORD}"

    # 检查 altool keychain 是否已配置（与 notarytool 的 keychain 不共用，需要单独创建）
    if ! xcrun altool --validate-app -f "$APP_PATH" -t "$PLATFORM" -u "$APPLE_ID" -p "@keychain:${ASC_PROFILE}" --output-format xml &>/dev/null; then
        echo "错误: altool 验证失败，请先创建 keychain 条目:" >&2
        echo "  xcrun altool --store-password-in-keychain-item '${ASC_PROFILE}' -u '${APPLE_ID}' -p @env:APP_SPECIFIC_PASSWORD" >&2
        echo "或手动设置:" >&2
        echo "  xcrun altool --store-password-in-keychain-item '${ASC_PROFILE}' -u '${APPLE_ID}'" >&2
        exit 1
    fi

    echo "=== 上传 App Store Connect ==="
    xcrun altool --upload-app -f "$APP_PATH" -t "$PLATFORM" -u "$APPLE_ID" -p "@keychain:${ASC_PROFILE}" --output-format xml

    # Tag + push 主仓库
    echo "=== Tag 主仓库 ==="
    git tag "$VERSION_TAG"
    git push origin "$VERSION_TAG"

    echo "=== 发布完成 ==="
    echo "App 已上传至 App Store Connect，请在 App Store Connect 中完成提审"
    echo ""
    echo "=== 更新日志 ==="
    cat "$CHANGELOG_FILE"
fi
