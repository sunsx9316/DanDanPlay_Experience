#!/bin/bash
set -euo pipefail

# 计算下一个版本号
# 用法: calc_version.sh <mac|ios|tvos> [--testflight]
#
# App Store 模式（默认）: 从该平台最新 git tag 计算新 SHORT_VERSION + BUILD
# TestFlight 模式: 保持当前 SHORT_VERSION 不变，只计算新 BUILD

MODE="appstore"
PLATFORM=""

# 解析参数: calc_version.sh <platform> [--testflight]
if [ "$#" -ge 1 ]; then
    PLATFORM="$1"
    shift
fi
if [ "$#" -ge 1 ] && [ "$1" = "--testflight" ]; then
    MODE="testflight"
fi

case "$PLATFORM" in
    mac)  PLATFORM_DIR="Mac" ;;
    ios)  PLATFORM_DIR="iOS" ;;
    tvos) PLATFORM_DIR="tvOS" ;;
    *)
        echo "错误: 需要指定平台 mac/ios/tvos" >&2
        echo "用法: $0 <mac|ios|tvos> [--testflight]" >&2
        exit 1
        ;;
esac

TODAY=$(date +%Y%m%d)
CURRENT_MONTH=$(date +%-m)
REPO_ROOT="$(cd "$(dirname "$0")/../.." && pwd)"
PBXPROJ="$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcodeproj/project.pbxproj"

if [ "$MODE" = "testflight" ]; then
    # TestFlight: 读取当前版本号，只算新 build
    CURRENT_SHORT=$(grep -m1 "MARKETING_VERSION" "$PBXPROJ" | sed 's/.*= //;s/;//')
    CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" "$PBXPROJ" | sed 's/.*= //;s/;//')

    if [[ "$CURRENT_BUILD" == "$TODAY"* ]]; then
        TODAY_SEQ=$((10#${CURRENT_BUILD:8:2} + 1))
    else
        TODAY_SEQ=1
    fi
    NEW_BUILD=$(printf "%s%02d" "$TODAY" "$TODAY_SEQ")

    echo "NEW_SHORT_VERSION=$CURRENT_SHORT"
    echo "NEW_BUILD=$NEW_BUILD"
    echo "MODE=testflight"
    exit 0
fi

# App Store 模式: 从该平台最新 git tag 计算
LAST_TAG=$(git tag --sort=-creatordate | grep "^${PLATFORM}-v" | head -1)
if [ -z "$LAST_TAG" ]; then
    echo "错误: 未找到 ${PLATFORM} 的版本 tag，请先手动创建一个（如 ${PLATFORM}-v1.0.0-$(date +%Y%m%d)01）" >&2
    exit 1
fi

# 解析 <platform>-vX.Y.Z-BUILD 格式
TAG_VERSION="${LAST_TAG#${PLATFORM}-v}"  # X.Y.Z-BUILD
LAST_SHORT="${TAG_VERSION%-*}"            # X.Y.Z
IFS='.' read -r MAJOR LAST_MONTH LAST_MINOR <<< "$LAST_SHORT"
LAST_MINOR="${LAST_MINOR:-0}"

if [ "$CURRENT_MONTH" -ne "$LAST_MONTH" ]; then
    NEW_MINOR=0
else
    NEW_MINOR=$((LAST_MINOR + 1))
fi
NEW_SHORT_VERSION="${MAJOR}.${CURRENT_MONTH}.${NEW_MINOR}"

# 检查当前 pbxproj 中的 build 号
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" "$PLATFORM_DIR/AniXPlayer.xcodeproj/project.pbxproj" | sed 's/.*= //;s/;//')
if [[ "$CURRENT_BUILD" == "$TODAY"* ]]; then
    TODAY_SEQ=$((10#${CURRENT_BUILD:8:2} + 1))
else
    TODAY_SEQ=1
fi
NEW_BUILD=$(printf "%s%02d" "$TODAY" "$TODAY_SEQ")

echo "NEW_SHORT_VERSION=$NEW_SHORT_VERSION"
echo "NEW_BUILD=$NEW_BUILD"
echo "MODE=appstore"
