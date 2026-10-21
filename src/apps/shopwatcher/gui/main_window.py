"""Mother window: OpenCV previews on top, live log below."""

from pathlib import Path

import numpy as np
from PySide6.QtCore import Qt, Signal
from PySide6.QtGui import QFont, QImage, QPixmap, QTextCursor
from PySide6.QtWidgets import (
    QGridLayout,
    QGroupBox,
    QLabel,
    QMainWindow,
    QPlainTextEdit,
    QSizePolicy,
    QSplitter,
    QTabWidget,
    QVBoxLayout,
    QWidget,
)
from src.apps.shopwatcher.gui.qt_io import LogBridge

COLUMNS = 3
MAX_LOG_LINES = 5000
STYLESHEET_PATH = Path(__file__).with_suffix(".qss")


def to_qimage(frame: np.ndarray) -> QImage | None:
    if frame.dtype != np.uint8:
        f = frame.astype(np.float32)
        if f.size and f.max() <= 1.0:
            f *= 255
        frame = np.clip(f, 0, 255).astype(np.uint8)
    frame = np.ascontiguousarray(frame)
    h, w = frame.shape[:2]

    if frame.ndim == 2:
        fmt = QImage.Format.Format_Grayscale8
    elif frame.shape[2] == 3:
        fmt = QImage.Format.Format_BGR888
    elif frame.shape[2] == 4:
        fmt = QImage.Format.Format_ARGB32
    else:
        return None

    # copy() detaches from the numpy buffer
    return QImage(frame.data, w, h, frame.strides[0], fmt).copy()


class PreviewLabel(QLabel):
    """Aspect-preserving image label that shrinks and grows with the layout."""

    def __init__(self) -> None:
        super().__init__("waiting for frames...")
        self._pix: QPixmap | None = None
        self.setAlignment(Qt.AlignmentFlag.AlignCenter)
        self.setMinimumSize(40, 22)
        self.setSizePolicy(QSizePolicy.Policy.Ignored, QSizePolicy.Policy.Ignored)

    def set_image(self, img: QImage) -> None:
        self._pix = QPixmap.fromImage(img)
        self._rescale()

    def resizeEvent(self, event) -> None:  # noqa: N802
        super().resizeEvent(event)
        self._rescale()

    def _rescale(self) -> None:
        if self._pix is not None:
            self.setPixmap(
                self._pix.scaled(
                    self.size(),
                    Qt.AspectRatioMode.KeepAspectRatio,
                    Qt.TransformationMode.FastTransformation,
                )
            )


class MainWindow(QMainWindow):
    closed = Signal()

    def __init__(self, bridge: LogBridge, panel_names: list[str]) -> None:
        super().__init__()
        self._panels: dict[str, PreviewLabel] = {}
        self._status_labels: dict[str, QLabel] = {}
        self._mono = self._make_mono_font()

        self.setWindowTitle("ShopWatcher")
        self.resize(1200, 850)
        self.setStyleSheet(STYLESHEET_PATH.read_text(encoding="utf-8"))

        self._grid = QGridLayout()
        self.log = self._make_view()
        self.prints = self._make_view()
        self.tabs = self._build_tabs()
        self.status_box = self._build_status_box()
        self.setCentralWidget(self._build_splitter())

        for name in panel_names:
            self._add_panel(name)

        bridge.log.connect(self.append_log)
        bridge.text.connect(self.append_print)

    @staticmethod
    def _make_mono_font() -> QFont:
        font = QFont("Consolas")
        font.setPointSize(8)
        font.setStyleHint(QFont.StyleHint.Monospace)
        return font

    def _build_previews(self) -> QWidget:
        self._grid.setContentsMargins(2, 2, 2, 2)
        self._grid.setSpacing(2)
        previews = QWidget()
        previews.setLayout(self._grid)
        previews.setMinimumHeight(60)
        return previews

    def _build_status_box(self) -> QGroupBox:
        box = QGroupBox("Status")
        box.setObjectName("status")
        box.setSizePolicy(QSizePolicy.Policy.Preferred, QSizePolicy.Policy.Maximum)

        self._status_layout = QVBoxLayout(box)
        self._status_layout.setContentsMargins(6, 1, 6, 1)
        self._status_layout.setSpacing(0)
        return box

    def _build_splitter(self) -> QSplitter:
        splitter = QSplitter(Qt.Orientation.Vertical)
        splitter.setHandleWidth(3)
        splitter.addWidget(self._build_previews())
        splitter.addWidget(self.status_box)
        splitter.addWidget(self.tabs)
        splitter.setStretchFactor(0, 3)
        splitter.setStretchFactor(1, 0)
        splitter.setStretchFactor(2, 2)
        return splitter

    def _build_tabs(self) -> QTabWidget:
        tabs = QTabWidget()
        tabs.setDocumentMode(True)
        tabs.addTab(self.log, "Logs")
        tabs.addTab(self.prints, "Prints")
        tabs.currentChanged.connect(self._clear_unread)
        return tabs

    def _add_panel(self, name: str) -> PreviewLabel:
        label = PreviewLabel()
        box = QGroupBox(name)

        lay = QVBoxLayout(box)
        lay.setContentsMargins(2, 2, 2, 2)
        lay.addWidget(label)

        i = len(self._panels)
        self._grid.addWidget(box, i // COLUMNS, i % COLUMNS)
        self._panels[name] = label
        return label

    def show_frame(self, name: str, frame: np.ndarray) -> None:
        img = to_qimage(frame)
        if img is None:
            return
        panel = self._panels.get(name) or self._add_panel(name)
        panel.set_image(img)

    def set_status(self, key: str, text: str) -> None:
        label = self._status_labels.get(key)
        if label is None:
            label = QLabel()
            label.setFont(self._mono)
            label.setTextInteractionFlags(Qt.TextInteractionFlag.TextSelectableByMouse)
            self._status_layout.addWidget(label)
            self._status_labels[key] = label
        label.setText(text)

    def _make_view(self) -> QPlainTextEdit:
        view = QPlainTextEdit()
        view.setReadOnly(True)
        view.setMaximumBlockCount(MAX_LOG_LINES)
        view.setLineWrapMode(QPlainTextEdit.LineWrapMode.NoWrap)
        view.setFont(self._mono)
        return view

    def append_log(self, text: str) -> None:
        self._append(self.log, text)

    def append_print(self, text: str) -> None:
        self._append(self.prints, text)

    def _append(self, view: QPlainTextEdit, text: str) -> None:
        sb = view.verticalScrollBar()
        at_bottom = sb.value() >= sb.maximum() - 4

        cur = QTextCursor(view.document())
        cur.movePosition(QTextCursor.MoveOperation.End)
        cur.insertText(text)

        if at_bottom:
            sb.setValue(sb.maximum())

        idx = self.tabs.indexOf(view)
        label = self.tabs.tabText(idx)
        if idx != self.tabs.currentIndex() and not label.endswith(" •"):
            self.tabs.setTabText(idx, label + " •")

    def _clear_unread(self, idx: int) -> None:
        self.tabs.setTabText(idx, self.tabs.tabText(idx).removesuffix(" •"))

    def closeEvent(self, event) -> None:  # noqa: N802
        self.closed.emit()
        super().closeEvent(event)
