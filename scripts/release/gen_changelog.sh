#!/bin/bash
set -euo pipefail

# 从上次 tag 到 HEAD 生成更新日志
# 用法: gen_changelog.sh <last_tag> [output_file]
# 默认输出到 /tmp/release_changelog.txt

LAST_TAG="${1:-}"
OUTPUT_FILE="${2:-/tmp/release_changelog.txt}"

if [ -z "$LAST_TAG" ]; then
    echo "用法: $0 <last_tag> [output_file]" >&2
    echo "示例: $0 v1.6.2" >&2
    exit 1
fi

echo "生成更新日志: $LAST_TAG..HEAD"

# 生成日志
git log "${LAST_TAG}..HEAD" --pretty=format:"- %s" --no-merges > "$OUTPUT_FILE"

if [ ! -s "$OUTPUT_FILE" ]; then
    echo "警告: $LAST_TAG..HEAD 之间没有新的 commit" >&2
    echo "(空)" > "$OUTPUT_FILE"
fi

echo "更新日志已写入: $OUTPUT_FILE"
cat "$OUTPUT_FILE"
