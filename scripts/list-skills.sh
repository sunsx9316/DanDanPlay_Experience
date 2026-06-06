#!/bin/bash
# 扫描 .claude/skills/ 下的所有 .skill.md 文件，输出 name 和 description
# 用于 SessionStart hook，自动发现项目 skill

SKILL_DIR="$(cd "$(dirname "$0")/.." && pwd)/.claude/skills"

if [ ! -d "$SKILL_DIR" ]; then
    exit 0
fi

echo ""
echo "== 项目 Skills (位于 .claude/skills/) =="
echo "可使用 Skill 工具调用："

for f in "$SKILL_DIR"/*.skill.md; do
    [ -f "$f" ] || continue
    name=$(sed -n 's/^name: *//p' "$f")
    desc=$(sed -n 's/^description: *//p' "$f")
    [ -n "$name" ] && echo "  $name — $desc"
done

echo ""
