from src.apps.shopwatcher.core.paths import TIME_SINCE_SHOP_OPENED_TXT_PATH
from src.streaming_config.types import Rule

PATH_RULES: list[Rule] = [
    Rule(
        field_name="file",
        value=str(TIME_SINCE_SHOP_OPENED_TXT_PATH),
        token="{{SHOPWATCHER_TIME_SINCE_SHOP_OPENED_TXT_PATH}}",
        consumers=frozenset({"streamerbot"}),
    ),
]
