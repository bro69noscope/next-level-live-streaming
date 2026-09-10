import subprocess
from pathlib import Path

from constants import PRETTIER_PATH
from src.utils.logging_utils import setup_logger


def format_with_prettier(path: Path):
    subprocess.run(
        [str(PRETTIER_PATH), "--write", str(path)],
        check=True,
        cwd=path.parent,
    )


LOG_DIR = Path(__file__).resolve().parent / "logs"
logger = setup_logger("generate-icons", log_dir=LOG_DIR)
