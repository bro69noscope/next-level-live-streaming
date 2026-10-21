"""Utility to initialize terminal window managed scripts."""

import atexit
import signal
import sys
from collections.abc import Callable
from types import FrameType

import aiosqlite

from src.core.termwm import (
    TERMINAL_WINDOW_SLOTS_DB_FILE_PATH,
    TerminalWindowManager,
    WinType,
)
from src.core.termwm import (
    slots_db_handler as sdh,
)
from src.utils.helpers import construct_script_name
from src.utils.lock_file_manager import LockFileManager
from src.utils.logging_utils import setup_logger

SCRIPT_NAME = construct_script_name(__file__)
logger = setup_logger(SCRIPT_NAME)

cleanup_functions: list[
    tuple[Callable[..., None], tuple[object, ...], dict[str, object]]
] = []


def _register_atexit_func(
    func: Callable[..., None], *args: object, **kwargs: object
) -> None:
    atexit.register(func, *args, **kwargs)
    # Also keep track of the cleanup functions for signal handling
    cleanup_functions.append((func, args, kwargs))


def _witness_atexit_execution() -> None:
    print("this print was triggered by atexit module")
    logger.debug("this log entry was triggered by atexit module")


def _signal_module_cleanup() -> None:
    atexit.unregister(_witness_atexit_execution)
    for func, args, kwargs in cleanup_functions:
        print(f"called clean up func: {func.__name__}")
        logger.debug(f"called clean up func: {func.__name__}")
        func(*args, **kwargs)
        atexit.unregister(func)


def _signal_handler(sig: int, _: FrameType | None) -> None:
    print(f"Signal {sig} received, calling cleanup.")
    logger.info(f"Signal {sig} received, calling cleanup.")
    _signal_module_cleanup()
    sys.exit(0)


def _setup_signal_handlers() -> None:
    logger.debug("Signal handlers are set up.")
    signal.signal(signal.SIGTERM, _signal_handler)
    signal.signal(signal.SIGINT, _signal_handler)


async def _manage_script_startup(
    slots_db_conn: aiosqlite.Connection,
    window_type: WinType,
    script_name: str,
    lock_file_manager: LockFileManager | None = None,
    title_setter: Callable[[str], None] | None = None,
) -> int | None:
    twm = TerminalWindowManager()

    slot, name = await twm.adjust_terminal_window(
        slots_db_conn, window_type, script_name, title_setter=title_setter
    )
    if window_type == WinType.DENIED:
        _register_atexit_func(sdh.free_denied_slot_sync, slot)
        print(f"\n>>> Lock file is present for {script_name} <<<")
        logger.info(f"Lock file is present for {script_name}")

    elif window_type == WinType.ACCEPTED:
        if lock_file_manager:
            lock_file_manager.create_lock_file()
            _register_atexit_func(lock_file_manager.remove_lock_file)
        _register_atexit_func(sdh.free_slot_by_name_sync, name)
    return slot


async def setup_script(
    script_name, *, title_setter=None
) -> tuple[aiosqlite.Connection, int | None]:
    """Initialize the must have components for a terminal window managed script."""

    lock_file_manager = LockFileManager(script_name)
    db_conn = await sdh.create_connection(TERMINAL_WINDOW_SLOTS_DB_FILE_PATH)

    if not db_conn:
        e = f"Failed to connect to database: {TERMINAL_WINDOW_SLOTS_DB_FILE_PATH}"
        raise ConnectionError(e)

    _setup_signal_handlers()
    atexit.register(_witness_atexit_execution)

    if lock_file_manager.lock_exists():
        window_type = WinType.DENIED
    else:
        window_type = WinType.ACCEPTED

    slot = await _manage_script_startup(
        db_conn, window_type, script_name, lock_file_manager, title_setter
    )

    return db_conn, slot
