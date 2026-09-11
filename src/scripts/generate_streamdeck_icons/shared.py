import subprocess
from pathlib import Path

from src.utils.logging_utils import setup_logger

from .constants import PRETTIER_PATH

PRETTIER_QUEUE: list[Path] = []


class KnownBadProfile(ValueError):
    pass


def format_with_prettier(paths: list[Path]):
    if not paths:
        return

    result = subprocess.run(
        [str(PRETTIER_PATH), "--write", "--no-config", *[str(p) for p in paths]],
        capture_output=True,
        text=True,
    )

    if result.stdout:
        logger.info(result.stdout.strip())

    if result.returncode != 0:
        if result.stderr:
            logger.error(result.stderr.strip())
        raise subprocess.CalledProcessError(
            result.returncode, result.args, result.stdout, result.stderr
        )


LOG_DIR = Path(__file__).resolve().parent / "logs"
logger = setup_logger("generate-icons", log_dir=LOG_DIR, log_in_common=False)
