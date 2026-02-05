# =============================================================================
# File: tools/fhl_menu/src/fhl_menu/ui_textual.py
# Project: Fouchger HomeLab Menu (fhl_menu)
# Purpose: Textual TUI (production-ready minimal menu).
# Options included (only these for now):
# - Settings (Logging level)
# - View logs
# - Doctor
# - Exit
# =============================================================================

from __future__ import annotations

from dataclasses import dataclass
from pathlib import Path

from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Button, Footer, Header, Select, Static, TextLog

from fhl_menu.config import AppConfig, save_config
from fhl_menu.constants import APP_DISPLAY_NAME, SUPPORTED_LOG_LEVELS
from fhl_menu.doctor import build_doctor_report
from fhl_menu.logging_setup import get_logger
from fhl_menu.util import TerminalCapabilities

log = get_logger(__name__)


@dataclass(frozen=True)
class TuiContext:
    capabilities: TerminalCapabilities
    config_path: Path
    log_path: Path


def _tail_file(path: Path, max_lines: int = 200) -> str:
    if not path.exists():
        return f"Log file not found: {path}"
    lines = path.read_text(encoding="utf-8", errors="replace").splitlines()
    return "\n".join(lines[-max_lines:])


class FhlMenuApp(App[int]):
    CSS = """
    Screen { padding: 1; }

    #main { height: auto; }

    #left {
        width: 42%;
        min-width: 36;
        border: round $primary;
        padding: 1;
        height: auto;
    }

    #right {
        width: 58%;
        border: round $primary;
        padding: 1;
        height: auto;
    }

    #title {
        content-align: center middle;
        text-style: bold;
        padding-bottom: 1;
    }

    #status { padding-top: 1; height: auto; }

    TextLog { height: 18; }

    .btnrow Button { margin-right: 1; }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("s", "settings", "Settings"),
        ("l", "view_logs", "View logs"),
        ("d", "doctor", "Doctor"),
    ]

    def __init__(self, *, ctx: TuiContext, config: AppConfig) -> None:
        super().__init__()
        self._ctx = ctx
        self._config = config
        self._output: TextLog | None = None
        self._level_select: Select[str] | None = None

    def compose(self) -> ComposeResult:
        yield Header(show_clock=True)

        with Horizontal(id="main"):
            with Vertical(id="left"):
                yield Static(APP_DISPLAY_NAME, id="title")
                yield Static(self._build_status_text(), id="status")
                yield Static("Settings (Logging)")
                self._level_select = Select(
                    options=[(lvl, lvl) for lvl in SUPPORTED_LOG_LEVELS],
                    value=self._config.log_level,
                    id="log_level_select",
                )
                yield self._level_select

                with Horizontal(classes="btnrow"):
                    yield Button("Save log level", id="save_log_level", variant="primary")
                    yield Button("Doctor", id="doctor", variant="default")
                    yield Button("View logs", id="view_logs", variant="default")
                    yield Button("Exit", id="exit", variant="error")

            with Vertical(id="right"):
                yield Static("Output")
                self._output = TextLog(highlight=True, markup=False)
                yield self._output

        yield Footer()

    def on_mount(self) -> None:
        log.info("Starting Textual menu")
        self._write_output("Ready. Use buttons or shortcuts (s, l, d, q).")

    def _build_status_text(self) -> str:
        c = self._ctx.capabilities
        return "\n".join(
            [
                "Mode: Textual (TUI)",
                f"TERM: {c.term or '(unset)'}",
                f"tmux: {'yes' if c.is_tmux else 'no'}",
                f"Config: {self._ctx.config_path}",
                f"Logs:   {self._ctx.log_path}",
                f"Log level: {self._config.log_level}",
            ]
        )

    def _refresh_status(self) -> None:
        self.query_one("#status", Static).update(self._build_status_text())

    def _write_output(self, text: str) -> None:
        if self._output is not None:
            self._output.write(text)

    def action_settings(self) -> None:
        self._write_output("Select a log level then press Save log level.")

    def action_view_logs(self) -> None:
        self._show_logs()

    def action_doctor(self) -> None:
        self._show_doctor()

    def on_button_pressed(self, event: Button.Pressed) -> None:
        bid = event.button.id or ""
        if bid == "save_log_level":
            self._save_log_level()
        elif bid == "doctor":
            self._show_doctor()
        elif bid == "view_logs":
            self._show_logs()
        elif bid == "exit":
            self.exit(0)

    def _save_log_level(self) -> None:
        if self._level_select is None:
            return

        new_level = str(self._level_select.value or "").strip().upper()
        if new_level not in SUPPORTED_LOG_LEVELS:
            self._write_output(f"Invalid log level: {new_level}")
            return

        self._config = AppConfig(log_level=new_level)
        save_config(self._ctx.config_path, self._config)
        log.warning("Log level updated to %s (applies on next start)", new_level)
        self._write_output(f"Saved log level: {new_level}. Restart recommended.")
        self._refresh_status()

    def _show_doctor(self) -> None:
        report = build_doctor_report(
            capabilities=self._ctx.capabilities,
            config_path=self._ctx.config_path,
            log_path=self._ctx.log_path,
        )
        self._write_output(report.text)

    def _show_logs(self) -> None:
        self._write_output("--- Logs (tail) ---")
        self._write_output(_tail_file(self._ctx.log_path))
        self._write_output("--- End logs ---")
