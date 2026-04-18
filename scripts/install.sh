#!/usr/bin/env bash
# install.sh — 在你的 Go 项目根目录运行，一行命令安装并激活 gospec
#
# 它做几件事：
#   1. 安装 gospec skill 到 ~/.claude/skills/gospec/（如果还没装）
#   2. 在当前目录创建 AGENTS.md（Codex / Cline / Cursor 等通用入口）
#   3. 检测 Cursor，自动落 .cursor/rules/gospec.mdc
#      —— 让 Cursor 通过 globs 自动附加，避免每次让用户挑选
#   4. 检测 Claude Code 项目级 .claude/，可选项目级 skill 软链
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
#
# 跳过 Cursor 落盘：
#     NO_CURSOR=1 bash <(curl -sSL .../install.sh)

set -euo pipefail

REPO_URL="https://github.com/singchia/gospec.git"
SKILL_DIR="${SKILL_DIR:-$HOME/.claude/skills/gospec}"
TEMPLATE_REL="docs/templates/project-agents-template.md"
CURSOR_TEMPLATE_REL="docs/templates/cursor-rule-template.mdc"
TARGET_AGENTS="./AGENTS.md"
TARGET_CURSOR_DIR="./.cursor/rules"
TARGET_CURSOR="$TARGET_CURSOR_DIR/gospec.mdc"

echo "📦 gospec 安装"
echo ""

# ────────────────────────────────────────────────────────
# Step 1: 确保 skill 已安装
# ────────────────────────────────────────────────────────
if [[ -f "$SKILL_DIR/SKILL.md" ]]; then
    echo "✓ gospec skill 已安装在 $SKILL_DIR"
    # 可选：检测远端有更新提示用户 update（不强制）
    if command -v git >/dev/null 2>&1 && [[ -d "$SKILL_DIR/.git" ]]; then
        if git -C "$SKILL_DIR" fetch --quiet origin 2>/dev/null; then
            BEHIND=$(git -C "$SKILL_DIR" rev-list --count HEAD..origin/main 2>/dev/null || echo 0)
            if [[ "$BEHIND" != "0" ]]; then
                echo "⚠  本地 gospec 落后远端 $BEHIND 个 commit，更新："
                echo "     git -C $SKILL_DIR pull --ff-only"
            fi
        fi
    fi
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
CURSOR_TEMPLATE_FULL="$SKILL_DIR/$CURSOR_TEMPLATE_REL"
if [[ ! -f "$TEMPLATE_FULL" ]]; then
    echo "❌ AGENTS 模板未找到：$TEMPLATE_FULL"
    echo "   gospec 安装可能损坏或版本过旧，尝试："
    echo "   rm -rf $SKILL_DIR && bash $0"
    exit 1
fi

# ────────────────────────────────────────────────────────
# Step 3: 在当前目录创建 AGENTS.md
# ────────────────────────────────────────────────────────
if [[ -f "$TARGET_AGENTS" ]]; then
    BACKUP="$TARGET_AGENTS.bak.$(date +%Y%m%d%H%M%S)"
    echo "⚠  $TARGET_AGENTS 已存在，备份为 $BACKUP"
    cp "$TARGET_AGENTS" "$BACKUP"
fi
cp "$TEMPLATE_FULL" "$TARGET_AGENTS"
echo "✓ AGENTS.md 已创建：$(pwd)/AGENTS.md（Codex / Cline / 通用 agent 入口）"

# ────────────────────────────────────────────────────────
# Step 4: 为 Cursor 落 .cursor/rules/gospec.mdc
#         （单文件 + globs 自动附加，避免 Cursor 每次让用户选择）
# ────────────────────────────────────────────────────────
if [[ "${NO_CURSOR:-0}" == "1" ]]; then
    echo "⏭  跳过 Cursor 规则（NO_CURSOR=1）"
elif [[ ! -f "$CURSOR_TEMPLATE_FULL" ]]; then
    echo "⚠  Cursor 模板未找到，跳过：$CURSOR_TEMPLATE_FULL"
else
    mkdir -p "$TARGET_CURSOR_DIR"
    if [[ -f "$TARGET_CURSOR" ]]; then
        BACKUP="$TARGET_CURSOR.bak.$(date +%Y%m%d%H%M%S)"
        echo "⚠  $TARGET_CURSOR 已存在，备份为 $BACKUP"
        cp "$TARGET_CURSOR" "$BACKUP"
    fi
    cp "$CURSOR_TEMPLATE_FULL" "$TARGET_CURSOR"
    echo "✓ Cursor 规则已创建：$TARGET_CURSOR"
    echo "  （globs 自动附加 .go / .proto / Dockerfile / migration，无需每次手动选）"
fi

# ────────────────────────────────────────────────────────
# Step 5: 提示 Claude Code 项目级安装
# ────────────────────────────────────────────────────────
if [[ -d ".claude" && ! -d ".claude/skills/gospec" ]]; then
    echo ""
    echo "💡 检测到 .claude/，如需项目级安装（不影响其他项目）："
    echo "     SKILL_DIR=.claude/skills/gospec bash $0"
fi

echo ""
echo "───────────────────────────────────────────────"
echo "下一步："
echo "  1. 检查 AGENTS.md / .cursor/rules/gospec.mdc 内容，按需调整"
echo "  2. 提交到 git："
echo "       git add AGENTS.md .cursor/rules/gospec.mdc"
echo "       git commit -m 'chore: add gospec rules'"
echo "  3. 任何 AI agent（Claude Code / Cursor / Cline / Codex / Gemini CLI）"
echo "     打开本项目都会自动加载 gospec 规范"
echo "───────────────────────────────────────────────"
