"""
history.py
Notes:
- Run history will eventually be backed by SQLite (recommended).
- For now we show the DataTable wiring and leave the store implementation as the next increment.
"""
from __future__ import annotations

from textual.app import ComposeResult
from textual.screen import Screen
from textual.widgets import DataTable


class HistoryScreen(Screen):
    BINDINGS = [("r", "refresh", "Refresh")]

    def compose(self) -> ComposeResult:
        table = DataTable(id="history_table")
        yield table

    def on_mount(self) -> None:
        table = self.query_one("#history_table", DataTable)
        table.add_columns("Run ID", "When", "Job", "Status", "Exit Code")
        # Placeholder row
        table.add_row("—", "—", "—", "—", "—")

    def action_refresh(self) -> None:
        self.app.notify("Refresh not implemented yet")
