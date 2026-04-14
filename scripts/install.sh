#!/usr/bin/env bash
# install.sh — 在你的 Go 项目根目录运行，一行命令安装并激活 gospec
#
# 它做两件事：
#   1. 安装 gospec skill 到 ~/.claude/skills/gospec/（如果还没装）
#   2. 在当前目录创建 AGENTS.md，让任何 AI agent 打开本项目都能识别 gospec
#
# 用法（远程，一行命令）：
#     cd your-go-project
#     bash <(curl -sSL https://raw.githubusercontent.com/singchia/gospec/main/scripts/install.sh)
#
# 用法（本地，已 clone 仓库）：
#     cd your-go-project
#     ~/.claude/skills/gospec/scripts/install.sh
#
# 项目级安装（仅对当前项目生效）：
#     SKILL_DIR=.claude/skills/gospec bash <(curl -sSL .../install.sh)

set -euo pipefail

REPO_URL="https://github.com/singchia/gospec.git"
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/gospec}"
TEMPLATE_REL="docs/templates/project-agents-template.md"
TARGET="./AGENTS.md"

echo "📦 gospec 安装"
echo ""

# ────────────────────────────────────────────────────────
# Step 1: 确保 skill 已安装
# ────────────────────────────────────────────────────────
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
    echo "✓ gospec skill 已安装在 $SKILL_DIR"
else
    if ! command -v git >/dev/null 2>&1; then
        echo "❌ git 未安装，无法继续"
        exit 1
    fi
    echo "⬇  gospec skill 未安装，clone 到 $SKILL_DIR..."
    mkdir -p "$(dirname "$SKILL_DIR")"
    git clone --depth 1 "$REPO_URL" "$SKILL_DIR"
    echo ""
fi

# ────────────────────────────────────────────────────────
# Step 2: 校验模板存在
# ────────────────────────────────────────────────────────
TEMPLATE_FULL="$SKILL_DIR/$TEMPLATE_REL"
if [[ ! -f "$TEMPLATE_FULL" ]]; then
    echo "❌ 模板未找到：$TEMPLATE_FULL"
    echo "   gospec 安装可能损坏或版本过旧，尝试："
    echo "   rm -rf $SKILL_DIR && bash $0"
    exit 1
fi

# ────────────────────────────────────────────────────────
# Step 3: 在当前目录创建 AGENTS.md
# ────────────────────────────────────────────────────────
if [[ -f "$TARGET" ]]; then
    BACKUP="$TARGET.bak.$(date +%Y%m%d%H%M%S)"
    echo "⚠  $TARGET 已存在，备份为 $BACKUP"
    cp "$TARGET" "$BACKUP"
fi

cp "$TEMPLATE_FULL" "$TARGET"

echo "✓ AGENTS.md 已创建：$(pwd)/AGENTS.md"
echo ""
echo "───────────────────────────────────────────────"
echo "下一步："
echo "  1. 检查 AGENTS.md 内容，按需调整核心约束"
echo "  2. 提交到 git："
echo "       git add AGENTS.md"
echo "       git commit -m 'chore: add gospec AGENTS.md'"
echo "  3. 任何 AI agent（Claude Code / Cursor / Cline / Codex）"
echo "     打开本项目都会读到 AGENTS.md 并加载 gospec 规范"
echo "───────────────────────────────────────────────"
