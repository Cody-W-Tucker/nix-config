"""Miniflux auto-curator package.

Submodules:
- ``titles``: pure-text title normalization and reference-title gating.
- ``clients``: state file I/O, embedding API calls, Karakeep HTTP client.
- ``scoring``: reference selection and batch entry scoring.
- ``main``: CLI entry point (reads env, orchestrates a run).

Heavy runtime deps (miniflux, numpy) are loaded lazily so that
``from curator.titles import ...`` works in test contexts without those
packages installed.
"""


def __getattr__(name):
    if name == "main":
        from .main import main
        return main
    raise AttributeError(f"module {__name__!r} has no attribute {name!r}")


__all__ = ["main"]
