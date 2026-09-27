import json
from pathlib import Path

from src.config.settings import PROJECT_ROOT_PATH
from src.streaming_config.types import (
    Consumer,
    Rule,
    ScopedEntry,
    ScopedMapping,
    ScopeKeys,
)

CONSUMER_OUTPUTS: dict[Consumer, Path] = {
    "obs": PROJECT_ROOT_PATH / "config" / "scoped_generated.obs.json",
    "streamdeck": PROJECT_ROOT_PATH / "config" / "scoped_generated.streamdeck.json",
    "streamerbot": PROJECT_ROOT_PATH / "config" / "scoped_generated.streamerbot.json",
}


def _resolve_key(field_name: str, scope_keys: ScopeKeys | None, consumer: str) -> str:
    if not scope_keys:
        return field_name
    if consumer in scope_keys:
        return scope_keys[consumer]
    if "default" in scope_keys:
        return scope_keys["default"]
    return field_name


def _build_scoped_entries(rules: list[Rule], consumer: Consumer) -> list[ScopedEntry]:
    entries: list[ScopedEntry] = []
    for rule in rules:
        if rule.consumers is not None and consumer not in rule.consumers:
            continue
        key = _resolve_key(rule.field_name, rule.scope_keys, consumer)
        entries.append({"key": key, "value": rule.value, "token": rule.token})
    return entries


def write_consumer_files(rules: list[Rule]) -> list[tuple[str, Path, int]]:
    """Write each consumer's scoped mapping file.

    Returns one (consumer, output_path, entry_count) tuple per consumer, in
    the order they were written, for the caller to report on.
    """
    written: list[tuple[str, Path, int]] = []
    for consumer, out_path in CONSUMER_OUTPUTS.items():
        entries = _build_scoped_entries(rules, consumer)
        mapping: ScopedMapping = {"scoped": entries}
        out_path.parent.mkdir(parents=True, exist_ok=True)
        with out_path.open("w", encoding="utf-8") as f:
            json.dump(mapping, f, indent=2)
            f.write("\n")
        written.append((consumer, out_path, len(entries)))
    return written
