#!/usr/bin/env python3
"""
build-skill.py — 跨平台把 gospec 打包成 .skill 文件。

与 build-skill.sh 等价，但不依赖 bash / zip / cp，只需 python3 + pyyaml。
Windows / macOS / Linux 通用。

用法：
    python3 scripts/build-skill.py              # 输出到 ./dist/gospec.skill
    python3 scripts/build-skill.py /path/to/out # 输出到指定目录

可作为模块 import：
    from build_skill import build
    build(out_dir=Path("/tmp/dist"))
"""

import shutil
import subprocess
import sys
import tempfile
import zipfile
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
DEFAULT_OUT_DIR = REPO_ROOT / "dist"

# 打包进 .skill 的文件（相对 repo root）
STAGE_FILES = [
    "SKILL.md",
    "AGENTS.md",
    "LICENSE",
]
STAGE_DIRS = [
    "spec",
    "docs",
]
# 仅打包用户需要的脚本，不打包维护者脚本（build-skill.* / validate-skill.py）
STAGE_SCRIPTS = [
    "scripts/install.sh",
]


def run_validate() -> None:
    """调用 scripts/validate-skill.py 校验 frontmatter + 必备文件。"""
    print("🔍 Validating SKILL.md...")
    validator = REPO_ROOT / "scripts" / "validate-skill.py"
    result = subprocess.run(
        [sys.executable, str(validator), str(REPO_ROOT)],
        check=False,
    )
    if result.returncode != 0:
        sys.exit(result.returncode)
    print()


def stage_files(staging_dir: Path) -> None:
    """把需要打包的文件复制到 staging 目录。"""
    print("📦 Staging skill files...")
    staging_dir.mkdir(parents=True, exist_ok=True)

    for f in STAGE_FILES:
        src = REPO_ROOT / f
        dst = staging_dir / f
        shutil.copy2(src, dst)

    for d in STAGE_DIRS:
        src = REPO_ROOT / d
        dst = staging_dir / d
        shutil.copytree(src, dst)

    (staging_dir / "scripts").mkdir(exist_ok=True)
    for s in STAGE_SCRIPTS:
        src = REPO_ROOT / s
        dst = staging_dir / s
        shutil.copy2(src, dst)
        dst.chmod(0o755)

    print()


def package_zip(staging_root: Path, out_path: Path) -> None:
    """把 staging_root 下的内容压成 .skill (zip) 文件。

    staging_root 是包含 gospec/ 子目录的临时父目录，这样 zip 里的
    路径是 gospec/SKILL.md 而不是 SKILL.md。
    """
    print("🗜  Packaging...")
    out_path.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(out_path, "w", zipfile.ZIP_DEFLATED) as zf:
        for file_path in sorted(staging_root.rglob("*")):
            if file_path.is_file():
                arcname = file_path.relative_to(staging_root)
                zf.write(file_path, arcname.as_posix())

    print()


def report(out_path: Path) -> None:
    """打印产物信息。"""
    size_kb = out_path.stat().st_size / 1024
    print(f"✅ Built: {out_path}")
    print(f"   Size: {size_kb:.1f} KB")

    with zipfile.ZipFile(out_path) as zf:
        names = zf.namelist()
        total_uncompressed = sum(zf.getinfo(n).file_size for n in names)

    print(f"   Files: {len(names)}")
    print(f"   Uncompressed: {total_uncompressed / 1024:.1f} KB")
    print()
    print("📋 Contents (last 10):")
    with zipfile.ZipFile(out_path) as zf:
        for name in sorted(zf.namelist())[-10:]:
            info = zf.getinfo(name)
            print(f"   {info.file_size:>8}  {name}")


def build(out_dir: Path = DEFAULT_OUT_DIR) -> Path:
    """主入口：验证 + staging + 打包。返回产物路径。"""
    out_dir = Path(out_dir).resolve()
    out_path = out_dir / "gospec.skill"

    run_validate()

    with tempfile.TemporaryDirectory() as tmp:
        tmp_root = Path(tmp)
        staging_dir = tmp_root / "gospec"
        stage_files(staging_dir)
        package_zip(tmp_root, out_path)

    report(out_path)
    return out_path


def main() -> None:
    out_dir = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_OUT_DIR
    build(out_dir)


if __name__ == "__main__":
    main()
