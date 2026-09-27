from pathlib import Path

_APP_DIR = Path(__file__).resolve().parents[1]
_DATA_DIR = _APP_DIR / "data"
_OPENCV_DIR = _DATA_DIR / "opencv"
_WS_REQUESTS_DIR = _DATA_DIR / "ws_requests"
_OBS_DIR = _DATA_DIR / "obs"

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
