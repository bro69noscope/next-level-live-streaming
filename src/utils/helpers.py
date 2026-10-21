"""Helper functions for various utilities."""

import time
from logging import Logger
from pathlib import Path

import cv2 as cv


def print_countdown(duration: int = 3) -> None:
    """Print a countdown from the specified duration in seconds."""
    for seconds in reversed(range(1, duration)):
        print("\r" + f"Counting down from {seconds} seconds...", end="\r")
        time.sleep(1)


def construct_script_name(file_path: str | Path) -> str:
    """Construct a script name from a file path for further use.

    This function extracts a meaningful module name from the file path to avoid the
    generic `__main__` name appearing in logs when scripts are run directly or as
    subprocesses. It also play a major role in subprocesses identification by our
    terminal_window_manager (tmw) module.

    For main.py entry points, the parent directory name is automatically prefixed to
    make them distinguishable (e.g., "shopwatcher_main" instead of just "main").

    Args:
        file_path: The file path of the script. Pass `__file__`.

    Returns:
        The base name of the file without extension, with parent directory prefix for
        main.py files.

    Example:
        # Regular module
        SCRIPT_NAME = construct_script_name(__file__)  # "shop_tracker"

        # Main entry point (automatically prefixed)
        SCRIPT_NAME = construct_script_name(__file__)  # "shopwatcher_main"

    """
    path = Path(file_path)
    base_name = path.stem

    if base_name == "main":
        parent_name = path.parent.name
        return f"{parent_name}_main"

    return base_name


def load_grayscale_opencv_template(
    template_path: Path, logger: Logger | None = None
) -> cv.typing.MatLike:
    """Load a grayscale OpenCV template image from the specified path."""
    template = cv.imread(str(template_path), cv.IMREAD_GRAYSCALE)
    if template is None:
        e = f"Template image could not be loaded: {template_path}"
        if logger:
            logger.error(e)
        raise ValueError(e)
    return template
