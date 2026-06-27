#!/bin/bash
set -euo pipefail

# macOS 公证
# 用法: notarize.sh <app_path>

APP_PATH="$1"
KEYCHAIN_PROFILE="AC_PASSWORD"

if [ -z "$APP_PATH" ]; then
    echo "用法: $0 <app_path>" >&2
    exit 1
fi

if [ ! -d "$APP_PATH" ]; then
    echo "错误: 找不到 app: $APP_PATH" >&2
    exit 1
fi

# 检查 Keychain profile
echo "=== 检查公证凭证 ==="
if ! xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    echo "错误: Keychain profile '${KEYCHAIN_PROFILE}' 不存在" >&2
    echo "请先配置: xcrun notarytool store-credentials '${KEYCHAIN_PROFILE}'" >&2
    exit 1
fi
echo "凭证 OK"

# 打包为 zip（notarytool 只接受 .zip/.pkg/.dmg）
ZIP_PATH="${APP_PATH%.app}_for_notarize.zip"
echo "=== 打包 zip ==="
ditto -c -k --keepParent "$APP_PATH" "$ZIP_PATH"

# 提交公证
echo "=== 提交公证（可能需要 5-15 分钟）==="
xcrun notarytool submit "$ZIP_PATH" \
    --keychain-profile "$KEYCHAIN_PROFILE" \
    --wait

# 清理 zip
rm -f "$ZIP_PATH"

# 钉入票据
echo "=== 钉入票据 ==="
xcrun stapler staple "$APP_PATH"

echo "公证完成: $APP_PATH"
