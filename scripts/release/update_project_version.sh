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
