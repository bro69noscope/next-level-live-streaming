from logging import Logger
from typing import Callable, Optional

import aiosqlite
import src.core.termwm.slots_db_handler as sdh
from src.core.termwm.core.constants import (
    MAIN_WINDOW_HEIGHT,
    MAIN_WINDOW_WIDTH,
    SERVER_WINDOW_NAME,
    WINDOW_NAME_SUFFIX,
)
from src.core.termwm.core.types import SecondaryWindow, WinType
from src.core.termwm.helpers.window_adjuster import WindowAdjuster
from src.core.termwm.helpers.window_properties_calculator import (
    WindowPropertiesCalculator,
)


class WindowManager:
    def __init__(
        self,
        adjuster: WindowAdjuster,
        calculator: WindowPropertiesCalculator,
        logger: Logger,
    ) -> None:
        self.adjuster = adjuster
        self.calculator = calculator
        self.logger = logger

    @staticmethod
    def _generate_window_data(
        main_title: str | None,
        secondary_windows: list[SecondaryWindow] | None = None,
    ) -> list[tuple[str, int, int]]:
        data = []
        if main_title:
            data = [(main_title, MAIN_WINDOW_WIDTH, MAIN_WINDOW_HEIGHT)]
        if secondary_windows:
            for window in secondary_windows:
                sw_tuple = (window.name, window.width, window.height)
                data.append(sw_tuple)
        return data

    async def initially_manage_secondary_windows(
        self,
        conn: aiosqlite.Connection,
        slot: int,
        secondary_windows: list[SecondaryWindow],
    ) -> None:
        data = self._generate_window_data(None, secondary_windows)
        await sdh.occupy_slot_with_data(conn, slot, data, start_index=1)
        properties = self.calculator.calculate_secondary_window_properties(
            slot, secondary_windows
        )
        for window, props in zip(secondary_windows, properties):
            await self.adjuster.adjust_window(window.name, props)
        self.logger.info(f"Secondary windows managed for slot {slot}.")

    async def initially_manage_window(
        self,
        conn: aiosqlite.Connection,
        window_type: WinType,
        window_name: str,
        *,
        title_setter: Callable[[str], None] | None = None,
    ) -> tuple[Optional[int], str]:
        """Main method to manage the main window of the script."""

        window_name = WINDOW_NAME_SUFFIX + window_name
        slot, title = await self._assign_slot_and_name_window(
            conn, window_type, window_name, title_setter
        )

        properties = self.calculator.calculate_main_window_properties(window_type, slot)
        await self.adjuster.adjust_window(title, properties)

        if window_type == WinType.ACCEPTED and slot is not None:
            data = self._generate_window_data(title)
            await sdh.occupy_slot_with_data(conn, slot, data)

        return slot, window_name

    async def _assign_slot_and_name_window(
        self,
        conn: aiosqlite.Connection,
        window_type: WinType,
        window_name: str,
        title_setter: Callable[[str], None] | None = None,
    ) -> tuple[Optional[int], str]:
        set_title = title_setter or self.adjuster.set_window_title
        if window_type == WinType.ACCEPTED:
            slot_id = await sdh.get_first_free_slot(conn)
            if slot_id is None:
                raise ValueError("No available slot for an accepted window.")
            title = window_name
            set_title(title)

        elif window_type == WinType.DENIED:
            slot_id = await sdh.occupy_first_free_denied_slot(conn)
            if slot_id is None:
                raise ValueError("No available slot for a denied window.")
            title = f"{window_name}_denied({slot_id})"
            set_title(title)

        elif window_type == WinType.SERVER:
            slot_id = None  # Server doesn't occupy a slot in the DB
            title = SERVER_WINDOW_NAME
            set_title(title)

        return slot_id, title
