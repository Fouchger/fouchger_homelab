"""web_app.py
Notes:
- Web entrypoint for Textual `serve`.
- Provides an importable factory so Textual can construct the App without CLI glue.
"""

from __future__ import annotations

from .app import HomelabApp
from .paths import AppPaths
from .config import AppConfig
from .logging_setup import configure_logging


def make_app() -> HomelabApp:
    """Factory used by `textual serve`."""
    paths = AppPaths.from_home("fouchger_homelab")
    paths.ensure()
    configure_logging(paths.logs_dir)

    config_path = paths.config_dir / "config.yml"
    cfg = AppConfig.load(config_path)

    return HomelabApp(paths=paths, config=cfg)
