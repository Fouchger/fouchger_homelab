# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/paths.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Resolve per-user config/log paths.
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from platformdirs import user_config_dir, user_log_dir

from fhl_menu.constants import APP_SLUG, CONFIG_FILE_NAME, LOG_FILE_NAME


@dataclass(frozen=True)
class AppPaths:
    config_dir: Path
    log_dir: Path
    config_path: Path
    log_path: Path


def get_app_paths(app_slug: str = APP_SLUG) -> AppPaths:
    config_dir = Path(user_config_dir(app_slug))
    log_dir = Path(user_log_dir(app_slug))
    return AppPaths(
        config_dir=config_dir,
        log_dir=log_dir,
        config_path=config_dir / CONFIG_FILE_NAME,
        log_path=log_dir / LOG_FILE_NAME,
    )
