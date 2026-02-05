# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/ui_cli.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: CLI fallback menu for constrained terminals.
# Developer notes:
# - Mirrors the same options as the Textual UI.
# - No extra prompt dependencies to keep installs reliable.
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from fhl_menu.config import AppConfig, save_config
from fhl_menu.constants import APP_DISPLAY_NAME, SUPPORTED_LOG_LEVELS
from fhl_menu.doctor import build_doctor_report
from fhl_menu.logging_setup import get_logger
from fhl_menu.util import TerminalCapabilities

log = get_logger(__name__)


@dataclass(frozen=True)
class CliContext:
    capabilities: TerminalCapabilities
    config_path: Path
    log_path: Path


def _prompt_choice(prompt: str, choices: list[str]) -> str:
    while True:
        print(prompt)
        for i, c in enumerate(choices, start=1):
            print(f"  {i}) {c}")
        raw = input("Select an option: ").strip()
        if raw.isdigit():
            idx = int(raw)
            if 1 <= idx <= len(choices):
                return choices[idx - 1]
        print("Invalid selection. Try again.\n")


def _tail_file(path: Path, max_lines: int = 200) -> str:
    if not path.exists():
        return f"Log file not found: {path}"
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(lines[-max_lines:])


def run_cli_menu(ctx: CliContext, config: AppConfig) -> int:
    log.info("Starting CLI menu")

    menu_items = ["Settings (Logging)", "View logs", "Doctor", "Exit"]

    while True:
        selection = _prompt_choice(f"{APP_DISPLAY_NAME} (CLI mode)", menu_items)

        if selection == "Settings (Logging)":
            new_level = _prompt_choice(
                f"Current log level: {config.log_level}. Choose new level:",
                list(SUPPORTED_LOG_LEVELS),
            )
            config = AppConfig(log_level=new_level)
            save_config(ctx.config_path, config)
            log.warning("Log level updated to %s (applies on next start)", new_level)
            print(f"Saved. New log level: {new_level}. Restart recommended.\n")

        elif selection == "View logs":
            print("\n--- Last log lines ---")
            print(_tail_file(ctx.log_path))
            print("--- End ---\n")

        elif selection == "Doctor":
            report = build_doctor_report(
                capabilities=ctx.capabilities,
                config_path=ctx.config_path,
                log_path=ctx.log_path,
            )
            print("\n" + report.text + "\n")

        elif selection == "Exit":
            log.info("Exiting CLI menu")
            return 0
