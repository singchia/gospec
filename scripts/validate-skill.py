#!/usr/bin/env python3
"""
validate-skill.py — 校验 gospec skill 的结构和 SKILL.md frontmatter。

不依赖外部 skill 工具。只需要 python3 + pyyaml。

用法：
    python3 scripts/validate-skill.py              # 校验当前目录
    python3 scripts/validate-skill.py /path/to/dir # 校验指定目录
    python3 scripts/validate-skill.py --strict .   # 自查清单缺失视为失败

退出码：0 = 通过，1 = 失败。
"""

import re
import sys
from pathlib import Path

try:
    import yaml
except ImportError:
    print("❌ 需要 pyyaml。安装：pip install pyyaml")
    sys.exit(2)


# 与 skill-creator/quick_validate.py 保持一致
ALLOWED_FRONTMATTER = {
    "name",
    "description",
    "license",
    "allowed-tools",
    "metadata",
    "compatibility",
}
REQUIRED_FRONTMATTER = {"name", "description"}

# gospec 自身的额外约束
GOSPEC_REQUIRED_FILES = [
    "SKILL.md",
    "AGENTS.md",
    "spec/spec.md",
    "docs/templates/project-agents-template.md",
    "docs/templates/product-requirement-template.md",
    "docs/templates/technical-rfc-template.md",
    "docs/templates/architecture-decision-record-template.md",
    "docs/templates/high-level-design-template.md",
    "docs/templates/cursor-rule-template.mdc",
    "scripts/install.sh",
]

# 路由表里的 spec 子文件必须真实存在
ROUTING_LINK_RE = re.compile(r"`(\d{2}-[\w-]+/[\w.-]+\.md|\d{2}-[\w-]+\.md|spec\.md)`")

# 每个 spec 子文件应有"自查清单"小节，否则 agent 完成任务后无法对照
# 例外：纯路由 / 索引文件
SELF_CHECK_HEADERS = ("自查清单", "Checklist", "checklist")
SELF_CHECK_EXEMPT = {
    "spec/spec.md",        # 入口路由
    "spec/05-coding/README.md",  # 二级路由
    "spec/01-requirement/README.md",
    "spec/02-architecture/README.md",
    "spec/03-api/README.md",
    "spec/04-data-model/README.md",
    "spec/06-testing/README.md",
    "spec/08-delivery/README.md",
    "spec/10-observability/README.md",
    "spec/11-security/README.md",
    "spec/12-operations/README.md",
    "spec/13-database-migration/README.md",
}


def validate_frontmatter(skill_md: Path) -> tuple[bool, str]:
    content = skill_md.read_text()
    if not content.startswith("---"):
        return False, "SKILL.md 缺少 YAML frontmatter（必须以 --- 开头）"

    m = re.match(r"^---\n(.*?)\n---", content, re.DOTALL)
    if not m:
        return False, "SKILL.md frontmatter 格式不合法（找不到结束的 ---）"

    try:
        fm = yaml.safe_load(m.group(1))
    except yaml.YAMLError as e:
        return False, f"frontmatter YAML 解析失败: {e}"

    if not isinstance(fm, dict):
        return False, "frontmatter 必须是 YAML 字典"

    # Required
    missing = REQUIRED_FRONTMATTER - fm.keys()
    if missing:
        return False, f"缺少必填字段: {', '.join(sorted(missing))}"

    # Allowed
    extra = set(fm.keys()) - ALLOWED_FRONTMATTER
    if extra:
        return False, (
            f"frontmatter 含不允许字段: {', '.join(sorted(extra))}\n"
            f"   允许的字段: {', '.join(sorted(ALLOWED_FRONTMATTER))}"
        )

    # name 校验
    name = fm["name"]
    if not isinstance(name, str):
        return False, f"name 必须是字符串"
    if not re.match(r"^[a-z0-9-]+$", name):
        return False, f"name '{name}' 必须是 kebab-case（小写字母 / 数字 / 连字符）"
    if len(name) > 64:
        return False, f"name 太长 ({len(name)} > 64)"
    if name.startswith("-") or name.endswith("-") or "--" in name:
        return False, f"name '{name}' 连字符位置不合法"

    # description 校验
    desc = fm["description"]
    if not isinstance(desc, str):
        return False, "description 必须是字符串"
    if len(desc) > 1024:
        return False, f"description 太长 ({len(desc)} > 1024)"
    if "<" in desc or ">" in desc:
        return False, "description 不能包含尖括号 < 或 >"

    return True, name


