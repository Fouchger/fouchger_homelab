# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/constants.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Centralised defaults and supported values.
# Developer notes:
# - Identity values are environment-overridable to avoid hardcoding.
# =============================================================================

from __future__ import annotations

import os

# Identity
APP_DISPLAY_NAME: str = os.environ.get("FHL_APP_DISPLAY_NAME", "Fouchger HomeLab")
APP_SLUG: str = os.environ.get("FHL_APP_SLUG", "fouchger-homelab")

# Files
CONFIG_FILE_NAME: str = "config.toml"
LOG_FILE_NAME: str = f"{APP_SLUG}.log"

# Logging defaults
DEFAULT_LOG_LEVEL: str = "INFO"
DEFAULT_CONSOLE_LOG_LEVEL: str = "WARNING"
SUPPORTED_LOG_LEVELS = ("CRITICAL", "ERROR", "WARNING", "INFO", "DEBUG")
