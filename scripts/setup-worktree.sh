#!/bin/bash
set -euo pipefail

# 为当前 checkout（主仓库或 worktree）建立外部工作区软链
#
# 背景：
#   - 项目根目录 /Users/kaedei/code/dandanplay 不是 git 仓库；
#   - DandanClientCore（敏感代码，约 500MB）和 sample（测试素材）留在仓库外；
#   - git worktree 只 checkout tracked 文件，ignored 的 AppKey.swift 也不会带过去。
#
# 用法：
#   bash scripts/setup-worktree.sh
#
# 会建立（均已 gitignore）：
#   vendor/DandanClientCore -> <workspace>/DandanClientCore
#   sample                  -> <workspace>/sample
#   Share/CocoaShare/Networking/AppKey.swift -> 主 checkout 的同名文件（仅 worktree）

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
COMMON_DIR="$(cd "$ROOT" && cd "$(git rev-parse --git-common-dir)" && pwd -P)"
MAIN_REPO="$(dirname "$COMMON_DIR")"
WORKSPACE="$(dirname "$MAIN_REPO")"

mkdir -p "$ROOT/vendor"

link_dir() {
  local src="$1"
  local dst="$2"

  if [ ! -d "$src" ]; then
    echo "跳过（源不存在）: $src"
    return
  fi

  if [ -L "$dst" ]; then
    ln -sfn "$src" "$dst"
  elif [ -e "$dst" ]; then
    echo "跳过（目标已存在且不是软链）: $dst"
    return
  else
    ln -s "$src" "$dst"
  fi

  echo "linked: $dst -> $src"
}

link_dir "$WORKSPACE/DandanClientCore" "$ROOT/vendor/DandanClientCore"
link_dir "$WORKSPACE/sample" "$ROOT/sample"

# AppKey.swift 被 .gitignore 忽略；worktree 里从主 checkout 软链过来。
# 主 checkout 自身已有该文件，不会覆盖。
MAIN_APPKEY="$MAIN_REPO/Share/CocoaShare/Networking/AppKey.swift"
WT_APPKEY="$ROOT/Share/CocoaShare/Networking/AppKey.swift"

if [ "$ROOT" = "$MAIN_REPO" ]; then
  [ -f "$WT_APPKEY" ] || echo "提示：主 checkout 还没有 AppKey.swift，可运行 bash scripts/build-mac.sh 生成占位文件"
elif [ -f "$MAIN_APPKEY" ] && [ ! -e "$WT_APPKEY" ]; then
  ln -s "$MAIN_APPKEY" "$WT_APPKEY"
  echo "linked: $WT_APPKEY -> $MAIN_APPKEY"
fi
