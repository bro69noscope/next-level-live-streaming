"""Main entry point for the ShopWatcher application."""

import asyncio
import sys

import aiosqlite
import cv2 as cv

from src.apps.shopwatcher.core import runtime_flags
from src.apps.shopwatcher.core.constants import SECONDARY_WINDOWS
from src.apps.shopwatcher.core.shared_events import (
    mute_ssim_prints,
    secondary_windows_spawned,
)
from src.apps.shopwatcher.core.shop_detector import ShopDetector
from src.apps.shopwatcher.core.socket_handler import ShopWatcherHandler
from src.connection.constants import (
    STOP_SUBPROCESS_MESSAGE,
    STREAMERBOT_WS_URL,
    SUBPROCESSES_PORTS,
)
from src.connection.websocket_client import WebSocketClient
from src.core.termwm import TerminalWindowManager
from src.utils.helpers import construct_script_name, print_countdown
from src.utils.logging_utils import setup_logger
from src.utils.script_initializer import setup_script

PORT = SUBPROCESSES_PORTS["shopwatcher"]
SCRIPT_NAME = construct_script_name(__file__)

logger = setup_logger(SCRIPT_NAME)
twm = TerminalWindowManager()


async def run_main_task(
    conn: aiosqlite.Connection, slot: int, shopwatcher: ShopDetector, write: bool
) -> None:
    """Run the main scanning and notification task."""
    mute_ssim_prints.set()
    main_task = asyncio.create_task(shopwatcher.scan_for_shop_and_notify(write=write))
    await secondary_windows_spawned.wait()
    await twm.adjust_secondary_windows(conn, slot, SECONDARY_WINDOWS)
    mute_ssim_prints.clear()
    await main_task


async def main(write: bool) -> None:
    """Get this shit going."""
    socket_server_task = None
    slots_db_conn = None
    try:
        slots_db_conn, slot = await setup_script(SCRIPT_NAME)
        if slot is None:
            logger.error("No slot available, exiting.")
            return

        socket_server_handler = ShopWatcherHandler(
            port=PORT, stop_message=STOP_SUBPROCESS_MESSAGE, logger=logger
        )
        socket_server_task = asyncio.create_task(
            socket_server_handler.run_socket_server()
        )

        ws_client = WebSocketClient(STREAMERBOT_WS_URL, logger)
        await ws_client.establish_connection()

        shopwatcher = ShopDetector(socket_server_handler, logger, ws_client)

        await run_main_task(slots_db_conn, slot, shopwatcher, write=write)

    except Exception as e:
        print(f"Unexpected error of type: {type(e).__name__}: {e}")
        logger.exception("Unexpected error")
        raise

    finally:
        if socket_server_task:
            socket_server_task.cancel()
            await socket_server_task
        if slots_db_conn:
            await slots_db_conn.close()
        cv.destroyAllWindows()


if __name__ == "__main__":
    sysargs = sys.argv[1:]
    write_mode = "--write" in sysargs
    runtime_flags.always_react = "--always" in sysargs
    runtime_flags.react_fast = "--fast" in sysargs
    asyncio.run(main(write_mode))
    print_countdown()
