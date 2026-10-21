"""What the core logic needs from whatever displays its state (the GUI)."""

from typing import Protocol

import numpy as np

SSIM_KEY = "ssim"
SHOP_KEY = "shop"


class Display(Protocol):
    """Implemented by the GUI window; keeps the core free of Qt imports."""

    def gui_show_frame(self, name: str, frame: np.ndarray) -> None:
        """Show the latest frame in the panel called `name`."""

    def gui_set_status(self, key: str, text: str) -> None:
        """Set the live readout for `key`."""
