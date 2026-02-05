# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/bootstrap.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Bootstrap flow (args, paths, config, logging, run).
# Developer notes:
# - All modules receive required values via arguments.
# - No hidden globals beyond environment-overridable identity.
# =============================================================================

from __future__ import annotations

import argparse

from fhl_menu.app import AppContext, run_app
from fhl_menu.config import load_config
from fhl_menu.logging_setup import configure_logging, get_logger
from fhl_menu.paths import get_app_paths
from fhl_menu.util import detect_terminal_capabilities

log = get_logger(__name__)


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(prog="fhl-menu", add_help=True)
    mode = parser.add_mutually_exclusive_group()
    mode.add_argument("--tui", action="store_true", help="Force Textual UI")
    mode.add_argument("--cli", action="store_true", help="Force CLI mode")
    return parser


def run() -> int:
    args = build_parser().parse_args()

    paths = get_app_paths()
    capabilities = detect_terminal_capabilities()
    config = load_config(paths.config_path)

    configure_logging(
        log_path=paths.log_path,
        file_log_level=config.log_level,
    )

    log.info("Bootstrap complete")
    ctx = AppContext(
        capabilities=capabilities,
        config_path=paths.config_path,
        log_path=paths.log_path,
        force_cli=bool(args.cli),
        force_tui=bool(args.tui),
    )
    return run_app(ctx, config)
