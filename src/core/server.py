"""Websocket server made for listening to a basic StreamDeck Websocket client plugin.

This is where the scripts will be launched from... and sometimes
communicated with, although this is the kind of complex stuff I'll worry
about later.
"""

import asyncio
from collections.abc import Awaitable, Callable

import aiosqlite
import websockets
from websockets.asyncio.server import ServerConnection

from src.config.settings import PROJECT_ROOT_PATH, VENV_PYTHON
from src.connection.constants import STOP_SUBPROCESS_MESSAGE, SUBPROCESSES_PORTS
from src.core.constants import (
    APPS_DIR_PATH,
    LOCK_FILES_DIR_PATH,
)
from src.core.termwm import (
    TERMINAL_WINDOW_SLOTS_DB_FILE_PATH,
    TerminalWindowManager,
    WinType,
)
from src.core.termwm import (
    slots_db_handler as sdh,
)
from src.utils.helpers import construct_script_name
from src.utils.logging_utils import setup_logger

twm = TerminalWindowManager()

SCRIPT_NAME = construct_script_name(__file__)
MIN_MSG_LENGTH = 2

logger = setup_logger(SCRIPT_NAME)


async def _manage_subprocess(message: str) -> None:
    parts = message.split(maxsplit=1)
    if not len(parts) >= MIN_MSG_LENGTH:
        error_msg = (
            "Invalid message format, must be at least two separate words: target,"
            " instructions"
        )
        logger.error(error_msg)
        raise ValueError(error_msg)

    target = parts[0]
    instructions = parts[1].strip()
    if target not in SUBPROCESSES_PORTS:
        error_msg = f" Unknown target {target} not in {list(SUBPROCESSES_PORTS.keys())}"
        logger.error(error_msg)
        raise ValueError(error_msg)

    if instructions == "start":
        # Open the process in a new separate cli window: this is done to be
        # able to manipulate the position of the script's terminal with the
        # terminal window manager module.

        script_path = APPS_DIR_PATH / target / "main.py"

        command = (
            f'start /min cmd /k "'
            f"cd /d {PROJECT_ROOT_PATH} && "
            f"set PYTHONPATH={PROJECT_ROOT_PATH} && "
            f'{VENV_PYTHON} {script_path}"'
        )

        await asyncio.create_subprocess_shell(
            command,
            cwd=str(PROJECT_ROOT_PATH),
        )

        print(f"Started {target}")
        logger.info(f"Started subprocess {target}")

    elif instructions == "stop":
        await send_message_to_subprocess_socket(
            STOP_SUBPROCESS_MESSAGE, SUBPROCESSES_PORTS[target]
        )

    elif instructions == "unlock":
        # Check for an ACK from the subprocess SOCK server. If there is one,
        # it means the subprocess is running and should not be attempted to
        # be unlocked.
        answer = await send_message_to_subprocess_socket(
            "Check for server ACK", SUBPROCESSES_PORTS[target]
        )
        if not answer:
            lock_file = LOCK_FILES_DIR_PATH / f"{target}.lock"
            print(f"Checking for {lock_file}")
            if lock_file.exists():
                lock_file.unlink()
                print(f"Found and removed lock for {target}")
            else:
                print("No lock found here, traveler.")
        else:
            print(f"{target} seems to be running, cannot unlock")


async def _manage_windows(conn: aiosqlite.Connection, message: str) -> None:
    if message == "refit":
        await twm.refit_all_windows(conn)
    elif message == "refit_server":
        await twm.bring_windows_to_foreground(conn, server=True)
    else:
        print("Invalid windows path message, does not fit any use case")


async def _manage_database(conn: aiosqlite.Connection, message: str) -> None:
    if message == "free all slots":
        await sdh.free_all_slots(conn, verbose=True)
        await sdh.free_all_denied_slots(conn)
    else:
        print("Invalid database path message, does not fit any use")


def create_websocket_handler(
    conn: aiosqlite.Connection,
) -> Callable[[ServerConnection], Awaitable[None]]:
    """Create a websocket handler function with access to given database connection."""

    async def websocket_handler(websocket: ServerConnection) -> None:
        async for raw_message in websocket:
            message = (
                raw_message.decode("utf-8")
                if isinstance(raw_message, bytes)
                else raw_message
            )

            path = websocket.request.path if websocket.request else "/"
            print(f"Received: '{message}' on path: {path}")

            if path == "/subprocess":
                await _manage_subprocess(message)

            elif path == "/windows":
                await _manage_windows(conn, message)

            elif path == "/database":
                await _manage_database(conn, message)

            elif path == "/test":  # Path to test stuff
                if message == "get windows":
                    windows_names = await sdh.get_all_names(conn)
                    print(f"Windows in slot DB: {windows_names}")
                elif message == "hi bitch":
                    print("I aint ur bitch")

    return websocket_handler


async def send_message_to_subprocess_socket(
    message: str, port: int, host: str = "localhost"
) -> str:
    """Client function to send messages to subprocesses servers."""
    try:
        reader, writer = await asyncio.open_connection(host, port)

        writer.write(message.encode("utf-8"))
        print(f"SOCK: Sent: {message}")
        data = await reader.read(1024)
        msg = data.decode("utf-8")
        print(f"SOCK: Received: {msg}")

        print("SOCK: closing connection")
        writer.close()
        await writer.wait_closed()

    except OSError as e:
        msg = f"SOCK: Could not connect to {host}:{port}"
        print(e)
    return msg


async def main() -> None:
    """Entry point, duh."""
    conn = await sdh.create_connection(TERMINAL_WINDOW_SLOTS_DB_FILE_PATH)
    if conn is None:
        logger.warning("Could not connect to the windows slots database.")
        print("Could not connect to the windows slots database.")
        return
    await twm.adjust_terminal_window(conn, WinType.SERVER, "SERVER")
    websocket_server = await websockets.serve(
        create_websocket_handler(conn), "localhost", 50000
    )
    try:
        await asyncio.Future()
    except KeyboardInterrupt:
        logger.info("Server stopping due to keyboard interrupt")
    finally:
        websocket_server.close()
        await websocket_server.wait_closed()


if __name__ == "__main__":
    asyncio.run(main())
