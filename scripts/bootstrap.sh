#!/bin/bash
set -euo pipefail

# 首次 clone 后的环境初始化脚本
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# 安装 Git hooks
"$SCRIPT_DIR/install_hooks.sh"

echo "Bootstrap 完成 ✓"
