"""Type definitions shared across the streaming_config domain package."""

from typing import Literal, NamedTuple, TypedDict

# Recursive shape of a parsed ports.json5 tree.
type JsonValue = JsonTree | str | int | float | bool | None
type JsonTree = dict[str, JsonValue]

Consumer = Literal["obs", "streamdeck", "streamerbot"]
ScopeKeys = dict[Consumer | Literal["default"], str]


class Rule(NamedTuple):
    """One (field, value, token) tuple destined for consumer mapping files."""

    field_name: str
    value: str
    token: str
    scope_keys: ScopeKeys | None = None
    """Per-consumer key overrides; None means field_name is used everywhere."""
    consumers: frozenset[Consumer] | None = None
    """Consumers that receive this rule; None means all of them."""


class ScopedEntry(TypedDict):
    """A single entry in a generated per-consumer mapping file."""

    key: str
    value: str
    token: str


class ScopedMapping(TypedDict):
    """Top-level shape of a generated per-consumer mapping file."""

    scoped: list[ScopedEntry]
