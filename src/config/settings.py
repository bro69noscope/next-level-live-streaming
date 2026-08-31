"""Settings module for managing environment variables and project paths."""

import os
from pathlib import Path

from dotenv import load_dotenv

load_dotenv()


def get_env_var(var_name: str, default_value: str = "MISSING_ENV_VAR") -> str:
    """Retrieve an environment variable with a default value."""
    return str(os.getenv(var_name, default_value))


def find_project_root() -> Path:
    """Find the root directory of the project by looking for root marker."""
    root_marker = ".project-root"
    start = Path(__file__).parent
    current = start
    while current != current.parent:
        if (current / root_marker).exists():
            return current
        current = current.parent
    msg = (
        f"Could not find project root marker '{root_marker}' in any parent "
        f"directory of {start}."
    )
    raise FileNotFoundError(msg)


PROJECT_ROOT_PATH = find_project_root()

PYTHONPATH = get_env_var("PYTHONPATH")

GOOGLE_CLOUD_API_KEY = get_env_var("GOOGLE_CLOUD_API_KEY_PATH")

NEO4J_URI = get_env_var("NEO4J_URI")
NEO4J_USER = get_env_var("NEO4J_USER")
NEO4J_PASSWORD = get_env_var("NEO4J_PASSWORD")
