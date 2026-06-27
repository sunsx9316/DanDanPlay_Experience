#!/bin/bash

# 检查是否提供了参数
if [ $# -lt 1 ]; then
    echo "使用方法: $0 <app路径> [dmg名称]"
    exit 1
fi

file_path="$1"
dmg_name="${2:-}"

dir_path=$(dirname "$file_path")
cd "$dir_path" || { echo "无法切换到目录 '$dir_path'"; exit 3; }

if [ -n "$dmg_name" ]; then
    create-dmg --overwrite "$dmg_name" "$file_path"
else
    create-dmg "$file_path"
fi
