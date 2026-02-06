"""dev_tools.py
Notes:
- Development tooling intended for the control plane host.
- Actions here should be safe-by-default and idempotent where practical.
- Uses the same Job runner pipeline as other sections so output is captured in Run History.
"""

from __future__ import annotations

from textual.app import ComposeResult
from textual.containers import Vertical
from textual.screen import Screen
from textual.widgets import Button, Static

from ...domain.jobs import Job


class DevToolsScreen(Screen):
    """Developer-focused utilities for the control plane."""

    def compose(self) -> ComposeResult:
        with Vertical(id="dev_tools"):
            yield Static("Development Tools", id="title")
            yield Static(
                "Utilities for setting up the control plane for development and contributions.",
                id="subtitle",
            )

            yield Button(
                "Developer authentication (Git identity and GitHub CLI)",
                id="dev-auth",
            )

    def on_button_pressed(self, event: Button.Pressed) -> None:
        if event.button.id != "dev-auth":
            return

        paths = self.app.paths  # type: ignore[attr-defined]
        job = Job(
            name="Dev tools: authentication (git + gh)",
            argv=["bash", "scripts/core/dev-auth.sh", "all"],
            cwd=paths.root,
        )
        self.app.submit_job(job)  # type: ignore[attr-defined]
