"""Type definitions shared across the streaming_config domain package."""

from typing import NamedTuple, TypedDict

# Recursive shape of a parsed ports.json5 tree.
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
