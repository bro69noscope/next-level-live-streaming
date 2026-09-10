import subprocess
from pathlib import Path

from constants import PRETTIER_PATH
from src.utils.logging_utils import setup_logger

PRETTIER_QUEUE: list[Path] = []


def format_with_prettier(paths: list[Path]):
    if not paths:
        return
    subprocess.run(
        [str(PRETTIER_PATH), "--write", "--no-config", *[str(p) for p in paths]],
        check=True,
    )


LOG_DIR = Path(__file__).resolve().parent / "logs"
logger = setup_logger("generate-icons", log_dir=LOG_DIR)
