# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/logging_setup.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Logging configuration (rotating file logs + console logs).
# Developer notes:
# - File logging is always enabled.
# - Console logging is intentionally less chatty by default.
# =============================================================================

from __future__ import annotations

import logging
from logging.handlers import RotatingFileHandler
from pathlib import Path

from rich.logging import RichHandler

from fhl_menu.constants import DEFAULT_CONSOLE_LOG_LEVEL


def configure_logging(
    *,
    log_path: Path,
    file_log_level: str,
    console_log_level: str = DEFAULT_CONSOLE_LOG_LEVEL,
    max_bytes: int = 2_000_000,
    backup_count: int = 5,
) -> None:
    log_path.parent.mkdir(parents=True, exist_ok=True)

    root = logging.getLogger()
    root.setLevel("DEBUG")

    # Prevent duplicate handlers on re-run
    for handler in list(root.handlers):
        root.removeHandler(handler)

    file_handler = RotatingFileHandler(
        filename=str(log_path),
        maxBytes=max_bytes,
        backupCount=backup_count,
        encoding="utf-8",
    )
    file_handler.setLevel(file_log_level)
    file_handler.setFormatter(
        logging.Formatter(
            fmt="%(asctime)s %(levelname)s %(name)s %(message)s",
            datefmt="%Y-%m-%d %H:%M:%S",
        )
    )

    console_handler = RichHandler(
        rich_tracebacks=True,
        markup=False,
        show_time=True,
        show_level=True,
        show_path=False,
    )
    console_handler.setLevel(console_log_level)

    root.addHandler(file_handler)
    root.addHandler(console_handler)


def get_logger(name: str) -> logging.Logger:
    return logging.getLogger(name)
