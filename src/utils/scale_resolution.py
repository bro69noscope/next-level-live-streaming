"""Utilities for scaling a screen region across different display resolutions."""

from dataclasses import dataclass, field

import mss


def get_screen_resolution(monitor_index: int = 1) -> tuple[int, int]:
    """Get the resolution of a monitor.

    Args:
        monitor_index: mss monitor index. 0 is the virtual union of all
            monitors, 1 is the primary, 2+ are additional monitors in order.

    """
    with mss.mss() as sct:
        monitor = sct.monitors[monitor_index]
    return monitor["width"], monitor["height"]


@dataclass(frozen=True)
class ScaledArea:
    """Computes a screen capture area for any resolution from a known-good
    reference area, anchored to the right edge (for UI elements that stick
    to the right side of the screen regardless of resolution).

    Known exact areas for specific resolutions can be supplied to bypass
    the scaling formula when pixel-perfect calibration is available.
    """

    ref_width: int
    ref_height: int
    ref_left: int
    ref_top: int
    ref_area_width: int
    ref_area_height: int
    known_areas: dict[tuple[int, int], dict[str, int]] = field(default_factory=dict)

    def _ref_right_offset(self) -> int:
        return self.ref_width - self.ref_left - self.ref_area_width

    def resolve(self, screen_width: int, screen_height: int) -> dict[str, int]:
        """Get the capture area for a given screen resolution.

        Args:
            screen_width: Width of the target screen in pixels.
            screen_height: Height of the target screen in pixels.

        """
        key = (screen_width, screen_height)
        if key in self.known_areas:
            return self.known_areas[key]

        scale = screen_width / self.ref_width
        width = round(self.ref_area_width * scale)
        height = round(self.ref_area_height * scale)
        left = screen_width - round(self._ref_right_offset() * scale) - width
        top = round(self.ref_top * scale)
        return {"left": left, "top": top, "width": width, "height": height}

    def resolve_for_current_screen(self, monitor_index: int = 1) -> dict[str, int]:
        """Get the capture area for the current screen's resolution.

        Args:
            monitor_index: mss monitor index (see get_screen_resolution).

        """
        screen_width, screen_height = get_screen_resolution(monitor_index)
        return self.resolve(screen_width, screen_height)
