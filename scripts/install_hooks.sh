#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOK_SRC="$PROJECT_ROOT/.githooks/commit-msg"
# 使用 git rev-parse --git-path 获取真实的 hooks 路径（兼容 worktree 环境）
HOOKS_DIR="$(cd "$PROJECT_ROOT" && git rev-parse --git-path hooks 2>/dev/null)"
if [ -z "$HOOKS_DIR" ]; then
    # 回退：非 git 仓库或 git 不可用
    HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
fi
HOOK_DST="$HOOKS_DIR/commit-msg"

mkdir -p "$HOOKS_DIR"
if [ ! -L "$HOOK_DST" ] && [ ! -f "$HOOK_DST" ]; then
    ln -sf "$HOOK_SRC" "$HOOK_DST"
fi
chmod +x "$HOOK_DST"
