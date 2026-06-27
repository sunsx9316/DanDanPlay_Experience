#!/bin/bash
set -euo pipefail

# 更新 Xcode 工程版本号（直接改 pbxproj，不动 Info.plist）
# 用法:
#   update_project_version.sh <platform> <short_version> <build>            # App Store 模式
#   update_project_version.sh <platform> --testflight <build>               # TestFlight 模式（只改 build）

if [ "$2" = "--testflight" ]; then
    # TestFlight 模式: 只更新 build
    PLATFORM="$1"
    BUILD="$3"
    TESTFLIGHT=true
else
    # App Store 模式: 更新版本号和 build
    PLATFORM="$1"
    SHORT_VERSION="$2"
    BUILD="$3"
    TESTFLIGHT=false
fi

if [ -z "$PLATFORM" ] || [ -z "$BUILD" ]; then
    echo "用法: $0 <mac|ios|tvos> <shortVersion|--testflight> <build>" >&2
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

if [ "$TESTFLIGHT" = true ]; then
    echo "TestFlight 模式: 只更新 build"
else
    echo "更新 MARKETING_VERSION → $SHORT_VERSION"
    sed -i '' "s/MARKETING_VERSION = [0-9.]*;/MARKETING_VERSION = $SHORT_VERSION;/g" "$PBXPROJ"
fi

echo "更新 CURRENT_PROJECT_VERSION → $BUILD"
sed -i '' "s/CURRENT_PROJECT_VERSION = [0-9]*;/CURRENT_PROJECT_VERSION = $BUILD;/g" "$PBXPROJ"

echo ""
if [ "$TESTFLIGHT" = true ]; then
    echo "Build 号更新完成: $BUILD"
else
    echo "版本号更新完成: $SHORT_VERSION ($BUILD)"
fi
echo "Info.plist 使用 \$(MARKETING_VERSION) / \$(CURRENT_PROJECT_VERSION) 构建变量，无需修改。"
