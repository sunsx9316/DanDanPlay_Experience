#!/bin/bash
set -euo pipefail

# macOS 本地编译脚本
#
# 用法:
#   bash scripts/build-mac.sh              # Debug 编译（不签名）
#   bash scripts/build-mac.sh Release      # Release 编译（不签名）
#   bash scripts/build-mac.sh Debug --resolve  # 先解析 SPM 依赖
#   bash scripts/build-mac.sh Debug --clean-spm # 清理本项目 SPM artifacts 后编译
#   DERIVED_DATA_PATH=/tmp/anix-dd-feature bash scripts/build-mac.sh Debug
#
# 说明:
#   - 默认 CODE_SIGNING_ALLOWED=NO，仅验证编译；
#   - 要运行 App/登录/网络，请用 Xcode 打开工程并配置签名；
#   - AppKey.swift 缺失时会从 .example 复制一份占位文件（不会覆盖已有文件）；
#   - 并行 worktree 建议设置 DERIVED_DATA_PATH，避免 xcodebuild 抢锁。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/Mac/AniXPlayer.xcodeproj"
APPKEY="$ROOT/Share/CocoaShare/Networking/AppKey.swift"
APPKEY_EXAMPLE="$ROOT/Share/CocoaShare/Networking/AppKey.swift.example"

CONFIG="${1:-Debug}"
shift || true

RESOLVE=0
CLEAN_SPM=0
for arg in "$@"; do
  case "$arg" in
    --resolve) RESOLVE=1 ;;
    --clean-spm) CLEAN_SPM=1 ;;
    *) echo "未知参数: $arg"; exit 1 ;;
  esac
done

DERIVED_ARGS=()
if [ -n "${DERIVED_DATA_PATH:-}" ]; then
  DERIVED_ARGS+=("-derivedDataPath" "$DERIVED_DATA_PATH")
fi

if [ ! -f "$APPKEY" ]; then
  if [ -f "$APPKEY_EXAMPLE" ]; then
    cp "$APPKEY_EXAMPLE" "$APPKEY"
    echo "警告: 已从 AppKey.swift.example 创建占位文件，请填入真实 AppId/AppSecret 后再联调 API。"
  else
    echo "错误: 缺少 $APPKEY，且找不到 .example 模板。"
    exit 1
  fi
fi

if [ "$CLEAN_SPM" = "1" ]; then
  echo "清理本项目 SPM artifacts..."
  rm -rf "$HOME/Library/Developer/Xcode/DerivedData/AniXPlayer-"*/SourcePackages/artifacts
fi

if [ "$RESOLVE" = "1" ]; then
  echo "解析 SPM 依赖..."
  xcodebuild -project "$PROJECT" -scheme AniXPlayer -resolvePackageDependencies
fi

echo "编译 macOS ($CONFIG)..."
xcodebuild \
  -project "$PROJECT" \
  -scheme AniXPlayer \
  -configuration "$CONFIG" \
  -destination 'platform=macOS' \
  "${DERIVED_ARGS[@]}" \
  CODE_SIGNING_ALLOWED=NO \
  build
