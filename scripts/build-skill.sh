#!/usr/bin/env bash
# build-skill.sh — 把 gospec 打包成 .skill 文件（agent skills 通用 zip 格式）
#
# 用法：
#     scripts/build-skill.sh              # 输出到 ./dist/gospec.skill
#     scripts/build-skill.sh /path/to/out # 输出到指定目录
#
# 依赖：bash + python3 + pyyaml + zip
# 不依赖任何外部 skill 工具，本地和 CI 都能跑。

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT_DIR_RAW="${1:-$REPO_ROOT/dist}"
# 把 OUT_DIR 解析为绝对路径，避免脚本内 cd 后相对路径失效
mkdir -p "$OUT_DIR_RAW"
OUT_DIR="$(cd "$OUT_DIR_RAW" && pwd)"
STAGING_PARENT="$(mktemp -d)"
STAGING_DIR="$STAGING_PARENT/gospec"

cleanup() { rm -rf "$STAGING_PARENT"; }
trap cleanup EXIT

echo "🔍 Validating SKILL.md..."
python3 "$REPO_ROOT/scripts/validate-skill.py" "$REPO_ROOT"
echo ""

echo "📦 Staging skill files..."
mkdir -p "$STAGING_DIR" "$STAGING_DIR/scripts"
cp "$REPO_ROOT/SKILL.md"   "$STAGING_DIR/"
cp "$REPO_ROOT/AGENTS.md"  "$STAGING_DIR/"
cp "$REPO_ROOT/LICENSE"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/spec"    "$STAGING_DIR/"
cp -r "$REPO_ROOT/docs"    "$STAGING_DIR/"
# 仅打包 install.sh（用户需要），不打包 build-skill.sh / validate-skill.py（仅维护者用）
cp "$REPO_ROOT/scripts/install.sh" "$STAGING_DIR/scripts/"
chmod +x "$STAGING_DIR/scripts/install.sh"
echo ""

echo "🗜  Packaging..."
(cd "$STAGING_PARENT" && zip -r -q "$OUT_DIR/gospec.skill" gospec/)

echo ""
echo "✅ Built: $OUT_DIR/gospec.skill"
ls -lh "$OUT_DIR/gospec.skill"
echo ""
echo "📋 Contents (last 10):"
unzip -l "$OUT_DIR/gospec.skill" | tail -10
