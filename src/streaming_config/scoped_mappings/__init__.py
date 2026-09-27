"""Generation of per-consumer scoped mapping files (ports, paths)."""

from src.streaming_config.scoped_mappings.paths import PATH_RULES
from src.streaming_config.scoped_mappings.ports import PORTS_SOURCE, collect_ports_rules
from src.streaming_config.scoped_mappings.writer import (
    CONSUMER_OUTPUTS,
    write_consumer_files,
)

__all__ = [
    "CONSUMER_OUTPUTS",
    "PATH_RULES",
    "PORTS_SOURCE",
    "collect_rules",
    "write_consumer_files",
]
