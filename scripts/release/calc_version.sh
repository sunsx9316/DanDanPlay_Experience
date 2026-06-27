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
LAST_MINOR="${LAST_MINOR:-0}"

CURRENT_MONTH=$(date +%-m)
TODAY=$(date +%Y%m%d)

# 计算 shortVersion
if [ "$CURRENT_MONTH" -ne "$LAST_MONTH" ]; then
    NEW_MINOR=0
else
    NEW_MINOR=$((LAST_MINOR + 1))
fi
NEW_SHORT_VERSION="${MAJOR}.${CURRENT_MONTH}.${NEW_MINOR}"

# 检查当前 pbxproj 中的 build 号是否以今天日期开头，决定 XX
CURRENT_BUILD=$(grep -m1 "CURRENT_PROJECT_VERSION" Mac/AniXPlayer.xcodeproj/project.pbxproj | sed 's/.*= //;s/;//')
if [[ "$CURRENT_BUILD" == "$TODAY"* ]]; then
    TODAY_SEQ=$((10#${CURRENT_BUILD:8:2} + 1))
else
    TODAY_SEQ=1
fi
NEW_BUILD=$(printf "%s%02d" "$TODAY" "$TODAY_SEQ")

echo "NEW_SHORT_VERSION=$NEW_SHORT_VERSION"
echo "NEW_BUILD=$NEW_BUILD"
