"""
settings.py
Notes:
- Displays runner mode and Proxmox endpoints.
- In the next increment, add editable widgets (Input, Switch, etc.) and persist to YAML.
"""
from __future__ import annotations

from textual.app import ComposeResult
from textual.screen import Screen
from textual.widgets import Static


class SettingsScreen(Screen):
    def compose(self) -> ComposeResult:
        cfg = self.app.config  # type: ignore[attr-defined]
        text = (
            f"Runner mode: {cfg.runner.mode}\n"
            f"Proxmox endpoints: {', '.join(cfg.proxmox.endpoints) or '(none set)'}\n"
            f"TLS verify: {cfg.proxmox.verify_tls}\n"
        )
        yield Static(text, id="settings_view")
