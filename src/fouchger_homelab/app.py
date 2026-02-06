"""
app.py
Notes:
- Primary navigation uses screen switching (one section at a time).
- Long-running work should run in Workers and report back via messages.
- This file holds minimal orchestration. Business logic belongs in domain/*.
"""
from __future__ import annotations

from pathlib import Path
import logging
from typing import Iterable

from textual import work
from textual.app import App, ComposeResult, SystemCommand
from textual.containers import Horizontal, Vertical
from textual.widgets import Header, Footer, ContentSwitcher
from textual.screen import Screen

from .paths import AppPaths
from .config import AppConfig
from .logging_setup import configure_logging

from .domain.direct_runner import DirectRunner
from .domain.history_store import HistoryStore
from .domain.jobs import Job
from .messages import LogLine, JobFinished

from .ui.widgets.menu import Menu
from .ui.widgets.log_panel import LogPanel

from .ui.screens.home import HomeScreen
from .ui.screens.setup_wizard import SetupWizardScreen
from .ui.screens.settings import SettingsScreen
from .ui.screens.history import HistoryScreen
from .ui.screens.proxmox import ProxmoxScreen
from .ui.screens.ansible import AnsibleScreen
from .ui.screens.terraform import TerraformScreen
from .ui.screens.packer import PackerScreen
from .ui.screens.dev_tools import DevToolsScreen

class HomelabApp(App):
    CSS = """
    #root { height: 1fr; }
    #nav { width: 30; border: heavy $background; }
    #main { width: 1fr; }
    #log { height: 12; border-top: heavy $background; }
    """

    BINDINGS = [
        ("q", "quit", "Quit"),
        ("1", "nav('setup')", "Setup"),
        ("2", "nav('proxmox')", "Proxmox"),
        ("3", "nav('ansible')", "Ansible"),
        ("4", "nav('terraform')", "Terraform"),
        ("5", "nav('packer')", "Packer"),
        ("6", "nav('devtools')", "Dev Tools"),
        ("7", "nav('history')", "History"),
        ("8", "nav('settings')", "Settings"),
    ]

    def __init__(self, paths: AppPaths, config: AppConfig) -> None:
        super().__init__()
        self.paths = paths
        self.config = config
        self.runner = DirectRunner(runs_dir=self.paths.runs_dir)
        self.history = HistoryStore(db_path=self.paths.state_dir / "history.db")

        self._ui_log_handler: logging.Handler | None = None

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="root"):
            yield Menu(id="nav")
            with Vertical(id="main"):
                yield ContentSwitcher(
                    HomeScreen(id="home"),
                    SetupWizardScreen(id="setup"),
                    ProxmoxScreen(id="proxmox"),
                    AnsibleScreen(id="ansible"),
                    TerraformScreen(id="terraform"),
                    PackerScreen(id="packer"),
                    DevToolsScreen(id="devtools"),
                    HistoryScreen(id="history"),
                    SettingsScreen(id="settings"),
                    initial="home",
                    id="switcher",
                )
                yield LogPanel(id="log")
        yield Footer()

    def on_mount(self) -> None:
        self._wire_logging_to_ui()
        self.notify("Control plane ready")
        self.post_message(LogLine(f"Runner: {self.runner.describe()}"))

    def on_menu_selected(self, message: Menu.Selected) -> None:
        self.action_nav(message.key)

    def action_nav(self, key: str) -> None:
        switcher = self.query_one("#switcher", ContentSwitcher)
        # Safety: only switch to known ids
        switcher.current = key if key in {
            "home","setup","proxmox","ansible","terraform","packer","devtools","history","settings"
        } else "home"

    def get_system_commands(self, screen: Screen) -> Iterable[SystemCommand]:
        """Expose navigation commands in the command palette.

        Textual's command palette is launched with Ctrl+P by default.
        """
        yield from super().get_system_commands(screen)
        yield SystemCommand("Go: Setup Wizard", "Open Setup Wizard", lambda: self.action_nav("setup"))
        yield SystemCommand("Go: Proxmox", "Open Proxmox section", lambda: self.action_nav("proxmox"))
        yield SystemCommand("Go: Ansible", "Open Ansible section", lambda: self.action_nav("ansible"))
        yield SystemCommand("Go: Terraform", "Open Terraform section", lambda: self.action_nav("terraform"))
        yield SystemCommand("Go: Packer", "Open Packer section", lambda: self.action_nav("packer"))
        yield SystemCommand("Go: Development Tools", "Open development tools", lambda: self.action_nav("devtools"))
        yield SystemCommand("Go: Run History", "Open run history", lambda: self.action_nav("history"))
        yield SystemCommand("Go: Settings", "Open settings", lambda: self.action_nav("settings"))

    def _wire_logging_to_ui(self) -> None:
        """Attach a logging handler that forwards log lines to the LogPanel.

        Notes:
        - We use App.post_message, which is thread-safe, to move log updates onto
          the UI thread.
        """

        if self._ui_log_handler is not None:
            return

        class _UiLogHandler(logging.Handler):
            def __init__(self, app: "HomelabApp") -> None:
                super().__init__()
                self._app = app

            def emit(self, record: logging.LogRecord) -> None:
                try:
                    msg = self.format(record)
                    self._app.post_message(LogLine(msg))
                except Exception:
                    # Never let logging break the app.
                    pass

        handler = _UiLogHandler(self)
        handler.setLevel(logging.INFO)
        handler.setFormatter(logging.Formatter("%(asctime)s %(levelname)s %(name)s %(message)s"))
        logging.getLogger().addHandler(handler)
        self._ui_log_handler = handler

    def on_log_line(self, message: LogLine) -> None:
        log_panel = self.query_one("#log", LogPanel)
        log_panel.write(message.text)

    def submit_job(self, job: Job) -> None:
        """Submit a Job for direct execution.

        This is the single entry point screens should use to run tooling.
        """
        self.history.record_started(job)
        self._run_job(job)

    @work(thread=True, group="jobs", exit_on_error=False)
    def _run_job(self, job: Job) -> None:
        result = self.runner.execute(job)
        self.post_message(JobFinished(job=job, result=result))

    def on_job_finished(self, message: JobFinished) -> None:
        self.history.record_finished(message.job, message.result)
        status = "Success" if message.result.exit_code == 0 else f"Failed (exit {message.result.exit_code})"
        self.notify(f"{message.job.name}: {status}")
        self.post_message(LogLine(f"Completed {message.job.name} run_id={message.result.run_id} exit={message.result.exit_code}"))


def main() -> None:
    paths = AppPaths.from_home("fouchger_homelab")
    paths.ensure()
    configure_logging(paths.logs_dir)

    config_path = paths.config_dir / "config.yml"
    cfg = AppConfig.load(config_path)

    HomelabApp(paths=paths, config=cfg).run()
