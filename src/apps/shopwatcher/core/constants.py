"""Constants for the shopwatcher app."""

from src.config.settings import PROJECT_ROOT_PATH
from src.core.termwm import SecondaryWindow
from src.utils.scale_resolution import ScaledArea

# Base paths
_BASE_DIR = PROJECT_ROOT_PATH / "data" / "apps" / "shopwatcher"
_OPENCV_DIR = _BASE_DIR / "opencv"
_WS_REQUESTS_DIR = _BASE_DIR / "ws_requests"
_OBS_DIR = _BASE_DIR / "obs"

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

# OpenCV templates
SHOP_TEMPLATE_IMAGE_PATH = _OPENCV_DIR / "shop_top_right_icon.jpg"

# WebSocket requests
BRB_BUYING_MILK_SHOW_PATH = _WS_REQUESTS_DIR / "brb_buying_milk_show.json"
BRB_BUYING_MILK_HIDE_PATH = _WS_REQUESTS_DIR / "brb_buying_milk_hide.json"
DSLR_HIDE_PATH = _WS_REQUESTS_DIR / "dslr_hide.json"
DSLR_SHOW_PATH = _WS_REQUESTS_DIR / "dslr_show.json"
DISPLAY_TIME_SINCE_SHOP_OPENED_PATH = (
    _WS_REQUESTS_DIR / "display_time_since_shop_opened.json"
)

# OBS
TIME_SINCE_SHOP_OPENED_TXT_PATH = _OBS_DIR / "time_since_shop_opened.txt"
