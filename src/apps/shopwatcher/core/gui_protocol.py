"""What the core logic needs from the GUI, without importing Qt."""

from typing import Protocol

import numpy as np

SSIM_KEY = "ssim"
SHOP_KEY = "shop"


class Gui(Protocol):
    """Implemented by the main window; keeps the core free of Qt imports."""

    def show_frame(self, name: str, frame: np.ndarray) -> None:
        """Show the latest frame in the panel called `name`."""

    def set_status(self, key: str, text: str) -> None:
        """Set the live readout for `key`."""
