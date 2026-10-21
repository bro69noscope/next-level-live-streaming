import asyncio
import ctypes
import os
import time
from logging import Logger
from typing import Optional

import pygetwindow

VERIFY_DELAY_SECONDS = 0.15
MAX_ADJUST_ATTEMPTS = 3
_USER32 = ctypes.WinDLL("user32")


class WindowAdjuster:
    def __init__(self, logger: Logger) -> None:
        self.logger = logger

    async def find_window(
        self, title: str, timeout: int = 2
    ) -> Optional[pygetwindow.Win32Window]:
        start_time = time.time()
        duration = 0.0
        while duration < timeout:
            window = pygetwindow.getWindowsWithTitle(title)
            if window:
                return window[0]
            await asyncio.sleep(0.01)
            duration = time.time() - start_time
        self.logger.warning(f"Window <{title}> not found within {timeout}s.")
        return None

    @staticmethod
    def _geometry(window: pygetwindow.Win32Window) -> tuple[int, int, int, int]:
        """Current (width, height, x, y), same order as the properties tuples."""
        return (
            int(window.width),
            int(window.height),
            int(window.left),
            int(window.top),
        )

    @staticmethod
    def _dpi(window: pygetwindow.Win32Window) -> int | None:
        """The window's DPI, or None if unavailable (old Windows, invalid handle)."""
        try:
            dpi = int(_USER32.GetDpiForWindow(window._hWnd))  # noqa: SLF001
        except (AttributeError, OSError):
            return None
        return dpi or None

    async def _verify_geometry(
        self,
        title: str,
        window: pygetwindow.Win32Window,
        properties: tuple[int, int, int, int],
    ) -> None:
        """Re-read the geometry after a delay to catch the app overriding it."""
        await asyncio.sleep(VERIFY_DELAY_SECONDS)
        actual = self._geometry(window)
        if actual == properties:
            self.logger.debug(f"Window <{title}> geometry held: {actual}.")
        else:
            self.logger.warning(
                f"Window <{title}> geometry drifted after "
                f"{VERIFY_DELAY_SECONDS}s: requested={properties} actual={actual} "
                f"dpi={self._dpi(window)}."
            )

    async def adjust_window(
        self,
        title: str,
        properties: tuple[int, int, int, int],
        resize: bool = True,
        move: bool = True,
    ) -> None:
        window = await self.find_window(title)
        if window:
            matches = pygetwindow.getWindowsWithTitle(title)
            if len(matches) > 1:
                self.logger.warning(
                    f"Title <{title}> matched multiple ({len(matches)}) windows: "
                    f"{[m.title for m in matches]}; using the first one."
                )
            self.logger.debug(
                f"Window <{title}> hwnd={window._hWnd} "  # noqa: SLF001
                f"dpi={self._dpi(window)} before={self._geometry(window)} "
                f"requested={properties}"
            )
            window.restore()
            # Windows picks a window's DPI from the monitor holding most of it, so
            # the DPI can flip (and the app rescale itself) mid-adjustment, e.g.
            # when the resize makes it fit entirely on the target monitor. Apply
            # again until the geometry holds.
            for attempt in range(1, MAX_ADJUST_ATTEMPTS + 1):
                if move:
                    window.moveTo(properties[2], properties[3])
                if resize:
                    window.resizeTo(properties[0], properties[1])
                geometry = self._geometry(window)
                self.logger.debug(
                    f"Window <{title}> attempt {attempt}: {geometry} "
                    f"dpi={self._dpi(window)}"
                )
                if geometry == properties:
                    break
            self.logger.info(f"Window <{title}> adjusted successfully.")
            await self._verify_geometry(title, window, properties)
        else:
            self.logger.error(f"Was not able to adjust window {title}.")

    def set_window_title(self, title: str) -> None:
        os.system(f"title {title}")
        self.logger.debug(f"Window title set to <{title}>.")
