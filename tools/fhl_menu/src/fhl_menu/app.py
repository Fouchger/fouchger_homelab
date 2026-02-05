# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/app.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: UI selection and app orchestration (TUI vs CLI).
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from fhl_menu.config import AppConfig
from fhl_menu.logging_setup import get_logger
from fhl_menu.ui_cli import CliContext, run_cli_menu
from fhl_menu.ui_textual import FhlMenuApp, TuiContext
from fhl_menu.util import TerminalCapabilities

log = get_logger(__name__)


@dataclass(frozen=True)
class AppContext:
    capabilities: TerminalCapabilities
    config_path: Path
    log_path: Path
    force_cli: bool = False
    force_tui: bool = False


def should_use_tui(ctx: AppContext) -> bool:
    if ctx.force_cli:
        return False
    if ctx.force_tui:
        return True

    c = ctx.capabilities
    if not c.is_tty:
        return False
    if c.is_dumb:
        return False

    # 256 colour is preferred but not strictly required for functionality.
    return True


def run_app(ctx: AppContext, config: AppConfig) -> int:
    if should_use_tui(ctx):
        log.info("Launching Textual TUI")
        tui_ctx = TuiContext(
            capabilities=ctx.capabilities,
            config_path=ctx.config_path,
            log_path=ctx.log_path,
        )
        return FhlMenuApp(ctx=tui_ctx, config=config).run()

    log.warning("Launching CLI fallback menu")
    cli_ctx = CliContext(
        capabilities=ctx.capabilities,
        config_path=ctx.config_path,
        log_path=ctx.log_path,
    )
    return run_cli_menu(cli_ctx, config)
