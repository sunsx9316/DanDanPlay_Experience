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
