"""Project-wide constant values."""

from src.config.settings import PROJECT_ROOT_PATH

# General project paths
APPS_DIR_PATH = PROJECT_ROOT_PATH / "src" / "apps"

# Temp project paths
TEMP_DIR_PATH = PROJECT_ROOT_PATH / "temp"
PROJECT_CONFIG_DIR_PATH = PROJECT_ROOT_PATH / "config"
LOG_DIR_PATH = TEMP_DIR_PATH / "logs"
LOCK_FILES_DIR_PATH = TEMP_DIR_PATH / "lock_files"
COMMON_LOGS_FILE_PATH = LOG_DIR_PATH / "all_logs.log"
