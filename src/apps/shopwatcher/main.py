"""Main entry point for the ShopWatcher application (Qt GUI)."""

import asyncio
import contextlib
import sys

import aiosqlite
import qasync
from PySide6.QtWidgets import QApplication

from src.apps.shopwatcher.core import runtime_flags
from src.apps.shopwatcher.core.constants import SECONDARY_WINDOWS
from src.apps.shopwatcher.core.shop_detector import ShopDetector
from src.apps.shopwatcher.core.socket_handler import ShopWatcherHandler
from src.apps.shopwatcher.gui.main_window import MainWindow
from src.apps.shopwatcher.gui.qt_io import (
    LogBridge,
    QtLogHandler,
    QtStream,
    attach_to_loggers,
)
from src.connection.constants import (
    STOP_SUBPROCESS_MESSAGE,
    STREAMERBOT_WS_URL,
    SUBPROCESSES_PORTS,
)
from src.connection.websocket_client import WebSocketClient
from src.utils.helpers import construct_script_name
from src.utils.logging_utils import setup_logger
from src.utils.script_initializer import setup_script

PORT = SUBPROCESSES_PORTS["shopwatcher"]
SCRIPT_NAME = construct_script_name(__file__)

logger = setup_logger(SCRIPT_NAME)


async def run_shopwatcher(
    window: MainWindow, slots_db_conn: aiosqlite.Connection, *, write: bool
) -> None:
    socket_server_task = None
    try:
        socket_server_handler = ShopWatcherHandler(
            port=PORT, stop_message=STOP_SUBPROCESS_MESSAGE, logger=logger
        )
        socket_server_task = asyncio.create_task(
            socket_server_handler.run_socket_server()
        )

        ws_client = WebSocketClient(STREAMERBOT_WS_URL, logger)
        await ws_client.establish_connection()

        shopwatcher = ShopDetector(socket_server_handler, logger, ws_client, window)
        await shopwatcher.scan_for_shop_and_notify(write=write)

    except asyncio.CancelledError:
        raise
    except Exception as e:
        print(f"Unexpected error of type: {type(e).__name__}: {e}")
        logger.exception("Unexpected error")
        raise
    finally:
        if socket_server_task:
            socket_server_task.cancel()
            with contextlib.suppress(asyncio.CancelledError):
                await socket_server_task
        await slots_db_conn.close()


async def amain(window: MainWindow, *, write: bool) -> None:
    closed = asyncio.Event()
    window.closed.connect(closed.set)

    slots_db_conn = None
    slots_db_conn, slot = await setup_script(
        SCRIPT_NAME, title_setter=window.setWindowTitle
    )
    if slot is None:
        logger.error("No slot available, exiting.")
        return

    task = asyncio.create_task(
        run_shopwatcher(window, slots_db_conn=slots_db_conn, write=write)
    )
    closed_wait = asyncio.create_task(closed.wait())
    done, _ = await asyncio.wait(
        {task, closed_wait}, return_when=asyncio.FIRST_COMPLETED
    )

    if task in done:
        error = None if task.cancelled() else task.exception()
        if error:
            print(f"ShopWatcher task ended with: {error!r}")
            print("ShopWatcher stopped. Close the window to exit.")
            await closed.wait()
        else:
            logger.info("ShopWatcher stopped cleanly, closing window.")
            window.close()
    else:
        task.cancel()
        with contextlib.suppress(asyncio.CancelledError):
            await task

    closed_wait.cancel()


def run(*, write: bool) -> None:
    app = QApplication(sys.argv)
    app.setQuitOnLastWindowClosed(False)  # amain decides when to finish
    loop = qasync.QEventLoop(app)
    asyncio.set_event_loop(loop)

    bridge = LogBridge()
    sys.stdout = QtStream(bridge, sys.__stdout__)
    sys.stderr = QtStream(bridge, sys.__stderr__)
    attach_to_loggers(QtLogHandler(bridge))

    window = MainWindow(bridge, [w.name for w in SECONDARY_WINDOWS])
    window.show()

    try:
        with loop:
            loop.run_until_complete(amain(window, write=write))
    finally:
        sys.stdout, sys.stderr = sys.__stdout__, sys.__stderr__


if __name__ == "__main__":
    sysargs = sys.argv[1:]
    runtime_flags.always_react = "--always" in sysargs
    runtime_flags.react_fast = "--fast" in sysargs
    run(write="--write" in sysargs)
