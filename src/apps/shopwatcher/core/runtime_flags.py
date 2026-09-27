"""Runtime flags for the shopwatcher app, set once at startup from CLI args."""

always_react: bool = False
"""If True, bypass the random rolls and always react to the shop staying open."""

react_fast: bool = False
"""If True, react to the shop staying open after a shorter duration than usual."""
