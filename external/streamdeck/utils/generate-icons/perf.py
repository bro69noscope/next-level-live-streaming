import time
from contextlib import contextmanager

_totals: dict[str, float] = {}


@contextmanager
def timed(label: str):
    start = time.perf_counter()
    try:
        yield
    finally:
        _totals[label] = _totals.get(label, 0.0) + (time.perf_counter() - start)


def print_summary():
    if not _totals:
        return
    width = max(len(k) for k in _totals)
    print("\n--- perf summary ---")
    for label, secs in sorted(_totals.items(), key=lambda kv: -kv[1]):
        print(f"{label:<{width}}  {secs * 1000:8.1f} ms")
