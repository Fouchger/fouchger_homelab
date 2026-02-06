"""
app.py
Notes:
- Primary navigation uses screen switching (one section at a time).
- Long-running work should run in Workers and report back via messages.
- This file holds minimal orchestration. Business logic belongs in domain/*.
"""
from __future__ import annotations

from pathlib import Path
from textual.app import App, ComposeResult
from textual.containers import Horizontal, Vertical
from textual.widgets import Header, Footer, ContentSwitcher

from .paths import AppPaths
from .config import AppConfig
from .logging_setup import configure_logging

from .ui.widgets.menu import Menu
from .ui.widgets.log_panel import LogPanel

from .ui.screens.home import HomeScreen
from .ui.screens.setup_wizard import SetupWizardScreen
from .ui.screens.settings import SettingsScreen
from .ui.screens.history import HistoryScreen

# Placeholders for future screens
from textual.screen import Screen
from textual.widgets import Static


class PlaceholderScreen(Screen):
    def __init__(self, title: str) -> None:
        super().__init__()
        self._title = title

    def compose(self) -> ComposeResult:
        yield Static(f"{self._title} screen: to be implemented")


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
        ("6", "nav('history')", "History"),
        ("7", "nav('settings')", "Settings"),
    ]

    def __init__(self, paths: AppPaths, config: AppConfig) -> None:
        super().__init__()
        self.paths = paths
        self.config = config

    def compose(self) -> ComposeResult:
        yield Header()
        with Horizontal(id="root"):
            yield Menu(id="nav")
            with Vertical(id="main"):
                yield ContentSwitcher(
                    HomeScreen(id="home"),
                    SetupWizardScreen(id="setup"),
                    PlaceholderScreen("Proxmox", id="proxmox"),
                    PlaceholderScreen("Ansible", id="ansible"),
                    PlaceholderScreen("Terraform", id="terraform"),
                    PlaceholderScreen("Packer", id="packer"),
                    HistoryScreen(id="history"),
                    SettingsScreen(id="settings"),
                    initial="home",
                    id="switcher",
                )
                yield LogPanel(id="log")
        yield Footer()

    def on_mount(self) -> None:
        self.notify("Control plane ready")

    def on_menu_selected(self, message: Menu.Selected) -> None:
        self.action_nav(message.key)

    def action_nav(self, key: str) -> None:
        switcher = self.query_one("#switcher", ContentSwitcher)
        # Safety: only switch to known ids
        switcher.current = key if key in {
            "home","setup","proxmox","ansible","terraform","packer","history","settings"
        } else "home"


def main() -> None:
    paths = AppPaths.from_home("fouchger_homelab")
    paths.ensure()
    configure_logging(paths.logs_dir)

    config_path = paths.config_dir / "config.yml"
    cfg = AppConfig.load(config_path)

    HomelabApp(paths=paths, config=cfg).run()
