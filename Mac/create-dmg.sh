#!/bin/bash

# 检查是否提供了参数
if [ $# -lt 1 ]; then
    echo "使用方法: $0 <文件路径>"
    exit 1
fi

# 获取第一个参数（文件路径）
file_path="$1"

# 获取文件的目录
dir_path=$(dirname "$file_path")

# 切换到文件的目录
cd "$dir_path" || { echo "无法切换到目录 '$dir_path'"; exit 3; }

create-dmg $1