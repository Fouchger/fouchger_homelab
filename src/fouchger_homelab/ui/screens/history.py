"""history.py
Notes:
- Run history is stored in SQLite and displayed via DataTable.
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
        self.action_refresh()

    def action_refresh(self) -> None:
        table = self.query_one("#history_table", DataTable)
        table.clear()

        records = self.app.history.latest(limit=200)  # type: ignore[attr-defined]
        if not records:
            table.add_row("—", "—", "—", "—", "—")
            return

        for r in records:
            table.add_row(r.run_id[:8], r.created_at_utc, r.job_name, r.status, str(r.exit_code))
