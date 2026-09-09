from pathlib import Path

from src.utils.logging_utils import setup_logger

LOG_DIR = Path(__file__).resolve().parent / "logs"
logger = setup_logger("generate-icons", log_dir=LOG_DIR)
