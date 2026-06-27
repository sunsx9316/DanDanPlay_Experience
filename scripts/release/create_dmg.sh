#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

if [ $# -lt 1 ]; then
    echo "使用方法: $0 <app路径> [dmg名称]"
    exit 1
fi

app_path="$1"
dmg_name="${2:-}"

app_dir=$(dirname "$app_path")
app_basename=$(basename "$app_path")
volname="${app_basename%.app}"

if [ -n "$dmg_name" ]; then
    output_name="$dmg_name"
else
    output_name="${volname}.dmg"
fi
output_path="$app_dir/$output_name"

# 删除已有同名 DMG
rm -f "$output_path"

# === 创建 staging 目录 ===
STAGING="$app_dir/dmg_staging_$$"
rm -rf "$STAGING"
mkdir "$STAGING"

# 复制 app
cp -R "$app_path" "$STAGING/"

# 创建 .webloc（弹弹Play 官网）
WEBLOC="$STAGING/弹弹Play 官网.webloc"
cat > "$WEBLOC" << 'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>URL</key>
	<string>https://www.dandanplay.com/</string>
</dict>
</plist>
PLIST

# === 创建临时 RW DMG ===
TMP_DMG="$app_dir/tmp_$$.dmg"
rm -f "$TMP_DMG"

echo "创建 DMG..."
hdiutil create -srcfolder "$STAGING" -volname "$volname" -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" -format UDRW "$TMP_DMG" -quiet

# 留余量放 Applications symlink 和 webloc
SIZE_MB=$(($(du -B 512 -s "$STAGING" | awk '{print $1}') * 512 / 1000 / 1000 + 10))
hdiutil resize -size ${SIZE_MB}m "$TMP_DMG" -quiet

# === 挂载 RW DMG ===
MOUNT_OUTPUT=$(hdiutil attach "$TMP_DMG" -readwrite -noverify -noautoopen 2>&1)
DEV_NAME=$(echo "$MOUNT_OUTPUT" | grep -E '^/dev/' | head -1 | awk '{print $1}')
MOUNT_POINT=$(echo "$MOUNT_OUTPUT" | grep -oE '/Volumes/[^ ]+' | head -1)

echo "挂载点: $MOUNT_POINT"

# === 创建 Applications 快捷方式 ===
ln -s /Applications "$MOUNT_POINT/Applications"

# === AppleScript 设置列表模式 ===
osascript - "$volname" << 'OSAEND'
on run argv
    set volName to item 1 of argv
    tell application "Finder"
        tell disk volName
            open
            set current view of container window to list view
            set toolbar visible of container window to false
            set statusbar visible of container window to false
            set bounds of container window to {200, 120, 680, 540}
            close
            open
        end tell
    end tell
end run
OSAEND

echo "Finder 设置完成"

# === 卸载 ===
echo "卸载 DMG..."
hdiutil detach "$DEV_NAME" -quiet

# === 压缩为最终 DMG ===
echo "压缩 DMG..."
rm -f "$output_path"
hdiutil convert "$TMP_DMG" -format UDZO -imagekey zlib-level=9 -o "$output_path" -quiet
rm -f "$TMP_DMG"

# === 清理 staging ===
rm -rf "$STAGING"

echo "DMG 已生成: $output_path"
