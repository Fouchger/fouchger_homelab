"""tool_base.py
Notes:
- Shared pattern for tooling screens (Proxmox, Ansible, Terraform, Packer).
- Keeps UI consistent and makes it easy to add new modules later.
"""

from __future__ import annotations

from dataclasses import dataclass

from textual.app import ComposeResult
from textual.screen import Screen
from textual.widgets import Button, Static
from textual.containers import Vertical

from ...domain.jobs import Job


@dataclass(frozen=True)
class PreflightCheck:
    """A simple preflight check that runs a fixed argv."""
    name: str
    argv: list[str]


class ToolScreen(Screen):
    """Base class for tool screens that run preflight checks."""

    TITLE: str = ""
    CHECKS: list[PreflightCheck] = []

    def compose(self) -> ComposeResult:
        with Vertical(id="tool_screen"):
            yield Static(self.TITLE, id="title")
            yield Static(
                "Preflight checks confirm the control plane can execute the required tooling.",
                id="subtitle",
            )
            for idx, check in enumerate(self.CHECKS):
                yield Button(check.name, id=f"check-{idx}")

    def on_button_pressed(self, event: Button.Pressed) -> None:
        button_id = event.button.id
        if not button_id or not button_id.startswith("check-"):
            return

        try:
            idx = int(button_id.removeprefix("check-"))
        except ValueError:
            return

        if idx < 0 or idx >= len(self.CHECKS):
            return

        check = self.CHECKS[idx]
        paths = self.app.paths  # type: ignore[attr-defined]
        job = Job(name=f"{self.TITLE} preflight: {check.name}", argv=check.argv, cwd=paths.root)
        self.app.submit_job(job)  # type: ignore[attr-defined]
