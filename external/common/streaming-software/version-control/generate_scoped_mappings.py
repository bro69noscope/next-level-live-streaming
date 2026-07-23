"""Generates per-consumer scoped mapping JSON files from a single ports.json5.

ports.json5 leaf shapes supported:

1. Simple leaf (one value, one token):
    {
      "port": 51000,
      "token": "{{OBS_PRODUCTION_PORT}}",
      "scope_keys": {"obs": "server_port", "default": "port"}   # optional
    }

2. Multi-field leaf (several values on one object, each with its own token):
    {
      "port": 50000,
      "url": "ws://localhost:50000",
      "tokens": {
        "url":  {"token": "{{REPOSITORY_PYTHON_WS}}"},
        "port": {"token": "{{REPOSITORY_PYTHON_PORT}}",
                 "scope_keys": {"default": "port"}}   # optional
      }
    }

For each recognized (field_name, value, token, scope_keys) tuple found
anywhere in the tree, this emits one scoped-rule entry per configured
consumer, resolving the JSON key each consumer's target files actually use
via: scope_keys.get(consumer) -> scope_keys.get("default") -> field_name.

Usage:
    python generate_scoped_mappings.py
"""

import json
import sys
from pathlib import Path
from typing import NamedTuple, TypedDict, cast

import json5
from src.config.settings import PROJECT_ROOT_PATH

PORTS_SOURCE = PROJECT_ROOT_PATH / "config" / "ports.json5"

# Each consumer's generated scoped mapping file gets written here.
# Add/remove entries as new templater modules are added.
CONSUMER_OUTPUTS: dict[str, Path] = {
    "obs": PROJECT_ROOT_PATH / "config" / "ports_generated.obs.json",
    "streamdeck": PROJECT_ROOT_PATH / "config" / "ports_generated.streamdeck.json",
    "streamerbot": PROJECT_ROOT_PATH / "config" / "ports_generated.streamerbot.json",
}

# Recursive shape of the parsed ports.json5 tree.
type JsonValue = JsonTree | str | int | float | bool | None
type JsonTree = dict[str, JsonValue]

ScopeKeys = dict[str, str]


class Rule(NamedTuple):
    """One (field, value, token) tuple collected from a ports.json5 leaf."""

    field_name: str
    value: str
    token: str
    scope_keys: ScopeKeys


class ScopedEntry(TypedDict):
    """A single entry in a generated per-consumer mapping file."""

    key: str
    value: str
    token: str


class ScopedMapping(TypedDict):
    """Top-level shape of a generated per-consumer mapping file."""

    scoped: list[ScopedEntry]


def resolve_key(field_name: str, scope_keys: ScopeKeys, consumer: str) -> str:
    """Resolve the JSON key each consumer actually use."""
    if not scope_keys:
        return field_name
    if consumer in scope_keys:
        return scope_keys[consumer]
    if "default" in scope_keys:
        return scope_keys["default"]
    return field_name


def collect_rules(node: JsonValue, rules: list[Rule]) -> None:
    """Recursively walk the parsed json5 tree."""
    if not isinstance(node, dict):
        return

    if "token" in node and "port" in node:
        rules.append(
            Rule(
                field_name="port",
                value=str(node["port"]),
                token=cast("str", node["token"]),
                scope_keys=cast("ScopeKeys", node.get("scope_keys", {})),
            )
        )

    if "tokens" in node and isinstance(node["tokens"], dict):
        for field_name, token_spec in node["tokens"].items():
            if field_name not in node:
                print(
                    f"Warning: tokens.{field_name} has no matching "
                    f"'{field_name}' field on parent object — skipping",
                    file=sys.stderr,
                )
                continue

            if not isinstance(token_spec, dict) or "token" not in token_spec:
                err = (
                    f"tokens.{field_name} must be an object with a 'token' key, "
                    f"got: {token_spec!r}"
                )
                raise ValueError(err)

            token = cast("str", token_spec["token"])
            scope_keys = cast("ScopeKeys", token_spec.get("scope_keys", {}))

            rules.append(
                Rule(
                    field_name=field_name,
                    value=str(node[field_name]),
                    token=token,
                    scope_keys=scope_keys,
                )
            )

    for value in node.values():
        if isinstance(value, dict):
            collect_rules(value, rules)


def build_scoped_entries(rules: list[Rule], consumer: str) -> list[ScopedEntry]:
    """Build a list of scoped entries for a given consumer."""
    entries: list[ScopedEntry] = []
    for field_name, value, token, scope_keys in rules:
        key = resolve_key(field_name, scope_keys, consumer)
        entries.append({"key": key, "value": value, "token": token})
    return entries


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

    for consumer, out_path in CONSUMER_OUTPUTS.items():
        entries = build_scoped_entries(rules, consumer)
        mapping: ScopedMapping = {"scoped": entries}
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open() as f:
            json.dump(mapping, f, indent=2)
            f.write("\n")
        print(f"Wrote {len(entries)} rules -> {out_path}")


if __name__ == "__main__":
    main()
