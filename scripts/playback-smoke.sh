#!/bin/bash
set -euo pipefail

# macOS L2 播放冒烟测试
#
# 用法:
#   bash scripts/playback-smoke.sh                    # 默认 Debug + sample/ASS测试.mp4
#   bash scripts/playback-smoke.sh --no-build         # 跳过编译
#   bash scripts/playback-smoke.sh --video /path/a.mp4 --play-seconds 5
#   bash scripts/playback-smoke.sh --require-danmaku  # 同时要求弹幕数 > 0
#
# 退出码:
#   0  播放成功且断言通过
#   1  构建/启动/断言失败

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="Debug"
VIDEO="$ROOT/sample/ASS测试.mp4"
PLAY_SECONDS="3"
DO_BUILD=1
REQUIRE_DANMAKU=0

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-build)
      DO_BUILD=0
      shift
      ;;
    --video)
      VIDEO="$2"
      shift 2
      ;;
    --play-seconds)
      PLAY_SECONDS="$2"
      shift 2
      ;;
    --require-danmaku)
      REQUIRE_DANMAKU=1
      shift
      ;;
    --config)
      CONFIG="$2"
      shift 2
      ;;
    *)
      echo "未知参数: $1" >&2
      exit 1
      ;;
  esac
done

if [ ! -f "$VIDEO" ]; then
  echo "错误: 视频不存在: $VIDEO" >&2
  exit 1
fi

if [ "$DO_BUILD" = "1" ]; then
  echo "编译 macOS ($CONFIG)..."
  bash "$ROOT/scripts/build-mac.sh" "$CONFIG" >/dev/null
fi

BUILT_PRODUCTS_DIR="$(xcodebuild \
  -project "$ROOT/Mac/AniXPlayer.xcodeproj" \
  -scheme AniXPlayer \
  -configuration "$CONFIG" \
  -showBuildSettings 2>/dev/null \
  | awk -F ' = ' '/[[:space:]]BUILT_PRODUCTS_DIR = /{print $2; exit}')"

if [ -z "${BUILT_PRODUCTS_DIR:-}" ]; then
  echo "错误: 无法解析 BUILT_PRODUCTS_DIR" >&2
  exit 1
fi

APP="$BUILT_PRODUCTS_DIR/AniXPlayer.app"
BIN="$APP/Contents/MacOS/AniXPlayer"
if [ ! -x "$BIN" ]; then
  echo "错误: App 不存在或不可执行: $BIN" >&2
  exit 1
fi

STATE_FILE="$(mktemp -t anix-playback-state)"
LOG_FILE="$(mktemp -t anix-playback-log)"
cleanup() {
  rm -f "$STATE_FILE" "$LOG_FILE"
}
trap cleanup EXIT

echo "运行播放冒烟: $(basename "$VIDEO") / ${PLAY_SECONDS}s"
set +e
"$BIN" \
  --open "$VIDEO" \
  --play-seconds "$PLAY_SECONDS" \
  --dump-state \
  --state-file "$STATE_FILE" \
  --exit >"$LOG_FILE" 2>&1
APP_EXIT=$?
set -e

if [ ! -s "$STATE_FILE" ]; then
  echo "错误: 没有生成状态文件（app exit=$APP_EXIT）" >&2
  echo "--- 日志 ---" >&2
  tail -40 "$LOG_FILE" >&2
  exit 1
fi

cat "$STATE_FILE"
echo

python3 - "$STATE_FILE" "$PLAY_SECONDS" "$(basename "$VIDEO")" "$REQUIRE_DANMAKU" <<'PY'
import json
import sys

state_path, play_seconds_raw, expected_file, require_danmaku = sys.argv[1:5]
play_seconds = float(play_seconds_raw)
require_danmaku = require_danmaku == "1"

with open(state_path, encoding="utf-8") as f:
    state = json.load(f)

errors = []
if not state.get("success"):
    errors.append(f"success=false: {state.get('error')}")
if not state.get("playerReady"):
    errors.append("playerReady=false")
if state.get("file") != expected_file:
    errors.append(f"file={state.get('file')!r}, 期望 {expected_file!r}")
if (state.get("duration") or 0) <= 0:
    errors.append(f"duration={state.get('duration')}")
position = state.get("position") or 0
minimum = max(1.0, play_seconds * 0.5)
if position < minimum:
    errors.append(f"position={position:.3f}, 期望至少 {minimum:.3f}")
if not state.get("isPlaying") and position < (state.get("duration") or 0) - 1:
    errors.append("isPlaying=false，但视频尚未结束")

danmaku_count = state.get("danmakuCount") or 0
if require_danmaku and danmaku_count <= 0:
    errors.append("danmakuCount=0（--require-danmaku）")
elif danmaku_count <= 0:
    print("警告: danmakuCount=0；如需强制校验请加 --require-danmaku", file=sys.stderr)

if errors:
    print("FAIL", file=sys.stderr)
    for error in errors:
        print(" - " + error, file=sys.stderr)
    sys.exit(1)

print(
    "PASS: opened={}, position={:.2f}s/{:.2f}s, danmaku={}".format(
        state.get("title"), position, state.get("duration") or 0, danmaku_count
    )
)
PY
