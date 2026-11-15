#!/bin/bash
set -uo pipefail

# 三平台回归编译脚本
#
# 用法:
#   bash scripts/build-all-platforms.sh            # Debug，全部平台
#   bash scripts/build-all-platforms.sh Release    # Release
#   bash scripts/build-all-platforms.sh Debug ios  # 只编某个平台（mac|ios|tvos）
#
# 说明:
#   - 用 CODE_SIGNING_ALLOWED=NO，只验证编译，不做签名；
#   - 改动 Share/ 下共享代码后必须跑一次，确认 iOS/tvOS 没被改坏；
#   - 每个平台日志写到 /tmp/anix-build-<platform>.log。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="${1:-Debug}"
ONLY="${2:-}"

LOG_DIR="${TMPDIR:-/tmp}/anix-build"
mkdir -p "$LOG_DIR"

declare -a PLATFORMS=()
case "$ONLY" in
  "") PLATFORMS=(mac ios tvos) ;;
  mac|ios|tvos) PLATFORMS=("$ONLY") ;;
  *) echo "未知平台: $ONLY（可选 mac|ios|tvos）"; exit 1 ;;
esac

failures=()

for platform in "${PLATFORMS[@]}"; do
  case "$platform" in
    mac)
      project="$ROOT/Mac/AniXPlayer.xcodeproj"
      destination="platform=macOS"
      ;;
    ios)
      project="$ROOT/iOS/AniXPlayer.xcodeproj"
      destination="generic/platform=iOS"
      ;;
    tvos)
      project="$ROOT/tvOS/AniXPlayer.xcodeproj"
      destination="generic/platform=tvOS"
      ;;
  esac

  log="$LOG_DIR/$platform.log"
  echo "=== 编译 $platform ($CONFIG) ==="
  if xcodebuild \
      -project "$project" \
      -scheme AniXPlayer \
      -configuration "$CONFIG" \
      -destination "$destination" \
      CODE_SIGNING_ALLOWED=NO \
      build > "$log" 2>&1; then
    echo "  ✅ $platform: BUILD SUCCEEDED ($log)"
  else
    echo "  ❌ $platform: BUILD FAILED ($log)"
    grep -n "error:" "$log" | head -20
    failures+=("$platform")
  fi
done

echo
if [ ${#failures[@]} -eq 0 ]; then
  echo "全部通过 ✅"
  exit 0
else
  echo "失败平台: ${failures[*]} ❌"
  exit 1
fi
