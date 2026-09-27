"""Constants for the shopwatcher app."""

from src.core.termwm import SecondaryWindow
from src.utils.scale_resolution import ScaledArea

# Window config for TerminalWindowManager
SECONDARY_WINDOWS = [SecondaryWindow("opencv_shop_scanner", 150, 100)]

_SHOP_ICON_AREA = ScaledArea(
    ref_width=2560,
    ref_height=1440,
    ref_left=2461,
    ref_top=67,
    ref_area_width=40,
    ref_area_height=47,
    known_areas={(2560, 1440): {"left": 2461, "top": 67, "width": 40, "height": 47}},
)

SCREEN_CAPTURE_AREA = _SHOP_ICON_AREA.resolve_for_current_screen()
