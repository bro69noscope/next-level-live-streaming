"""Port rules: collected from the ports.json5 tree."""

import sys
from typing import cast, get_args

from src.config.settings import PROJECT_ROOT_PATH
from src.streaming_config.types import Consumer, JsonValue, Rule, ScopeKeys

PORTS_SOURCE = PROJECT_ROOT_PATH / "config" / "ports.json5"

VALID_SCOPE_KEYS = frozenset(get_args(Consumer)) | {"default"}


def _validate_scope_keys(scope_keys: ScopeKeys, context: str) -> None:
    bad_keys = scope_keys.keys() - VALID_SCOPE_KEYS
    if bad_keys:
        err = (
            f"{context} has invalid scope_keys {sorted(bad_keys)}; "
            f"expected one of {sorted(VALID_SCOPE_KEYS)}"
        )
        raise ValueError(err)


def collect_ports_rules(node: JsonValue, rules: list[Rule]) -> None:
    """Recursively walk the parsed json5 tree and collect ports rules."""
    if not isinstance(node, dict):
        return

    if "token" in node and "port" in node:
        token = cast("str", node["token"])
        scope_keys = cast("ScopeKeys", node.get("scope_keys", {}))
        _validate_scope_keys(scope_keys, context=f"node {node}")

        rules.append(
            Rule(
                field_name="port",
                value=str(node["port"]),
                token=token,
                scope_keys=scope_keys,
            )
        )

    if "tokens" in node and isinstance(node["tokens"], dict):
        for field_name, token_spec in node["tokens"].items():
            if field_name not in node:
                print(
                    f"Warning: tokens.{field_name} has no matching "
                    f"'{field_name}' field on parent object {node} — skipping",
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
            _validate_scope_keys(scope_keys, context=f"node {node}")

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
            collect_ports_rules(value, rules)
