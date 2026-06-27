#!/bin/bash

# 检查是否提供了参数
if [ $# -lt 1 ]; then
    echo "使用方法: $0 <app路径> [dmg名称]"
    exit 1
fi

app_path="$1"
dmg_name="${2:-}"

# 切到 app 所在目录，DMG 生成在该目录下
dir_path=$(dirname "$app_path")
app_basename=$(basename "$app_path")
cd "$dir_path" || { echo "无法切换到目录 '$dir_path'"; exit 3; }

if [ -n "$dmg_name" ]; then
    output_name="$dmg_name"
else
    output_name="${app_basename%.app}.dmg"
fi

# 删除已有同名 DMG（brew 版 create-dmg 无 --overwrite）
rm -f "$output_name"

create-dmg \
    --volname "${app_basename%.app}" \
    --window-pos 200 120 \
    --window-size 480 400 \
    --icon-size 100 \
    --icon "${app_basename}" 110 190 \
    --app-drop-link 370 190 \
    "$output_name" \
    "$app_path"
