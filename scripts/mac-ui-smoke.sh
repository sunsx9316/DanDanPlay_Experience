#!/bin/bash
set -euo pipefail

# macOS L3 UI 冒烟（AX，不用 XCUITest）
#
# 用法:
#   bash scripts/mac-ui-smoke.sh             # 先编译
#   bash scripts/mac-ui-smoke.sh --no-build
#
# 覆盖:
#   1. 启动页可达性（launch.openButton）
#   2. 打开视频后播放器控件可达性（player.playPauseButton / player.timeLabel）
#
# 前置：OpenChamber/终端已获「辅助功能」权限；屏幕录制只用于额外截图，不强制。

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="Debug"
DO_BUILD=1
VIDEO="$ROOT/sample/ASS测试.mp4"

while [ "$#" -gt 0 ]; do
  case "$1" in
    --no-build) DO_BUILD=0; shift ;;
    --video) VIDEO="$2"; shift 2 ;;
    --config) CONFIG="$2"; shift 2 ;;
    *) echo "未知参数: $1" >&2; exit 1 ;;
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
BIN="$BUILT_PRODUCTS_DIR/AniXPlayer.app/Contents/MacOS/AniXPlayer"
if [ ! -x "$BIN" ]; then
  echo "错误: App 不存在或不可执行: $BIN" >&2
  exit 1
fi

FINDER_BIN="$(mktemp -t anix-find-element)"
LOG_FILE="$(mktemp -t anix-ui-smoke-log)"
cleanup() {
  rm -f "$FINDER_BIN" "$LOG_FILE"
  if [ -n "${APP_PID:-}" ]; then
    kill "$APP_PID" 2>/dev/null || true
    wait "$APP_PID" 2>/dev/null || true
  fi
}
trap cleanup EXIT

swiftc -O "$ROOT/scripts/mac-ui/find-element.swift" -o "$FINDER_BIN" >/dev/null

wait_for_element() {
  local needle="$1"
  local attempts="${2:-60}"
  for _ in $(seq 1 "$attempts"); do
    if "$FINDER_BIN" "$APP_PID" "$needle" 12 >>"$LOG_FILE" 2>&1; then
      return 0
    fi
    sleep 0.25
  done
  echo "未找到 AX 元素: $needle" >&2
  tail -30 "$LOG_FILE" >&2
  return 1
}

echo "1/2 启动页 AX 冒烟..."
# 不要传 --state-file：AppKit 会把命令行里的路径当成待打开文件。
"$BIN" --dump-state >/dev/null 2>&1 &
APP_PID=$!
wait_for_element "launch.openButton" 80
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
unset APP_PID
echo "  ✅ launch.openButton"

echo "2/2 播放器 AX 冒烟..."
"$BIN" --open "$VIDEO" --play-seconds 30 >/dev/null 2>&1 &
APP_PID=$!
wait_for_element "player.playPauseButton" 160
wait_for_element "player.timeLabel" 80
echo "  ✅ player.playPauseButton / player.timeLabel"
kill "$APP_PID" 2>/dev/null || true
wait "$APP_PID" 2>/dev/null || true
unset APP_PID

echo "PASS: macOS UI 冒烟通过"
