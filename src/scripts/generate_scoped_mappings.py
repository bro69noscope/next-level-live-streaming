"""Thin CLI for generating per-consumer scoped mapping JSON files.

Rules come from ports.json5 (ports, urls) and from code-defined path rules.

Usage:
    python generate_scoped_mappings.py
"""

import sys
from typing import TYPE_CHECKING, cast

import json5

from src.streaming_config.scoped_mappings import (
    PATH_RULES,
    PORTS_SOURCE,
    collect_ports_rules,
    write_consumer_files,
)

if TYPE_CHECKING:
    from src.streaming_config.types import JsonTree, Rule


def main() -> None:
    """Generate per-consumer scoped mapping JSON files from ports.json5 and path rules."""
    if not PORTS_SOURCE.exists():
        print(f"Source file not found: {PORTS_SOURCE}", file=sys.stderr)
        sys.exit(1)

    with PORTS_SOURCE.open("r", encoding="utf-8") as f:
        ports_tree = cast(
            "JsonTree",
            json5.load(f),  # pyright: ignore[reportUnknownMemberType]
        )

    rules: list[Rule] = []
    collect_ports_rules(ports_tree, rules)

    if not rules:
        print(
            "No token rules found in source file — nothing generated.", file=sys.stderr
        )
        sys.exit(1)

    rules.extend(PATH_RULES)

    for consumer, out_path, count in write_consumer_files(rules):
        print(f"Wrote {count} rules for {consumer} -> {out_path}")


if __name__ == "__main__":
    main()