def validate_files(skill_dir: Path) -> tuple[bool, str]:
    missing = []
    for rel in GOSPEC_REQUIRED_FILES:
        if not (skill_dir / rel).exists():
            missing.append(rel)
    if missing:
        return False, "缺少 gospec 必备文件:\n   " + "\n   ".join(missing)
    return True, ""


def validate_routing_links(skill_dir: Path) -> tuple[bool, str]:
    """spec/spec.md 路由表里引用的所有 spec 子文件必须存在。"""
    spec_md = skill_dir / "spec" / "spec.md"
    text = spec_md.read_text()
    spec_root = skill_dir / "spec"
    broken = []
    for match in ROUTING_LINK_RE.findall(text):
        # 跳过 spec.md 自引用
        if match == "spec.md":
            continue
        target = spec_root / match
        if not target.exists():
            broken.append(match)
    if broken:
        unique = sorted(set(broken))
        return False, "spec/spec.md 路由表引用了不存在的文件:\n   " + "\n   ".join(unique)
    return True, ""


def validate_self_check(skill_dir: Path) -> tuple[bool, str]:
    """每个 spec/*.md 子文件（非索引）应有自查清单或对应小节。"""
    spec_root = skill_dir / "spec"
    missing = []
    for md in spec_root.rglob("*.md"):
        rel = md.relative_to(skill_dir).as_posix()
        if rel in SELF_CHECK_EXEMPT:
            continue
        body = md.read_text()
        if not any(h in body for h in SELF_CHECK_HEADERS):
            missing.append(rel)
    if missing:
        return False, "以下 spec 子文件缺少自查清单 / Checklist 小节:\n   " + "\n   ".join(sorted(missing))
    return True, ""


def validate(skill_dir: str, strict: bool = False) -> tuple[bool, str, list[str]]:
    """返回 (ok, summary_msg, warnings)。warnings 只在非 strict 模式下不阻塞。"""
    skill_dir = Path(skill_dir).resolve()
    warnings: list[str] = []

    if not skill_dir.is_dir():
        return False, f"目录不存在: {skill_dir}", warnings

    skill_md = skill_dir / "SKILL.md"
    if not skill_md.exists():
        return False, f"SKILL.md 不存在: {skill_md}", warnings

    ok, msg = validate_frontmatter(skill_md)
    if not ok:
        return False, msg, warnings
    name = msg

    ok, msg = validate_files(skill_dir)
    if not ok:
        return False, msg, warnings

    ok, msg = validate_routing_links(skill_dir)
    if not ok:
        return False, msg, warnings

    ok, msg = validate_self_check(skill_dir)
    if not ok:
        if strict:
            return False, msg, warnings
        warnings.append(msg)

    return True, (
        f"skill '{name}' 通过校验"
        f"（frontmatter + {len(GOSPEC_REQUIRED_FILES)} 必备文件 + 路由表完整性"
        f"{' + 自查清单' if not warnings else ''}）"
    ), warnings


if __name__ == "__main__":
    args = sys.argv[1:]
    strict = "--strict" in args
    args = [a for a in args if a != "--strict"]
    target = args[0] if args else "."
    ok, msg, warnings = validate(target, strict=strict)
    for w in warnings:
        print("⚠️  " + w)
    print(("✅ " if ok else "❌ ") + msg)
    sys.exit(0 if ok else 1)
