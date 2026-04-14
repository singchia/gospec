#!/usr/bin/env bash
# build-skill.sh — 把 gospec 打包成 .skill 文件（Claude Code skill 格式）
#
# 用法：
#     scripts/build-skill.sh              # 输出到 ./dist/gospec.skill
#     scripts/build-skill.sh /path/to/out # 输出到指定目录
#
# 依赖：
#     - python3
#     - skill-creator 的 package_skill.py（在 ~/.claude/skills/skill-creator/scripts/）
#       如果没有，用 zip fallback。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR="${1:-$REPO_ROOT/dist}"
STAGING_PARENT="$(mktemp -d)"
STAGING_DIR="$STAGING_PARENT/gospec"
PACKAGER="$HOME/.claude/skills/skill-creator/scripts/package_skill.py"

cleanup() { rm -rf "$STAGING_PARENT"; }
trap cleanup EXIT

echo "📦 Staging skill files..."

mkdir -p "$STAGING_DIR"
cp "$REPO_ROOT/SKILL.md"   "$STAGING_DIR/"
cp "$REPO_ROOT/AGENTS.md"  "$STAGING_DIR/"
cp "$REPO_ROOT/LICENSE"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/spec"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/docs"    "$STAGING_DIR/"

mkdir -p "$OUT_DIR"

if [[ -f "$PACKAGER" ]]; then
    echo "🔧 Using skill-creator's package_skill.py"
    python3 "$PACKAGER" "$STAGING_DIR" "$OUT_DIR"
else
    echo "⚠️  skill-creator not installed locally, falling back to plain zip"
    (cd "$STAGING_PARENT" && zip -r -q "$OUT_DIR/gospec.skill" gospec/)
    echo "✅ Built: $OUT_DIR/gospec.skill"
fi

echo ""
echo "📊 Artifact info:"
ls -lh "$OUT_DIR/gospec.skill"
echo ""
echo "📋 Contents:"
unzip -l "$OUT_DIR/gospec.skill" | tail -20
