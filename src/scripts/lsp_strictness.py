"""Toggle local LSP strictness without touching pyproject.toml.

Strict mode writes two untracked override files next to pyproject.toml:
  - basedpyrightconfig.json: [tool.basedpyright] copied from pyproject.toml,
    with typeCheckingMode set to "recommended". basedpyright does not merge
    this with pyproject.toml, so the whole section is copied.
  - ruff.toml: extends pyproject.toml and selects every rule.

Relaxed mode deletes both files, so pyproject.toml applies as written.
Both files are added to .git/info/exclude so they never show in git status.

Usage:
    python lsp_strictness.py strict|relaxed|status [--root DIR]
"""

import argparse
import json
import subprocess
import sys
import tomllib
from pathlib import Path

BASEDPYRIGHT_FILE = "basedpyrightconfig.json"
RUFF_FILE = "ruff.toml"
OVERRIDE_FILES = (BASEDPYRIGHT_FILE, RUFF_FILE)
STRICT_TYPE_CHECKING_MODE = "recommended"
RUFF_STRICT_CONFIG = 'extend = "pyproject.toml"\n\n[lint]\nselect = ["ALL"]\n'


def find_root(start: Path) -> Path:
    """Return the nearest parent of `start` (inclusive) holding pyproject.toml."""
    for directory in (start, *start.parents):
        if (directory / "pyproject.toml").is_file():
            return directory
    print(f"pyproject.toml not found above {start}", file=sys.stderr)
    sys.exit(1)


def is_strict(root: Path) -> bool:
    return (root / BASEDPYRIGHT_FILE).exists()


def exclude_from_git(root: Path) -> None:
    """Add the override files to the repo's info/exclude (skipped outside a repo).

    Asks git for the path so worktrees and submodules, where `.git` is a file,
    resolve to the shared exclude file.
    """
    try:
        result = subprocess.run(
            ["git", "rev-parse", "--git-path", "info/exclude"],
            cwd=root,
            capture_output=True,
            text=True,
            check=False,
        )
    except FileNotFoundError:
        return
    if result.returncode != 0:
        return
    exclude = root / result.stdout.strip()
    exclude.parent.mkdir(parents=True, exist_ok=True)
    existing = exclude.read_text(encoding="utf-8") if exclude.exists() else ""
    missing = [name for name in OVERRIDE_FILES if name not in existing.splitlines()]
    if missing:
        separator = "" if not existing or existing.endswith("\n") else "\n"
        exclude.write_text(
            existing + separator + "\n".join(missing) + "\n", encoding="utf-8"
        )


def set_strict(root: Path) -> None:
    with (root / "pyproject.toml").open("rb") as f:
        pyproject = tomllib.load(f)
    config = pyproject.get("tool", {}).get("basedpyright", {})
    config["typeCheckingMode"] = STRICT_TYPE_CHECKING_MODE
    (root / BASEDPYRIGHT_FILE).write_text(
        json.dumps(config, indent=2) + "\n", encoding="utf-8"
    )
    (root / RUFF_FILE).write_text(RUFF_STRICT_CONFIG, encoding="utf-8")
    exclude_from_git(root)


def set_relaxed(root: Path) -> None:
    for name in OVERRIDE_FILES:
        (root / name).unlink(missing_ok=True)


def main() -> None:
    """Parse the CLI arguments and apply the requested mode."""
    parser = argparse.ArgumentParser(description=(__doc__ or "").split("\n", 1)[0])
    parser.add_argument("mode", choices=("strict", "relaxed", "status"))
    parser.add_argument("--root", type=Path, default=Path.cwd())
    args = parser.parse_args()

    root = find_root(args.root.resolve())
    if args.mode == "strict":
        set_strict(root)
    elif args.mode == "relaxed":
        set_relaxed(root)
    print("strict" if is_strict(root) else "relaxed")


if __name__ == "__main__":
    main()
