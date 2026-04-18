#!/usr/bin/env bash
# uninstall.sh — 移除 gospec skill 和当前项目里的 gospec 落盘文件
#
# 用法（在 Go 项目根目录运行）：
#     bash <(curl -sSL https://raw.githubusercontent.com/singchia/gospec/main/scripts/uninstall.sh)
#
# 或本地：
#     ~/.claude/skills/gospec/scripts/uninstall.sh
#
# 默认移除：
#   - 当前目录的 ./AGENTS.md（先备份）
#   - 当前目录的 ./.cursor/rules/gospec.mdc
# 不会自动删 ~/.claude/skills/gospec/，需要加 KEEP_SKILL=0 才会删
#
# 环境变量：
#   KEEP_SKILL=0     一并删 ~/.claude/skills/gospec/（默认保留）
#   SKILL_DIR=...    自定义 skill 目录（默认 ~/.claude/skills/gospec）

set -euo pipefail

SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/gospec}"
KEEP_SKILL="${KEEP_SKILL:-1}"
TARGET_AGENTS="./AGENTS.md"
TARGET_CURSOR="./.cursor/rules/gospec.mdc"

echo "🧹 gospec 卸载"
echo ""

# ────────────────────────────────────────────────────────
# Step 1: 项目根 AGENTS.md
# ────────────────────────────────────────────────────────
if [[ -f "${TARGET_AGENTS}" ]]; then
    if grep -q "gospec" "${TARGET_AGENTS}" 2>/dev/null; then
        BACKUP="${TARGET_AGENTS}.bak.$(date +%Y%m%d%H%M%S)"
        cp "${TARGET_AGENTS}" "${BACKUP}"
        rm "${TARGET_AGENTS}"
        echo "✓ 已删除 ${TARGET_AGENTS}（备份为 ${BACKUP}）"
    else
        echo "⏭  ${TARGET_AGENTS} 不像是 gospec 生成的（不含 'gospec' 字样），保留不动"
    fi
else
    echo "⏭  ${TARGET_AGENTS} 不存在，跳过"
fi

# ────────────────────────────────────────────────────────
# Step 2: Cursor 规则
# ────────────────────────────────────────────────────────
if [[ -f "${TARGET_CURSOR}" ]]; then
    rm "${TARGET_CURSOR}"
    echo "✓ 已删除 ${TARGET_CURSOR}"
    # 如 .cursor/rules/ 已空，连带删
    if [[ -d "./.cursor/rules" ]] && [[ -z "$(ls -A ./.cursor/rules)" ]]; then
        rmdir ./.cursor/rules
        if [[ -d "./.cursor" ]] && [[ -z "$(ls -A ./.cursor)" ]]; then
            rmdir ./.cursor
        fi
    fi
else
    echo "⏭  ${TARGET_CURSOR} 不存在，跳过"
fi

# ────────────────────────────────────────────────────────
# Step 3: 全局 skill 目录
# ────────────────────────────────────────────────────────
if [[ "${KEEP_SKILL}" == "0" ]]; then
    if [[ -d "${SKILL_DIR}" ]]; then
        rm -rf "${SKILL_DIR}"
        echo "✓ 已删除 ${SKILL_DIR}"
    else
        echo "⏭  ${SKILL_DIR} 不存在，跳过"
    fi
else
    if [[ -d "${SKILL_DIR}" ]]; then
        echo "ℹ  保留 ${SKILL_DIR}（其他项目可能仍在用）"
        echo "   如要一并删除：KEEP_SKILL=0 bash $0"
    fi
fi

echo ""
echo "✅ 卸载完成"
