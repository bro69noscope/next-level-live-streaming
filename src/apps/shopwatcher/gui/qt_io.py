"""Route prints and log records into the GUI from any thread."""

import contextlib
import logging
import re

from PySide6.QtCore import QObject, Signal

ANSI_RE = re.compile(r"\x1b\[[0-9;]*[A-Za-z]")


class LogBridge(QObject):
    """Any thread emits, GUI thread receives (queued connection)."""

    text = Signal(str)  # print() and stderr
    log = Signal(str)  # logging records


class QtStream:
    """File-like object replacing sys.stdout / sys.stderr."""

    encoding = "utf-8"

    def __init__(self, bridge: LogBridge, original=None) -> None:
        self._bridge = bridge
        self._original = original  # tee to real console, may be None (pythonw)

    def write(self, s: str) -> int:
        if self._original:
            with contextlib.suppress(Exception):
                self._original.write(s)
        if s:
            self._bridge.text.emit(ANSI_RE.sub("", s))
        return len(s)

    def flush(self) -> None:
        if self._original:
            with contextlib.suppress(Exception):
                self._original.flush()

    def isatty(self) -> bool:
        return False


class QtLogHandler(logging.Handler):
    def __init__(self, bridge: LogBridge) -> None:
        super().__init__()
        self._bridge = bridge
        self.setFormatter(
            logging.Formatter("%(asctime)s %(levelname)-7s : %(message)s", "%H:%M:%S")
        )

    def emit(self, record: logging.LogRecord) -> None:
        try:
            self._bridge.log.emit(self.format(record) + "\n")
        except Exception:  # noqa: BLE001
            self.handleError(record)


def attach_to_loggers(handler: logging.Handler) -> None:
    """Attach to root, plus every existing logger that does not propagate."""
    logging.getLogger().addHandler(handler)
    for obj in list(logging.Logger.manager.loggerDict.values()):
        if isinstance(obj, logging.Logger) and not obj.propagate:
            obj.addHandler(handler)
