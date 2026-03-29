#!/bin/bash

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

HOOKS_DIR="$PROJECT_ROOT/.git/hooks"
HOOK_SRC="$PROJECT_ROOT/.githooks/commit-msg"
HOOK_DST="$HOOKS_DIR/commit-msg"

mkdir -p "$HOOKS_DIR"
if [ ! -L "$HOOK_DST" ] && [ ! -f "$HOOK_DST" ]; then
    ln -sf "$HOOK_SRC" "$HOOK_DST"
fi
chmod +x "$HOOK_DST"
