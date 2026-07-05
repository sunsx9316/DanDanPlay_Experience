#!/bin/bash
set -euo pipefail

# macOS 公证（支持 .app 和 .dmg）
# 用法: notarize.sh <app_or_dmg_path>

INPUT_PATH="$1"
KEYCHAIN_PROFILE="AC_PASSWORD"

if [ -z "$INPUT_PATH" ]; then
    echo "用法: $0 <app_or_dmg_path>" >&2
    exit 1
fi

# 检查认证方式：优先 keychain profile，其次环境变量
echo "=== 检查公证凭证 ==="
AUTH_ARGS=""
if xcrun notarytool history --keychain-profile "$KEYCHAIN_PROFILE" &>/dev/null; then
    AUTH_ARGS="--keychain-profile $KEYCHAIN_PROFILE"
    echo "使用 Keychain profile '${KEYCHAIN_PROFILE}'"
elif [ -n "${APPLE_ID:-}" ] && [ -n "${APP_SPECIFIC_PASSWORD:-}" ]; then
    APPLE_TEAM_ID="${APPLE_TEAM_ID:-94L7P6P9PY}"
    AUTH_ARGS="--apple-id $APPLE_ID --team-id $APPLE_TEAM_ID --password @env:APP_SPECIFIC_PASSWORD"
    echo "使用环境变量 APPLE_ID / APP_SPECIFIC_PASSWORD"
else
    echo "错误: Keychain profile '${KEYCHAIN_PROFILE}' 不存在，且环境变量未设置" >&2
    echo "请选择其一配置:" >&2
    echo "  方式1: xcrun notarytool store-credentials '${KEYCHAIN_PROFILE}'" >&2
    echo "  方式2: export APPLE_ID=xxx APP_SPECIFIC_PASSWORD=xxx APPLE_TEAM_ID=xxx" >&2
    exit 1
fi
echo "凭证 OK"

# 确定输入类型
if [ -d "$INPUT_PATH" ] && [[ "$INPUT_PATH" == *.app ]]; then
    # .app: 打包为 zip 再提交
    ZIP_PATH="${INPUT_PATH%.app}_for_notarize.zip"
    echo "=== 打包 zip ==="
    ditto -c -k --keepParent "$INPUT_PATH" "$ZIP_PATH"
    SUBMIT_PATH="$ZIP_PATH"
    IS_DMG=false
elif [[ "$INPUT_PATH" == *.dmg ]]; then
    # .dmg: 直接提交
    SUBMIT_PATH="$INPUT_PATH"
    IS_DMG=true
else
    echo "错误: 不支持的文件类型: $INPUT_PATH" >&2
    exit 1
fi

# 提交公证
echo "=== 提交公证（可能需要 5-15 分钟）==="
xcrun notarytool submit "$SUBMIT_PATH" \
    $AUTH_ARGS \
    --wait

# 清理临时 zip
if [ "$IS_DMG" = false ]; then
    rm -f "$ZIP_PATH"
fi

# 钉入票据
echo "=== 钉入票据 ==="
xcrun stapler staple "$INPUT_PATH"

echo "公证完成: $INPUT_PATH"
