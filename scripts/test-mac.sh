#!/bin/bash
set -euo pipefail

# macOS 单元测试（无宿主，不启动 App）
#
# 用法:
#   bash scripts/test-mac.sh              # Debug
#   bash scripts/test-mac.sh Release      # Release
#   bash scripts/test-mac.sh Debug --only AniXPlayerTests/OAuthPKCETests
#   DERIVED_DATA_PATH=/tmp/anix-dd-feature bash scripts/test-mac.sh
#
# 说明:
#   - 测试 target 为 AniXPlayerTests，源文件在 Mac/AniXPlayerTests/；
#   - 被测的 OAuth/网络/会话源码直接编进测试 target（无 TEST_HOST），
#     因此不需要签名，也不会启动 App/登录窗口；
#   - 新增被测源码时，要同时加入 AniXPlayerTests 的 Sources；
#     可用 `ruby scripts/xcode_test_source.rb Mac/AniXPlayerTests/FooTests.swift`。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Debug}"
shift || true

ONLY_ARGS=()
while [ "$#" -gt 0 ]; do
  case "$1" in
    --only)
      shift
      ONLY_ARGS+=("-only-testing:$1")
      shift
      ;;
    *)
      echo "未知参数: $1"
      exit 1
      ;;
  esac
done

DERIVED_ARGS=()
if [ -n "${DERIVED_DATA_PATH:-}" ]; then
  DERIVED_ARGS+=("-derivedDataPath" "$DERIVED_DATA_PATH")
fi

echo "运行 macOS 单元测试 ($CONFIG)..."
if [ ${#ONLY_ARGS[@]} -gt 0 ] && [ ${#DERIVED_ARGS[@]} -gt 0 ]; then
  xcodebuild test \
    -project "$ROOT/Mac/AniXPlayer.xcodeproj" \
    -scheme AniXPlayerTests \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    "${DERIVED_ARGS[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    "${ONLY_ARGS[@]}"
elif [ ${#ONLY_ARGS[@]} -gt 0 ]; then
  xcodebuild test \
    -project "$ROOT/Mac/AniXPlayer.xcodeproj" \
    -scheme AniXPlayerTests \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO \
    "${ONLY_ARGS[@]}"
elif [ ${#DERIVED_ARGS[@]} -gt 0 ]; then
  xcodebuild test \
    -project "$ROOT/Mac/AniXPlayer.xcodeproj" \
    -scheme AniXPlayerTests \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    "${DERIVED_ARGS[@]}" \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
else
  xcodebuild test \
    -project "$ROOT/Mac/AniXPlayer.xcodeproj" \
    -scheme AniXPlayerTests \
    -configuration "$CONFIG" \
    -destination 'platform=macOS' \
    CODE_SIGNING_ALLOWED=NO \
    CODE_SIGNING_REQUIRED=NO
fi
