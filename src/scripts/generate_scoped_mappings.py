"""Thin CLI for generating per-consumer scoped mapping JSON files from ports.json5.

See src.streaming_config.scoped_mappings for the supported ports.json5 leaf
shapes and the rule-collection/resolution logic.

Usage:
    python -m src.scripts.generate_scoped_mappings
"""

import sys
from typing import TYPE_CHECKING, cast

import json5
from src.streaming_config.scoped_mappings import (
    PORTS_SOURCE,
    collect_rules,
    write_consumer_files,
)

if TYPE_CHECKING:
    from src.streaming_config.types import JsonTree, Rule


def main() -> None:
    """Generate per-consumer scoped mapping JSON files from a single ports.json5."""
    if not PORTS_SOURCE.exists():
        print(f"Source file not found: {PORTS_SOURCE}", file=sys.stderr)
        sys.exit(1)

    with PORTS_SOURCE.open("r", encoding="utf-8") as f:
        tree = cast(
            "JsonTree",
            json5.load(f),  # pyright: ignore[reportUnknownMemberType]
        )

    rules: list[Rule] = []
    collect_rules(tree, rules)

    if not rules:
        print(
            "No token rules found in source file — nothing generated.", file=sys.stderr
        )
        sys.exit(1)

    for _consumer, out_path, count in write_consumer_files(rules):
        print(f"Wrote {count} rules -> {out_path}")


if __name__ == "__main__":
    main()
