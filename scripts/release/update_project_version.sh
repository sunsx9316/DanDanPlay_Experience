#!/bin/bash
set -euo pipefail

# 更新 Xcode 工程版本号（直接改 pbxproj，不动 Info.plist）
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
PBXPROJ="$REPO_ROOT/$PLATFORM_DIR/AniXPlayer.xcodeproj/project.pbxproj"

# 更新 MARKETING_VERSION
echo "更新 MARKETING_VERSION → $SHORT_VERSION"
sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $SHORT_VERSION;/g" "$PBXPROJ"

# 更新 CURRENT_PROJECT_VERSION
echo "更新 CURRENT_PROJECT_VERSION → $BUILD"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBXPROJ"

echo ""
echo "版本号更新完成: $SHORT_VERSION ($BUILD)"
echo "Info.plist 使用 \$(MARKETING_VERSION) / \$(CURRENT_PROJECT_VERSION) 构建变量，无需修改。"
