"""Utility functions for setting up and managing loggers."""

import configparser
import logging
from logging import Logger
from pathlib import Path

from src.config.settings import PROJECT_ROOT_PATH
from src.core.constants import COMMON_LOGS_FILE_PATH, LOG_DIR_PATH

LOG_LEVELS = {
    "DEBUG": logging.DEBUG,
    "INFO": logging.INFO,
    "WARNING": logging.WARNING,
    "ERROR": logging.ERROR,
    "CRITICAL": logging.CRITICAL,
}


def setup_logger(
    file_name: str,
    level: str | None = None,
    log_dir: Path | None = None,
    log_in_common: bool = True,
) -> logging.Logger:
    """Set up a logger that logs to a script-specific log file and a common log file.

    If a logging level is not provided, it reads from the configuration file situated
    in `config/settings.ini`. If log_dir is not provided, defaults to LOG_DIR_PATH.
    """
    log_dir = log_dir or LOG_DIR_PATH
    if not log_dir.exists():
        log_dir.mkdir(parents=True, exist_ok=True)

    script_log_file_path = log_dir / f"{file_name}.log"

    if level is None:
        config = configparser.ConfigParser()
        config_path = PROJECT_ROOT_PATH / "config" / "settings.ini"

        if config.read(config_path):
            level = config.get("logging", "level", fallback="DEBUG").upper()
        else:
            level = "DEBUG"

    level = level.upper()
    if level not in LOG_LEVELS:
        level = "DEBUG"

    with script_log_file_path.open("a", encoding="utf-8") as log_file:
        log_file.write("\n")
        log_file.write("<< New Log Entry >>\n")

    logger = logging.getLogger(file_name)
    if not logger.hasHandlers():
        logger.setLevel(LOG_LEVELS[level])

        # Script-specific file handler with UTF-8 encoding
        script_fh = logging.FileHandler(script_log_file_path, encoding="utf-8")
        script_fh.setLevel(LOG_LEVELS[level])
        formatter = logging.Formatter(
            "%(asctime)s - %(filename)s:%(lineno)d - %(levelname)s - %(message)s"
        )
        script_fh.setFormatter(formatter)
        logger.addHandler(script_fh)

        if not log_in_common:
            return logger

        # Common file handler with UTF-8 encoding
        common_fh = logging.FileHandler(COMMON_LOGS_FILE_PATH, encoding="utf-8")
        common_fh.setLevel(LOG_LEVELS[level])
        common_formatter = logging.Formatter(
            "%(asctime)s - %(filename)s:%(lineno)d - %(levelname)s - %(message)s"
        )
        common_fh.setFormatter(common_formatter)
        logger.addHandler(common_fh)

    return logger


def log_empty_lines(logger: Logger, lines: int = 1) -> None:
    """Log empty lines to all file handlers of the given logger.

    Allows to space the entry better and create gaps that dont have the timestamp info
    in them.
    """
    for handler in logger.handlers:
        if isinstance(handler, logging.FileHandler):
            handler.stream.write(lines * "\n")
            handler.flush()
